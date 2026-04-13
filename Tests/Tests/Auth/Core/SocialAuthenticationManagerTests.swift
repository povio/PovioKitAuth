//
//  SocialAuthenticationManagerTests.swift
//  PovioKitAuth_Tests
//
//  Created by Cursor on 10/04/2026.
//

import XCTest
import UIKit
import PovioKitAuthCore

final class SocialAuthenticationManagerTests: XCTestCase {
  func test_isAuthenticated_whenAnyAuthenticatorIsAuthenticated_returnsTrue() {
    let first = MockAuthenticator(isAuthenticated: false, canOpenUrlResult: false)
    let second = MockAuthenticator(isAuthenticated: true, canOpenUrlResult: false)
    let sut = SocialAuthenticationManager(authenticators: [first, second])

    XCTAssertTrue(sut.isAuthenticated)
  }

  func test_currentAuthenticator_returnsFirstAuthenticatedAuthenticator() {
    let first = MockAuthenticator(isAuthenticated: false, canOpenUrlResult: false)
    let second = MockAuthenticator(isAuthenticated: true, canOpenUrlResult: false)
    let third = MockAuthenticator(isAuthenticated: true, canOpenUrlResult: false)
    let sut = SocialAuthenticationManager(authenticators: [first, second, third])

    XCTAssertTrue(sut.currentAuthenticator as AnyObject === second)
  }

  func test_authenticatorFor_returnsRequestedType() {
    let primary = PrimaryAuthenticator(isAuthenticated: false, canOpenUrlResult: false)
    let secondary = SecondaryAuthenticator(isAuthenticated: true, canOpenUrlResult: false)
    let sut = SocialAuthenticationManager(authenticators: [primary, secondary])

    let resolved: SecondaryAuthenticator? = sut.authenticator(for: SecondaryAuthenticator.self)
    XCTAssertNotNil(resolved)
    XCTAssertTrue(resolved as AnyObject === secondary)
  }

  func test_signOut_callsAllAuthenticators() {
    let first = MockAuthenticator(isAuthenticated: true, canOpenUrlResult: false)
    let second = MockAuthenticator(isAuthenticated: false, canOpenUrlResult: false)
    let sut = SocialAuthenticationManager(authenticators: [first, second])

    sut.signOut()

    XCTAssertEqual(first.signOutCalls, 1)
    XCTAssertEqual(second.signOutCalls, 1)
  }

  @MainActor
  func test_canOpenUrl_whenAnyAuthenticatorCanOpen_returnsTrue() {
    let first = MockAuthenticator(isAuthenticated: false, canOpenUrlResult: false)
    let second = MockAuthenticator(isAuthenticated: false, canOpenUrlResult: true)
    let sut = SocialAuthenticationManager(authenticators: [first, second])

    let canOpen = sut.canOpenUrl(
      URL(string: "myapp://callback")!,
      application: UIApplication.shared,
      options: [:]
    )

    XCTAssertTrue(canOpen)
  }
}

private class MockAuthenticator: Authenticator {
  var isAuthenticated: Authenticated
  var signOutCalls: Int = 0
  let canOpenUrlResult: Bool

  init(isAuthenticated: Bool, canOpenUrlResult: Bool) {
    self.isAuthenticated = isAuthenticated
    self.canOpenUrlResult = canOpenUrlResult
  }

  func signOut() {
    signOutCalls += 1
  }

  func canOpenUrl(_ url: URL, application: UIApplication, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
    canOpenUrlResult
  }
}

private final class PrimaryAuthenticator: MockAuthenticator {}
private final class SecondaryAuthenticator: MockAuthenticator {}
