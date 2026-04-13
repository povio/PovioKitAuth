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
}
