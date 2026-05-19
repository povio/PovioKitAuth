//
//  AppleAuthenticator.swift
//  PovioKitAuth
//
//  Created by Borut Tomazin on 24/10/2022.
//  Copyright © 2026 Povio Inc. All rights reserved.
//

import AuthenticationServices
import Foundation
import PovioKitAuthCore

public final class AppleAuthenticator: NSObject {
  typealias AuthorizationRequestFactory = () -> ASAuthorizationAppleIDRequest
  typealias AuthorizationPerformer = ([ASAuthorizationRequest], UIViewController, ASAuthorizationControllerDelegate) -> Void

  private let storage: UserDefaults
  private let storageUserIdKey = "signIn.userId"
  private let storageAuthenticatedKey = "authenticated"
  private let makeAuthorizationRequest: AuthorizationRequestFactory
  private let performAuthorization: AuthorizationPerformer
  private let keychainService: KeychainService
  private let keychainServiceDataKey: String
  private var continuation: CheckedContinuation<Response, Swift.Error>?
  
  public init(storage: UserDefaults? = nil) {
    self.storage = storage ?? .init(suiteName: "povioKit.auth.apple") ?? .standard
    let provider = ASAuthorizationAppleIDProvider()
    self.makeAuthorizationRequest = {
      provider.createRequest()
    }
    self.performAuthorization = { requests, presentingViewController, delegate in
      let controller = ASAuthorizationController(authorizationRequests: requests)
      controller.delegate = delegate
      controller.presentationContextProvider = presentingViewController
      controller.performRequests()
    }
    self.keychainService = KeychainService(name: "povioKit.auth")
    self.keychainServiceDataKey = "user.data"
    super.init()
    setupCredentialsRevokeListener()
  }
  
  init(
    storage: UserDefaults,
    makeAuthorizationRequest: @escaping AuthorizationRequestFactory,
    performAuthorization: @escaping AuthorizationPerformer,
    keychainService: KeychainService = KeychainService(name: "povioKit.auth"),
    keychainServiceDataKey: String = "user.data"
  ) {
    self.storage = storage
    self.makeAuthorizationRequest = makeAuthorizationRequest
    self.performAuthorization = performAuthorization
    self.keychainService = keychainService
    self.keychainServiceDataKey = keychainServiceDataKey
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
    resolveSignIn(with: .failure(Error.cancelled))
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
}

// MARK: - ASAuthorizationControllerDelegate
extension AppleAuthenticator: ASAuthorizationControllerDelegate {
  public func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    switch authorization.credential {
    case let credential as ASAuthorizationAppleIDCredential:
      do {
        let response = try processAppleIDCredential(
          user: credential.user,
          authCodeData: credential.authorizationCode,
          identityTokenData: credential.identityToken,
          emailFromCredential: credential.email,
          fullName: credential.fullName
        )
        resolveSignIn(with: .success(response))
      } catch let error as Error {
        rejectSignIn(with: error)
      } catch {
        rejectSignIn(with: .invalidIdentityToken)
      }
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

// MARK: - Internal Methods
extension AppleAuthenticator {
  func processAppleIDCredential(
    user: String,
    authCodeData: Data?,
    identityTokenData: Data?,
    emailFromCredential: String?,
    fullName: PersonNameComponents?
  ) throws -> Response {
    guard let authCodeData,
          let authCode = String(data: authCodeData, encoding: .utf8),
          let identityTokenData,
          let identityTokenString = String(data: identityTokenData, encoding: .utf8) else {
      throw Error.invalidIdentityToken
    }

    storage.set(user, forKey: storageUserIdKey)
    storage.setValue(true, forKey: storageAuthenticatedKey)

    let jwt = try? JWTDecoder(token: identityTokenString)
    var email: Email? = (emailFromCredential ?? jwt?.string(for: "email")).map {
      let isEmailPrivate = jwt?.bool(for: "is_private_email") ?? false
      let isEmailVerified = jwt?.bool(for: "email_verified") ?? false
      return .init(address: $0, isPrivate: isEmailPrivate, isVerified: isEmailVerified)
    }

    let existingUserData: UserData? = keychainService.read(UserData.self, for: keychainServiceDataKey)
    if email == nil, let existingUserData {
      email = existingUserData.email
    }

    guard let email, !email.address.isEmpty else {
      throw Error.missingEmail
    }

    let updatedUserData = UserData(name: fullName, email: email)
    try? keychainService.save(updatedUserData, for: keychainServiceDataKey)

    guard let expiresAt = jwt?.expiresAt else {
      throw Error.missingExpiration
    }

    return Response(
      userId: user,
      token: identityTokenString,
      authCode: authCode,
      nameComponents: updatedUserData.name,
      email: updatedUserData.email,
      expiresAt: expiresAt
    )
  }
}

// MARK: - Private Methods
private extension AppleAuthenticator {
  func appleSignIn(on presentingViewController: UIViewController, with nonce: Nonce?) async throws -> Response {
    guard continuation == nil else { throw Error.signInInProgress }

    let request = makeAuthorizationRequest()
    request.requestedScopes = [.fullName, .email]
    request.nonce = nonce?.value

    return try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      performAuthorization([request], presentingViewController, self)
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
    resolveSignIn(with: .failure(error))
  }

  func resolveSignIn(with result: Result<Response, Swift.Error>) {
    guard let continuation else { return }
    continuation.resume(with: result)
    self.continuation = nil
  }
}

// MARK: - Actions
private extension AppleAuthenticator {
  @objc func appleCredentialRevoked() {
    rejectSignIn(with: .credentialsRevoked)
  }
}
