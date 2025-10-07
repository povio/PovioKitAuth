//
//  AppleAuthenticator.swift
//  PovioKitAuth
//
//  Created by Borut Tomazin on 24/10/2022.
//  Copyright © 2025 Povio Inc. All rights reserved.
//

import AuthenticationServices
import Foundation
import PovioKitAuthCore

public final class AppleAuthenticator: NSObject {
  private let storage: UserDefaults
  private let storageUserIdKey = "signIn.userId"
  private let storageAuthenticatedKey = "authenticated"
  private let provider: ASAuthorizationAppleIDProvider
  private let keychainService: KeychainService = .init(name: "povioKit.auth")
  private let keychainServiceDataKey: String = "user.data"
  private var continuation: CheckedContinuation<Response, Swift.Error>?
  
  public init(storage: UserDefaults? = nil) {
    self.provider = .init()
    self.storage = storage ?? .init(suiteName: "povioKit.auth.apple") ?? .standard
    super.init()
    setupCredentialsRevokeListener()
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}

// MARK: - Public Methods
extension AppleAuthenticator: Authenticator {
  /// SignIn user
  ///
  /// Will asynchronously return the `Response` object on success or `Error` on error.
  public func signIn(from presentingViewController: UIViewController) async throws -> Response {
    try await appleSignIn(on: presentingViewController, with: nil)
  }
  
  /// SignIn user with `nonce` value
  ///
  /// Nonce is usually needed when doing auth with an external auth provider (e.g. firebase).
  /// Will asynchronously return the `Response` object on success or `Error` on error.
  public func signIn(from presentingViewController: UIViewController, with nonce: Nonce) async throws -> Response {
    try await appleSignIn(on: presentingViewController, with: nonce)
  }
  
  /// Clears the signIn footprint and logs out the user immediatelly.
  public func signOut() {
    storage.removeObject(forKey: storageUserIdKey)
    storage.setValue(false, forKey: storageAuthenticatedKey)
    continuation = nil
  }
  
  /// Returns the current authentication state.
  public var isAuthenticated: Authenticated {
    storage.string(forKey: storageUserIdKey) != nil && storage.bool(forKey: storageAuthenticatedKey)
  }
  
  /// Boolean if given `url` should be handled.
  ///
  /// Call this from UIApplicationDelegate’s `application:openURL:options:` method.
  public func canOpenUrl(
    _ url: URL,
    application: UIApplication,
    options: [UIApplication.OpenURLOptionsKey : Any]
  ) -> Bool {
    false
  }
  
  /// Generate random nonce string
  public func generateNonceString(length: UInt = 32) -> String {
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    let result = (0..<length).compactMap { _ in charset.randomElement() }
    guard result.count == length else { fatalError("Unable to generate nonce!") }
    return String(result)
  }
}

// MARK: - ASAuthorizationControllerDelegate
extension AppleAuthenticator: ASAuthorizationControllerDelegate {
  public func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    switch authorization.credential {
    case let credential as ASAuthorizationAppleIDCredential:
      guard let authCodeData = credential.authorizationCode,
            let authCode = String(data: authCodeData, encoding: .utf8),
            let identityToken = credential.identityToken,
            let identityTokenString = String(data: identityToken, encoding: .utf8) else {
        rejectSignIn(with: .invalidIdentityToken)
        return
      }
      
      // store userId and authentication flag
      storage.set(credential.user, forKey: storageUserIdKey)
      storage.setValue(true, forKey: storageAuthenticatedKey)
      
      // parse email and related metadata
      let jwt = try? JWTDecoder(token: identityTokenString)
      var email: Email? = (credential.email ?? jwt?.string(for: "email")).map {
        let isEmailPrivate = jwt?.bool(for: "is_private_email") ?? false
        let isEmailVerified = jwt?.bool(for: "email_verified") ?? false
        return .init(address: $0, isPrivate: isEmailPrivate, isVerified: isEmailVerified)
      }
      
      // load email from keychain on subsequent logins
      let existingUserData: UserData? = keychainService.read(UserData.self, for: keychainServiceDataKey)
      if email == nil, let existingUserData {
        email = existingUserData.email
      }
      
      // do not continue if `email` is missing
      guard let email, !email.address.isEmpty else {
        rejectSignIn(with: .missingEmail)
        return
      }
      
      // save user data for the future logins
      let updatedUserData: UserData = .init(name: credential.fullName, email: email)
      try? keychainService.save(updatedUserData, for: keychainServiceDataKey)
      
      // do not continue if `expiresAt` is missing
      guard let expiresAt = jwt?.expiresAt else {
        rejectSignIn(with: .missingExpiration)
        return
      }
      
      let response = Response(
        userId: credential.user,
        token: identityTokenString,
        authCode: authCode,
        nameComponents: updatedUserData.name,
        email: updatedUserData.email,
        expiresAt: expiresAt
      )
      
      continuation?.resume(with: .success(response))
    case _:
      rejectSignIn(with: .unhandledAuthorization)
    }
  }
  
  public func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithError error: Swift.Error
  ) {
    switch error {
    case let err as ASAuthorizationError where err.code == .canceled:
      rejectSignIn(with: .cancelled)
    default:
      rejectSignIn(with: .system(error))
    }
  }
}

// MARK: - Private Methods
private extension AppleAuthenticator {
  func appleSignIn(on presentingViewController: UIViewController, with nonce: Nonce?) async throws -> Response {
    let request = provider.createRequest()
    request.requestedScopes = [.fullName, .email]
    
    switch nonce {
    case .random(let length):
      guard length > 0 else {
        throw Error.invalidNonceLength
      }
      request.nonce = generateNonceString(length: length).sha256
    case .custom(let value):
      request.nonce = value.sha256
    case .none:
      break
    }
    
    return try await withCheckedThrowingContinuation { continuation in
      let controller = ASAuthorizationController(authorizationRequests: [request])
      controller.delegate = self
      controller.presentationContextProvider = presentingViewController
      self.continuation = continuation
      controller.performRequests()
    }
  }
  
  func setupCredentialsRevokeListener() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appleCredentialRevoked),
      name: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
      object: nil
    )
  }
  
  func rejectSignIn(with error: Error) {
    storage.setValue(false, forKey: storageAuthenticatedKey)
    continuation?.resume(throwing: error)
    continuation = nil
  }
}

// MARK: - Actions
private extension AppleAuthenticator {
  @objc func appleCredentialRevoked() {
    rejectSignIn(with: .credentialsRevoked)
  }
}
