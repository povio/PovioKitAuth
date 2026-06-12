//
//  LinkedInAuthenticatorTests.swift
//  PovioKitAuth_Tests
//
//  Created by Cursor on 18/05/2026.
//

import XCTest
import Foundation
@testable import PovioKitAuthLinkedIn

@MainActor
final class LinkedInAuthenticatorTests: XCTestCase {
  func test_isAuthenticated_readsStoredBooleanFlag() {
    let storage = makeStorage()
    storage.set(true, forKey: "signIn.isAuthenticated")

    let authenticator = LinkedInAuthenticator(storage: storage)

    XCTAssertTrue(authenticator.isAuthenticated)
  }

  func test_signOut_clearsAuthenticationFlag() {
    let storage = makeStorage()
    storage.set(true, forKey: "signIn.isAuthenticated")
    let authenticator = LinkedInAuthenticator(storage: storage)

    authenticator.signOut()

    XCTAssertFalse(authenticator.isAuthenticated)
    XCTAssertNil(storage.object(forKey: "signIn.isAuthenticated"))
  }

  func test_configuration_authorizationUrl_containsRequiredQueryItems() {
    let config = LinkedInAuthenticator.Configuration(
      clientId: "client-id",
      clientSecret: "client-secret",
      permissions: "openid profile email",
      redirectUrl: URL(string: "myapp://oauth/linkedin")!
    )

    let url = config.authorizationUrl(state: "state-123")
    let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
    let query = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value) })

    XCTAssertEqual(query["response_type"], "code")
    XCTAssertEqual(query["connection"], "linkedin")
    XCTAssertEqual(query["client_id"], "client-id")
    XCTAssertEqual(query["redirect_uri"], "myapp://oauth/linkedin")
    XCTAssertEqual(query["state"], "state-123")
    XCTAssertEqual(query["scope"], "openid profile email")
  }

  func test_configuration_authorizationUrl_includesOptionalPkceAndAudienceParameters() {
    let config = LinkedInAuthenticator.Configuration(
      clientId: "client-id",
      clientSecret: "client-secret",
      permissions: "openid profile email",
      redirectUrl: URL(string: "myapp://oauth/linkedin")!,
      authEndpoint: URL(string: "https://www.linkedin.com/oauth/v2/authorization")!,
      authCancel: URL(string: "https://www.linkedin.com/oauth/v2/login-cancel")!,
      audience: "https://api.linkedin.com",
      codeVerifier: "verifier",
      codeChallenge: "challenge",
      codeChallengeMethod: "S256"
    )

    let url = config.authorizationUrl(state: "state-123")
    let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
    let query = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value) })

    XCTAssertEqual(query["audience"], "https://api.linkedin.com")
    XCTAssertEqual(query["code_challenge"], "challenge")
    XCTAssertEqual(query["code_challenge_method"], "S256")
  }

  func test_response_name_returnsComputedFullName() {
    var components = PersonNameComponents()
    components.givenName = "Ada"
    components.familyName = "Lovelace"

    let response = LinkedInAuthenticator.Response(
      userId: "1",
      token: "token",
      nameComponents: components,
      email: "ada@povio.com",
      expiresAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    XCTAssertEqual(response.name, "Ada Lovelace")
  }

  func test_emailResponse_decodesHandleTildeKey() throws {
    let json = """
    {
      "elements": [
        {
          "handle~": {
            "emailAddress": "ada@povio.com"
          }
        }
      ]
    }
    """
    let data = Data(json.utf8)

    let decoded = try JSONDecoder().decode(LinkedInAPI.LinkedInEmailResponse.self, from: data)

    XCTAssertEqual(decoded.elements.first?.handle.emailAddress, "ada@povio.com")
  }

  func test_signIn_success_mapsApiResponsesAndSetsAuthenticatedFlag() async throws {
    let storage = makeStorage()
    let api = MockLinkedInAPI()
    api.loginResult = .success(try decodeAuthResponse(
      #"{"accessToken":"token-1","expiresIn":"2030-01-01T00:00:00Z"}"#
    ))
    api.profileResult = .success(try decodeProfileResponse(
      #"{"id":"user-1","localizedFirstName":"Ada","localizedLastName":"Lovelace"}"#
    ))
    api.emailResult = .success(try decodeEmailValueResponse(#"{"emailAddress":"ada@povio.com"}"#))

    let authenticator = LinkedInAuthenticator(storage: storage, linkedInAPI: api)
    let config = LinkedInAuthenticator.Configuration(
      clientId: "client-id",
      clientSecret: "client-secret",
      permissions: "openid profile email",
      redirectUrl: URL(string: "myapp://oauth/linkedin")!
    )

    let response = try await authenticator.signIn(authCode: "auth-code", configuration: config)

    XCTAssertEqual(response.userId, "user-1")
    XCTAssertEqual(response.token, "token-1")
    XCTAssertEqual(response.email, "ada@povio.com")
    XCTAssertEqual(response.name, "Ada Lovelace")
    XCTAssertTrue(authenticator.isAuthenticated)
  }

  func test_signIn_whenLoginFails_propagatesErrorAndDoesNotAuthenticate() async {
    enum DummyError: Error { case failed }

    let storage = makeStorage()
    let api = MockLinkedInAPI()
    api.loginResult = .failure(DummyError.failed)

    let authenticator = LinkedInAuthenticator(storage: storage, linkedInAPI: api)
    let config = LinkedInAuthenticator.Configuration(
      clientId: "client-id",
      clientSecret: "client-secret",
      permissions: "openid profile email",
      redirectUrl: URL(string: "myapp://oauth/linkedin")!
    )

    do {
      _ = try await authenticator.signIn(authCode: "auth-code", configuration: config)
      XCTFail("Expected error")
    } catch DummyError.failed {
      XCTAssertFalse(authenticator.isAuthenticated)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}

private extension LinkedInAuthenticatorTests {
  func makeStorage() -> UserDefaults {
    let suiteName = "dev.povio.linkedin.tests.\(UUID().uuidString)"
    let storage = UserDefaults(suiteName: suiteName)!
    storage.removePersistentDomain(forName: suiteName)
    return storage
  }

  func decodeAuthResponse(_ json: String) throws -> LinkedInAPI.LinkedInAuthResponse {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(LinkedInAPI.LinkedInAuthResponse.self, from: Data(json.utf8))
  }

  func decodeProfileResponse(_ json: String) throws -> LinkedInAPI.LinkedInProfileResponse {
    let decoder = JSONDecoder()
    return try decoder.decode(LinkedInAPI.LinkedInProfileResponse.self, from: Data(json.utf8))
  }

  func decodeEmailValueResponse(_ json: String) throws -> LinkedInAPI.LinkedInEmailValueResponse {
    let decoder = JSONDecoder()
    return try decoder.decode(LinkedInAPI.LinkedInEmailValueResponse.self, from: Data(json.utf8))
  }
}

private final class MockLinkedInAPI: LinkedInAPIProtocol, @unchecked Sendable {
  var loginResult: Result<LinkedInAPI.LinkedInAuthResponse, Error>!
  var profileResult: Result<LinkedInAPI.LinkedInProfileResponse, Error>!
  var emailResult: Result<LinkedInAPI.LinkedInEmailValueResponse, Error>!

  func login(with request: LinkedInAPI.LinkedInAuthRequest) async throws -> LinkedInAPI.LinkedInAuthResponse {
    try loginResult.get()
  }

  func loadProfile(with request: LinkedInAPI.LinkedInProfileRequest) async throws -> LinkedInAPI.LinkedInProfileResponse {
    try profileResult.get()
  }

  func loadEmail(with request: LinkedInAPI.LinkedInProfileRequest) async throws -> LinkedInAPI.LinkedInEmailValueResponse {
    try emailResult.get()
  }
}
