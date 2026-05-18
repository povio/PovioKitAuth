//
//  LinkedInAPITests.swift
//  PovioKitAuth_Tests
//
//  Created by Cursor on 18/05/2026.
//

import XCTest
import Foundation
@testable import PovioKitAuthLinkedIn

final class LinkedInAPITests: XCTestCase {
  override func tearDown() {
    URLProtocolMock.requestHandler = nil
    super.tearDown()
  }

  func test_login_success_buildsFormBodyAndDecodesResponse() async throws {
    URLProtocolMock.requestHandler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.absoluteString, "https://www.linkedin.com/oauth/v2/accessToken")
      XCTAssertEqual(
        request.value(forHTTPHeaderField: "Content-Type"),
        "application/x-www-form-urlencoded; charset=utf-8"
      )
      XCTAssertTrue(request.httpBody != nil || request.httpBodyStream != nil)

      let json = #"{"access_token":"token-1","expires_in":3600}"#
      let data = Data(json.utf8)
      let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (response, data)
    }

    let api = makeAPI()
    let request = LinkedInAPI.LinkedInAuthRequest(
      code: "abc123",
      redirectUri: "myapp://oauth/linkedin",
      clientId: "client",
      clientSecret: "secret"
    )

    let response = try await api.login(with: request)

    XCTAssertEqual(response.accessToken, "token-1")
    XCTAssertGreaterThan(response.expiresIn.timeIntervalSinceNow, 3500)
  }

  func test_loadProfile_success_setsBearerHeaderAndDecodesPayload() async throws {
    URLProtocolMock.requestHandler = { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.url?.absoluteString, "https://api.linkedin.com/v2/me")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-1")

      let json = #"{"id":"uid-1","localizedFirstName":"Ada","localizedLastName":"Lovelace"}"#
      let data = Data(json.utf8)
      let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (response, data)
    }

    let api = makeAPI()
    let profile = try await api.loadProfile(with: .init(token: "token-1"))

    XCTAssertEqual(profile.id, "uid-1")
    XCTAssertEqual(profile.localizedFirstName, "Ada")
    XCTAssertEqual(profile.localizedLastName, "Lovelace")
  }

  func test_loadEmail_success_decodesNestedHandle() async throws {
    URLProtocolMock.requestHandler = { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertTrue(request.url?.absoluteString.contains("emailAddress?q=members") == true)

      let json = #"{"elements":[{"handle~":{"emailAddress":"ada@povio.com"}}]}"#
      let data = Data(json.utf8)
      let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (response, data)
    }

    let api = makeAPI()
    let email = try await api.loadEmail(with: .init(token: "token-1"))

    XCTAssertEqual(email.emailAddress, "ada@povio.com")
  }

  func test_loadEmail_whenElementsAreEmpty_throwsInvalidResponse() async {
    URLProtocolMock.requestHandler = { request in
      let data = Data(#"{"elements":[]}"#.utf8)
      let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (response, data)
    }

    let api = makeAPI()

    do {
      _ = try await api.loadEmail(with: .init(token: "token-1"))
      XCTFail("Expected invalidResponse error")
    } catch let error as LinkedInAPI.Error {
      switch error {
      case .invalidResponse:
        break
      default:
        XCTFail("Unexpected LinkedInAPI.Error: \(error)")
      }
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func test_login_whenStatusCodeIsUnsuccessful_throwsHttpClientError() async {
    URLProtocolMock.requestHandler = { request in
      let data = Data(#"{"error":"invalid_client"}"#.utf8)
      let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
      return (response, data)
    }

    let api = makeAPI()
    let request = LinkedInAPI.LinkedInAuthRequest(
      code: "abc123",
      redirectUri: "myapp://oauth/linkedin",
      clientId: "client",
      clientSecret: "secret"
    )

    do {
      _ = try await api.login(with: request)
      XCTFail("Expected unsuccessfulStatusCode error")
    } catch let error as HttpClientError {
      switch error {
      case .unsuccessfulStatusCode(let code, _):
        XCTAssertEqual(code, 401)
      default:
        XCTFail("Unexpected HttpClientError: \(error)")
      }
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func test_endpoints_buildExpectedUrls() {
    XCTAssertEqual(LinkedInAPI.Endpoints.accessToken.path, "accessToken")
    XCTAssertEqual(LinkedInAPI.Endpoints.profile.path, "me")
    XCTAssertEqual(LinkedInAPI.Endpoints.email.path, "emailAddress?q=members&projection=(elements*(handle~))")
    XCTAssertEqual(LinkedInAPI.Endpoints.accessToken.url, "https://www.linkedin.com/oauth/v2/accessToken")
    XCTAssertEqual(LinkedInAPI.Endpoints.profile.url, "https://api.linkedin.com/v2/me")
    XCTAssertEqual(
      LinkedInAPI.Endpoints.email.url,
      "https://api.linkedin.com/v2/emailAddress?q=members&projection=(elements*(handle~))"
    )
  }
}

private extension LinkedInAPITests {
  func makeAPI() -> LinkedInAPI {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolMock.self]
    let session = URLSession(configuration: configuration)
    let client = HttpClient(session: session)
    return LinkedInAPI(client: client)
  }
}

private final class URLProtocolMock: URLProtocol {
  static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = Self.requestHandler else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }

    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
