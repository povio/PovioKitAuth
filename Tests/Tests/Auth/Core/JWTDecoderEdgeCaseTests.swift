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
  private struct Profile: Decodable, Equatable {
    let firstName: String
    let age: Int
  }
  
  func test_init_withInvalidStructure_throwsInvalidStructure() {
    XCTAssertThrowsError(try JWTDecoder(token: "only.two")) { error in
      XCTAssertEqual(error as? JWTDecoder.Error, .invalidStructure)
    }
  }
  
  func test_init_withInvalidBase64Header_throwsInvalidBase64Header() {
    let token = "*.eyJzdWIiOiIxMjMifQ.signature"
    XCTAssertThrowsError(try JWTDecoder(token: token)) { error in
      XCTAssertEqual(error as? JWTDecoder.Error, .invalidBase64(component: "header"))
    }
  }
  
  func test_init_withInvalidBase64Payload_throwsInvalidBase64Payload() {
    let validHeader = encodeBase64URL(from: ["alg": "HS256"])
    let token = "\(validHeader).*.signature"
    
    XCTAssertThrowsError(try JWTDecoder(token: token)) { error in
      XCTAssertEqual(error as? JWTDecoder.Error, .invalidBase64(component: "payload"))
    }
  }
  
  func test_init_withInvalidJsonHeader_throwsInvalidJsonHeader() {
    let invalidHeader = encodeBase64URL(rawJSON: "\"not-an-object\"")
    let validPayload = encodeBase64URL(from: ["sub": "123"])
    let token = "\(invalidHeader).\(validPayload).signature"
    
    XCTAssertThrowsError(try JWTDecoder(token: token)) { error in
      XCTAssertEqual(error as? JWTDecoder.Error, .invalidJson(component: "header"))
    }
  }
  
  func test_init_withInvalidJsonPayload_throwsInvalidJsonPayload() {
    let validHeader = encodeBase64URL(from: ["alg": "HS256"])
    let invalidPayload = encodeBase64URL(rawJSON: "[1,2,3]")
    let token = "\(validHeader).\(invalidPayload).signature"
    
    XCTAssertThrowsError(try JWTDecoder(token: token)) { error in
      XCTAssertEqual(error as? JWTDecoder.Error, .invalidJson(component: "payload"))
    }
  }
  
  func test_decode_acceptsUnpaddedBase64URL() throws {
    let token = makeToken(
      header: ["alg": "HS256", "typ": "JWT"],
      payload: ["sub": "abc123", "exp": 4_102_444_800] // 2100-01-01
    )
    
    let decoder = try JWTDecoder(token: token)
    XCTAssertEqual(decoder.algorithm, "HS256")
    XCTAssertEqual(decoder.subject, "abc123")
    XCTAssertEqual(decoder.expiresAt?.timeIntervalSince1970, 4_102_444_800)
  }
  
  func test_bool_parsing_supportsBooleanNumberAndStringRepresentations() throws {
    let token = makeToken(
      header: ["alg": "HS256"],
      payload: [
        "asBoolTrue": true,
        "asNumberOne": 1,
        "asStringTrueUpper": " TRUE ",
        "asStringOne": "1",
        "asBoolFalse": false,
        "asNumberZero": 0,
        "asStringFalse": "false",
        "asStringZero": "0",
        "invalid": "yes"
      ]
    )
    
    let decoder = try JWTDecoder(token: token)
    
    XCTAssertEqual(decoder.bool(for: "asBoolTrue"), true)
    XCTAssertEqual(decoder.bool(for: "asNumberOne"), true)
    XCTAssertEqual(decoder.bool(for: "asStringTrueUpper"), true)
    XCTAssertEqual(decoder.bool(for: "asStringOne"), true)
    XCTAssertEqual(decoder.bool(for: "asBoolFalse"), false)
    XCTAssertEqual(decoder.bool(for: "asNumberZero"), false)
    XCTAssertEqual(decoder.bool(for: "asStringFalse"), false)
    XCTAssertEqual(decoder.bool(for: "asStringZero"), false)
    XCTAssertNil(decoder.bool(for: "invalid"))
    XCTAssertNil(decoder.bool(for: "missing"))
  }
  
  func test_string_parsing_returnsExpectedValueOrNil() throws {
    let token = makeToken(header: ["alg": "HS256"], payload: ["name": "John", "count": 1])
    let decoder = try JWTDecoder(token: token)
    
    XCTAssertEqual(decoder.string(for: "name"), "John")
    XCTAssertNil(decoder.string(for: "count"))
    XCTAssertNil(decoder.string(for: "missing"))
  }
  
  func test_double_parsing_supportsStringIntDoubleAndNSNumber() throws {
    let token = makeToken(
      header: ["alg": "HS256"],
      payload: ["fromInt": 7, "fromDouble": 7.5, "fromString": "8.75", "invalid": "abc"]
    )
    let decoder = try JWTDecoder(token: token)
    
    XCTAssertEqual(decoder.double(for: "fromInt"), 7)
    XCTAssertEqual(decoder.double(for: "fromDouble"), 7.5)
    XCTAssertEqual(decoder.double(for: "fromString"), 8.75)
    XCTAssertNil(decoder.double(for: "invalid"))
    XCTAssertNil(decoder.double(for: "missing"))
  }
  
  func test_int_parsing_supportsStringIntDoubleAndNSNumber() throws {
    let token = makeToken(
      header: ["alg": "HS256"],
      payload: ["fromInt": 7, "fromDouble": 7.9, "fromString": "8", "invalid": "abc"]
    )
    let decoder = try JWTDecoder(token: token)
    
    XCTAssertEqual(decoder.int(for: "fromInt"), 7)
    XCTAssertEqual(decoder.int(for: "fromDouble"), 7) // truncates toward zero
    XCTAssertEqual(decoder.int(for: "fromString"), 8)
    XCTAssertNil(decoder.int(for: "invalid"))
    XCTAssertNil(decoder.int(for: "missing"))
  }
  
  func test_date_parsing_supportsStringIntDouble() throws {
    let token = makeToken(
      header: ["alg": "HS256"],
      payload: ["fromString": "1516239022", "fromInt": 1516239023, "fromDouble": 1516239024.5]
    )
    let decoder = try JWTDecoder(token: token)
    
    XCTAssertEqual(decoder.date(for: "fromString")?.timeIntervalSince1970, 1516239022)
    XCTAssertEqual(decoder.date(for: "fromInt")?.timeIntervalSince1970, 1516239023)
    XCTAssertEqual(decoder.date(for: "fromDouble")?.timeIntervalSince1970, 1516239024.5)
    XCTAssertNil(decoder.date(for: "missing"))
  }
  
  func test_standardDateClaims_mapToTypedDateAccessors() throws {
    let token = makeToken(
      header: ["alg": "HS256"],
      payload: ["iat": 100, "exp": 200, "nbf": 300]
    )
    let decoder = try JWTDecoder(token: token)
    
    XCTAssertEqual(decoder.issuedAt?.timeIntervalSince1970, 100)
    XCTAssertEqual(decoder.expiresAt?.timeIntervalSince1970, 200)
    XCTAssertEqual(decoder.notBefore?.timeIntervalSince1970, 300)
  }
  
  func test_isExpired_whenExpirationIsInPast_returnsTrue() throws {
    let token = makeToken(header: ["alg": "HS256"], payload: ["exp": 1.0])
    let decoder = try JWTDecoder(token: token)
    
    XCTAssertTrue(decoder.isExpired)
  }
  
  func test_isExpired_whenExpirationIsInFuture_returnsFalse() throws {
    let token = makeToken(header: ["alg": "HS256"], payload: ["exp": 4_102_444_800])
    let decoder = try JWTDecoder(token: token)
    
    XCTAssertFalse(decoder.isExpired)
  }
  
  func test_isExpired_whenExpirationMissing_returnsFalse() throws {
    let token = makeToken(header: ["alg": "HS256"], payload: ["sub": "abc"])
    let decoder = try JWTDecoder(token: token)
    
    XCTAssertFalse(decoder.isExpired)
  }
  
  func test_standardHeaderAndPayloadAccessors_readValuesCorrectly() throws {
    let token = makeToken(
      header: ["alg": "HS256"],
      payload: ["iss": "issuer", "sub": "subject", "jti": "identifier"]
    )
    let decoder = try JWTDecoder(token: token)
    
    XCTAssertEqual(decoder.algorithm, "HS256")
    XCTAssertEqual(decoder.issuer, "issuer")
    XCTAssertEqual(decoder.subject, "subject")
    XCTAssertEqual(decoder.identifier, "identifier")
  }
  
  func test_claim_decodesPrimitiveClaim() throws {
    let token = makeToken(header: ["alg": "HS256"], payload: ["tenant_id": 42])
    let decoder = try JWTDecoder(token: token)
    
    let tenantId: Int? = decoder.claim(for: "tenant_id")
    XCTAssertEqual(tenantId, 42)
  }
  
  func test_claim_decodesNestedDecodableClaim() throws {
    let token = makeToken(
      header: ["alg": "HS256"],
      payload: ["profile": ["firstName": "Ana", "age": 31]]
    )
    let decoder = try JWTDecoder(token: token)
    
    let profile: Profile? = decoder.claim(for: "profile")
    XCTAssertEqual(profile, Profile(firstName: "Ana", age: 31))
  }
  
  func test_headerClaim_decodesTypedHeaderClaim() throws {
    let token = makeToken(
      header: ["alg": "RS256", "kid": "kid-123"],
      payload: ["sub": "123"]
    )
    let decoder = try JWTDecoder(token: token)
    
    let kid: String? = decoder.headerClaim(for: "kid")
    XCTAssertEqual(kid, "kid-123")
  }
  
  func test_claim_whenTypeDoesNotMatch_returnsNil() throws {
    let token = makeToken(header: ["alg": "HS256"], payload: ["tenant_id": "abc"])
    let decoder = try JWTDecoder(token: token)
    
    let tenantId: Int? = decoder.claim(for: "tenant_id")
    XCTAssertNil(tenantId)
  }

  func test_errorDescription_providesReadableMessages() {
    XCTAssertEqual(
      JWTDecoder.Error.invalidStructure.errorDescription,
      "JWT token structure is invalid. Expected three dot-separated components."
    )
    XCTAssertEqual(
      JWTDecoder.Error.invalidBase64(component: "header").errorDescription,
      "Failed to decode Base64URL for JWT header component."
    )
    XCTAssertEqual(
      JWTDecoder.Error.invalidJson(component: "payload").errorDescription,
      "Failed to parse JSON in JWT payload component."
    )
  }

  func test_bool_whenStringIsUnrecognizedOrNumericStringHasDifferentValue_returnsNil() throws {
    let token = makeToken(
      header: ["alg": "HS256"],
      payload: ["yes": "yes", "two": "2"]
    )
    let decoder = try JWTDecoder(token: token)

    XCTAssertNil(decoder.bool(for: "yes"))
    XCTAssertNil(decoder.bool(for: "two"))
  }

  func test_double_whenValueIsBooleanNumber_returnsOneOrZero() throws {
    let token = makeToken(header: ["alg": "HS256"], payload: ["trueValue": true, "falseValue": false])
    let decoder = try JWTDecoder(token: token)

    XCTAssertEqual(decoder.double(for: "trueValue"), 1)
    XCTAssertEqual(decoder.double(for: "falseValue"), 0)
  }

  func test_int_whenValueIsBooleanNumber_returnsOneOrZero() throws {
    let token = makeToken(header: ["alg": "HS256"], payload: ["trueValue": true, "falseValue": false])
    let decoder = try JWTDecoder(token: token)

    XCTAssertEqual(decoder.int(for: "trueValue"), 1)
    XCTAssertEqual(decoder.int(for: "falseValue"), 0)
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
  
  func encodeBase64URL(rawJSON: String) -> String {
    let data = Data(rawJSON.utf8)
    let base64 = data.base64EncodedString()
    return base64
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
