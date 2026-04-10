//
//  NonceTests.swift
//  PovioKitAuth_Tests
//
//  Created by Cursor on 10/04/2026.
//

import XCTest
import PovioKitAuthCore

final class NonceTests: XCTestCase {
  func test_customNonce_isHashedDeterministically() {
    let nonce = Nonce.custom(value: "hello-world")
    XCTAssertEqual(nonce.value, "afa27b44d43b02a9fea41d13cedc2e4016cfcf87c5dbf990e593669aa8ce286d")
  }

  func test_randomNonce_isSha256HexString() {
    let nonce = Nonce.random(length: 16)
    XCTAssertEqual(nonce.value.count, 64)
    XCTAssertNotNil(nonce.value.range(of: "^[0-9a-f]{64}$", options: .regularExpression))
  }
}
