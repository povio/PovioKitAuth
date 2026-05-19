//
//  KeychainServiceTests.swift
//  PovioKitAuth_Tests
//
//  Created by Cursor on 18/05/2026.
//

import XCTest
import PovioKitAuthCore

final class KeychainServiceTests: XCTestCase {
  private struct StoredProfile: Codable, Equatable {
    let id: Int
    let name: String
  }

  func test_name_returnsConfiguredServiceName() {
    let serviceName = makeServiceName()
    let service = KeychainService(name: serviceName)

    XCTAssertEqual(service.name, serviceName)
  }

  func test_saveString_andReadString_roundTripValue() throws {
    let service = try makeEntitledServiceOrSkip()
    let key = "user_email"
    try service.clear()

    try service.saveString("ada@povio.com", for: key)

    XCTAssertEqual(service.readString(for: key), "ada@povio.com")

    try service.clear()
  }

  func test_saveString_withNil_removesStoredValue() throws {
    let service = try makeEntitledServiceOrSkip()
    let key = "temporary"
    try service.clear()
    try service.saveString("value", for: key)

    try service.saveString(nil, for: key)

    XCTAssertNil(service.readString(for: key))
    try service.clear()
  }

  func test_saveAndReadCodable_roundTripObject() throws {
    let service = try makeEntitledServiceOrSkip()
    let key = "profile"
    let expected = StoredProfile(id: 7, name: "Ada")
    try service.clear()

    try service.save(expected, for: key)

    let actual: StoredProfile? = service.read(StoredProfile.self, for: key)
    XCTAssertEqual(actual, expected)
    try service.clear()
  }

  func test_readCodable_whenDecodingFails_returnsNil() throws {
    let service = try makeEntitledServiceOrSkip()
    let key = "profile"
    try service.clear()
    try service.saveString("not-json", for: key)

    let profile: StoredProfile? = service.read(StoredProfile.self, for: key)

    XCTAssertNil(profile)
    try service.clear()
  }
}

private extension KeychainServiceTests {
  func makeService() -> KeychainService {
    KeychainService(name: makeServiceName())
  }

  func makeEntitledServiceOrSkip() throws -> KeychainService {
    let service = makeService()
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

  func makeServiceName() -> String {
    "dev.povio.auth.tests.\(UUID().uuidString)"
  }
}
