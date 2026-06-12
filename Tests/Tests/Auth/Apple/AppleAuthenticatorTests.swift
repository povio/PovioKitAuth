//
//  AppleAuthenticatorTests.swift
//  PovioKitAuth_Tests
//
//  Created by Cursor on 18/05/2026.
//

import XCTest
import Foundation
import AuthenticationServices
import UIKit
import PovioKitAuthCore
@testable import PovioKitAuthApple

@MainActor
final class AppleAuthenticatorTests: XCTestCase {
  func test_isAuthenticated_whenStorageContainsUserIdAndFlag_returnsTrue() {
    let storage = makeStorage()
    storage.set("user-1", forKey: "signIn.userId")
    storage.set(true, forKey: "authenticated")

    let authenticator = AppleAuthenticator(storage: storage)

    XCTAssertTrue(authenticator.isAuthenticated)
  }

  func test_signOut_clearsStoredStateAndReturnsUnauthenticated() {
    let storage = makeStorage()
    storage.set("user-1", forKey: "signIn.userId")
    storage.set(true, forKey: "authenticated")
    let authenticator = AppleAuthenticator(storage: storage)

    authenticator.signOut()

    XCTAssertFalse(authenticator.isAuthenticated)
    XCTAssertNil(storage.string(forKey: "signIn.userId"))
    XCTAssertFalse(storage.bool(forKey: "authenticated"))
  }

  func test_response_name_usesNameComponentsComputedName() {
    var components = PersonNameComponents()
    components.givenName = "Ada"
    components.familyName = "Lovelace"

    let response = AppleAuthenticator.Response(
      userId: "1",
      token: "token",
      authCode: "auth",
      nameComponents: components,
      email: .init(address: "ada@povio.com", isPrivate: false, isVerified: true),
      expiresAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    XCTAssertEqual(response.name, "Ada Lovelace")
  }

  func test_canOpenUrl_alwaysReturnsFalse() {
    let storage = makeStorage()
    let authenticator = AppleAuthenticator(storage: storage)

    let result = authenticator.canOpenUrl(
      URL(string: "myapp://callback")!,
      application: UIApplication.shared,
      options: [:]
    )

    XCTAssertFalse(result)
  }

  func test_credentialRevokedNotification_marksAuthenticatorAsSignedOut() {
    let storage = makeStorage()
    storage.set("user-1", forKey: "signIn.userId")
    storage.set(true, forKey: "authenticated")
    let authenticator = AppleAuthenticator(storage: storage)

    NotificationCenter.default.post(name: ASAuthorizationAppleIDProvider.credentialRevokedNotification, object: nil)

    XCTAssertFalse(authenticator.isAuthenticated)
    XCTAssertFalse(storage.bool(forKey: "authenticated"))
  }

  func test_internalInit_usesInjectedStorageForAuthenticationState() {
    let storage = makeStorage()
    storage.set("user-2", forKey: "signIn.userId")
    storage.set(true, forKey: "authenticated")
    let provider = ASAuthorizationAppleIDProvider()
    let authenticator = AppleAuthenticator(
      storage: storage,
      makeAuthorizationRequest: { provider.createRequest() },
      performAuthorization: { _, _, _ in
        // no-op
      }
    )

    XCTAssertTrue(authenticator.isAuthenticated)
  }

  func test_authorizationControllerDidCompleteWithError_whenCancelled_marksUnauthenticated() {
    let storage = makeStorage()
    storage.set("user-1", forKey: "signIn.userId")
    storage.set(true, forKey: "authenticated")
    let authenticator = AppleAuthenticator(storage: storage)
    let controller = makeAuthorizationController()

    authenticator.authorizationController(
      controller: controller,
      didCompleteWithError: ASAuthorizationError(.canceled)
    )

    XCTAssertFalse(authenticator.isAuthenticated)
    XCTAssertFalse(storage.bool(forKey: "authenticated"))
  }

  func test_authorizationControllerDidCompleteWithError_whenSystemError_marksUnauthenticated() {
    let storage = makeStorage()
    storage.set("user-1", forKey: "signIn.userId")
    storage.set(true, forKey: "authenticated")
    let authenticator = AppleAuthenticator(storage: storage)
    let controller = makeAuthorizationController()

    authenticator.authorizationController(
      controller: controller,
      didCompleteWithError: NSError(domain: "Tests", code: 999)
    )

    XCTAssertFalse(authenticator.isAuthenticated)
    XCTAssertFalse(storage.bool(forKey: "authenticated"))
  }

  @MainActor
  func test_signIn_whenPerformerFinishesWithCancelled_throwsCancelled() async {
    let storage = makeStorage()
    let provider = ASAuthorizationAppleIDProvider()
    let authenticator = AppleAuthenticator(
      storage: storage,
      makeAuthorizationRequest: { provider.createRequest() },
      performAuthorization: { requests, _, delegate in
        let controller = ASAuthorizationController(authorizationRequests: requests)
        let appleDelegate = delegate as! AppleAuthenticator
        appleDelegate.authorizationController(
          controller: controller,
          didCompleteWithError: ASAuthorizationError(.canceled)
        )
      }
    )

    do {
      _ = try await authenticator.signIn(from: UIViewController())
      XCTFail("Expected cancelled error")
    } catch let error as AppleAuthenticator.Error {
      switch error {
      case .cancelled:
        break
      default:
        XCTFail("Unexpected AppleAuthenticator.Error: \(error)")
      }
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func test_processAppleIDCredential_whenAuthCodeMissing_throwsInvalidIdentityToken() {
    let storage = makeStorage()
    let authenticator = makeAuthenticator(storage: storage)

    XCTAssertThrowsError(
      try authenticator.processAppleIDCredential(
        user: "user-1",
        authCodeData: nil,
        identityTokenData: Data(makeToken(header: ["alg": "HS256"], payload: ["exp": 4_102_444_800, "email": "a@b.com"]).utf8),
        emailFromCredential: nil,
        fullName: nil
      )
    ) { error in
      guard case .invalidIdentityToken = error as? AppleAuthenticator.Error else {
        return XCTFail("Expected invalidIdentityToken, got \(error)")
      }
    }
  }

  func test_processAppleIDCredential_whenEmailMissing_throwsMissingEmail() {
    let storage = makeStorage()
    let authenticator = makeAuthenticator(storage: storage)
    let token = makeToken(header: ["alg": "HS256"], payload: ["exp": 4_102_444_800, "sub": "user-1"])

    XCTAssertThrowsError(
      try authenticator.processAppleIDCredential(
        user: "user-1",
        authCodeData: Data("auth-code".utf8),
        identityTokenData: Data(token.utf8),
        emailFromCredential: nil,
        fullName: nil
      )
    ) { error in
      guard case .missingEmail = error as? AppleAuthenticator.Error else {
        return XCTFail("Expected missingEmail, got \(error)")
      }
    }
  }

  func test_processAppleIDCredential_whenExpirationMissing_throwsMissingExpiration() {
    let storage = makeStorage()
    let authenticator = makeAuthenticator(storage: storage)
    let token = makeToken(header: ["alg": "HS256"], payload: ["email": "ada@povio.com"])

    XCTAssertThrowsError(
      try authenticator.processAppleIDCredential(
        user: "user-1",
        authCodeData: Data("auth-code".utf8),
        identityTokenData: Data(token.utf8),
        emailFromCredential: nil,
        fullName: nil
      )
    ) { error in
      guard case .missingExpiration = error as? AppleAuthenticator.Error else {
        return XCTFail("Expected missingExpiration, got \(error)")
      }
    }
  }

  func test_processAppleIDCredential_whenValidToken_returnsResponseAndPersistsState() throws {
    let storage = makeStorage()
    let authenticator = makeAuthenticator(storage: storage)
    var fullName = PersonNameComponents()
    fullName.givenName = "Ada"
    fullName.familyName = "Lovelace"
    let expiresAt = Date(timeIntervalSince1970: 4_102_444_800)
    let token = makeToken(
      header: ["alg": "HS256"],
      payload: [
        "email": "ada@povio.com",
        "email_verified": true,
        "is_private_email": false,
        "exp": 4_102_444_800
      ]
    )

    let response = try authenticator.processAppleIDCredential(
      user: "user-1",
      authCodeData: Data("auth-code".utf8),
      identityTokenData: Data(token.utf8),
      emailFromCredential: nil,
      fullName: fullName
    )

    XCTAssertEqual(response.userId, "user-1")
    XCTAssertEqual(response.authCode, "auth-code")
    XCTAssertEqual(response.token, token)
    XCTAssertEqual(response.email.address, "ada@povio.com")
    XCTAssertTrue(response.email.isVerified)
    XCTAssertFalse(response.email.isPrivate)
    XCTAssertEqual(response.name, "Ada Lovelace")
    XCTAssertEqual(response.expiresAt, expiresAt)
    XCTAssertTrue(authenticator.isAuthenticated)
    XCTAssertEqual(storage.string(forKey: "signIn.userId"), "user-1")
  }

  func test_processAppleIDCredential_whenEmailProvidedByCredential_usesCredentialEmail() throws {
    let storage = makeStorage()
    let authenticator = makeAuthenticator(storage: storage)
    let token = makeToken(header: ["alg": "HS256"], payload: ["exp": 4_102_444_800])

    let response = try authenticator.processAppleIDCredential(
      user: "user-1",
      authCodeData: Data("auth-code".utf8),
      identityTokenData: Data(token.utf8),
      emailFromCredential: "ada@povio.com",
      fullName: nil
    )

    XCTAssertEqual(response.email.address, "ada@povio.com")
  }

  func test_processAppleIDCredential_whenEmailStoredInKeychain_usesStoredEmail() throws {
    let keychain = try makeEntitledKeychainOrSkip()
    let storage = makeStorage()
    let authenticator = makeAuthenticator(storage: storage, keychainService: keychain)
    let storedEmail = AppleAuthenticator.Email(address: "stored@povio.com", isPrivate: true, isVerified: false)
    try keychain.save(AppleAuthenticator.UserData(name: nil, email: storedEmail), for: "user.data")
    let token = makeToken(header: ["alg": "HS256"], payload: ["exp": 4_102_444_800])

    let response = try authenticator.processAppleIDCredential(
      user: "user-1",
      authCodeData: Data("auth-code".utf8),
      identityTokenData: Data(token.utf8),
      emailFromCredential: nil,
      fullName: nil
    )

    XCTAssertEqual(response.email.address, storedEmail.address)
    XCTAssertEqual(response.email.isPrivate, storedEmail.isPrivate)
    XCTAssertEqual(response.email.isVerified, storedEmail.isVerified)
    try keychain.clear()
  }

  @MainActor
  func test_signInWithNonce_whenPerformerFinishesWithSystemError_throwsSystem() async {
    let storage = makeStorage()
    let provider = ASAuthorizationAppleIDProvider()
    let authenticator = AppleAuthenticator(
      storage: storage,
      makeAuthorizationRequest: { provider.createRequest() },
      performAuthorization: { requests, _, delegate in
        let controller = ASAuthorizationController(authorizationRequests: requests)
        let appleDelegate = delegate as! AppleAuthenticator
        appleDelegate.authorizationController(
          controller: controller,
          didCompleteWithError: NSError(domain: "Tests", code: 500)
        )
      }
    )

    do {
      _ = try await authenticator.signIn(from: UIViewController(), with: .custom(value: "nonce"))
      XCTFail("Expected system error")
    } catch let error as AppleAuthenticator.Error {
      switch error {
      case .system:
        break
      default:
        XCTFail("Unexpected AppleAuthenticator.Error: \(error)")
      }
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}

private extension AppleAuthenticatorTests {
  func makeAuthenticator(
    storage: UserDefaults,
    keychainService: KeychainService = KeychainService(name: "povioKit.auth.apple.tests.\(UUID().uuidString)")
  ) -> AppleAuthenticator {
    let provider = ASAuthorizationAppleIDProvider()
    return AppleAuthenticator(
      storage: storage,
      makeAuthorizationRequest: { provider.createRequest() },
      performAuthorization: { _, _, _ in },
      keychainService: keychainService
    )
  }

  func makeEntitledKeychainOrSkip() throws -> KeychainService {
    let service = KeychainService(name: "dev.povio.apple.tests.\(UUID().uuidString)")
    do {
      try service.clear()
      return service
    } catch {
      let nsError = error as NSError
      let errorDescription = String(describing: error)
      if nsError.code == -34018 || errorDescription.contains("-34018") {
        throw XCTSkip("Skipping keychain storage tests without keychain entitlements: \(errorDescription)")
      }
      throw error
    }
  }

  func makeToken(header: [String: Any], payload: [String: Any]) -> String {
    let encodedHeader = encodeBase64URL(from: header)
    let encodedPayload = encodeBase64URL(from: payload)
    return "\(encodedHeader).\(encodedPayload).signature"
  }

  func encodeBase64URL(from object: [String: Any]) -> String {
    let data = try! JSONSerialization.data(withJSONObject: object, options: [])
    let base64 = data.base64EncodedString()
    return base64
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  func makeStorage() -> UserDefaults {
    let suiteName = "dev.povio.apple.tests.\(UUID().uuidString)"
    let storage = UserDefaults(suiteName: suiteName)!
    storage.removePersistentDomain(forName: suiteName)
    return storage
  }

  func makeAuthorizationController() -> ASAuthorizationController {
    let request = ASAuthorizationAppleIDProvider().createRequest()
    return ASAuthorizationController(authorizationRequests: [request])
  }
}
