//
//  JWTDecoderEdgeCaseTests.swift
//  PovioKitAuth_Tests
//
//  Created by Cursor on 10/04/2026.
//

import XCTest
import Foundation
import PovioKitAuthCore

final class JWTDecoderEdgeCaseTests: XCTestCase {
  func test_init_withInvalidStructure_throws() {
    XCTAssertThrowsError(try JWTDecoder(token: "only.two"))
  }

  func test_bool_parsesBooleanFromStringPayload() throws {
    let token = makeToken(header: ["alg": "HS256"], payload: ["email_verified": "true"])
    let decoder = try JWTDecoder(token: token)

    XCTAssertEqual(decoder.bool(for: "email_verified"), true)
  }

  func test_expiresAt_parsesStringDatePayload() throws {
    let token = makeToken(header: ["alg": "HS256"], payload: ["exp": "1516239022"])
    let decoder = try JWTDecoder(token: token)

    XCTAssertEqual(decoder.expiresAt?.timeIntervalSince1970, 1516239022)
  }

  func test_isExpired_whenExpirationIsInPast_returnsTrue() throws {
    let token = makeToken(header: ["alg": "HS256"], payload: ["exp": 1.0])
    let decoder = try JWTDecoder(token: token)

    XCTAssertTrue(decoder.isExpired)
  }
}

private extension JWTDecoderEdgeCaseTests {
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
}
