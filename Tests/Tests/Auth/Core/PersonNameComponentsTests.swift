//
//  PersonNameComponentsTests.swift
//  PovioKitAuth_Tests
//
//  Created by Cursor on 10/04/2026.
//

import XCTest
import Foundation
import PovioKitAuthCore

final class PersonNameComponentsTests: XCTestCase {
  func test_name_whenBothGivenAndFamilyAvailable_returnsFullName() {
    var components = PersonNameComponents()
    components.givenName = "Ada"
    components.familyName = "Lovelace"
    XCTAssertEqual(components.name, "Ada Lovelace")
  }

  func test_name_whenOnlyGivenNameAvailable_returnsGivenName() {
    var components = PersonNameComponents()
    components.givenName = "Ada"
    XCTAssertEqual(components.name, "Ada")
  }

  func test_name_whenOnlyFamilyNameAvailable_returnsFamilyName() {
    var components = PersonNameComponents()
    components.familyName = "Lovelace"
    XCTAssertEqual(components.name, "Lovelace")
  }

  func test_name_whenMissingBothGivenAndFamily_returnsNil() {
    let components = PersonNameComponents()
    XCTAssertNil(components.name)
  }

  func test_init_setsAllProvidedFields() {
    let phonetic = PersonNameComponents(middleName: nil, givenName: "Eh-duh", familyName: "Luhv-lace")
    let components = PersonNameComponents(
      namePrefix: "Dr.",
      middleName: "Byron",
      givenName: "Ada",
      familyName: "Lovelace",
      nameSuffix: "III",
      nickname: "Countess",
      phoneticRepresentation: phonetic
    )
    let reference = PersonNameComponents(
      namePrefix: "Dr.",
      givenName: "Ada",
      middleName: "Byron",
      familyName: "Lovelace",
      nameSuffix: "III",
      nickname: "Countess",
      phoneticRepresentation: phonetic
    )

    XCTAssertEqual(components.namePrefix, "Dr.")
    XCTAssertEqual(components.middleName, "Byron")
    XCTAssertEqual(components.givenName, "Ada")
    XCTAssertEqual(components.familyName, "Lovelace")
    XCTAssertEqual(components.nameSuffix, "III")
    XCTAssertEqual(components.nickname, "Countess")
    XCTAssertEqual(components.phoneticRepresentation?.givenName, "Eh-duh")
    XCTAssertEqual(components.phoneticRepresentation?.familyName, "Luhv-lace")
    XCTAssertEqual(reference.middleName, "Byron")
  }
}
