//
//  LinkedInAuthenticator.swift
//  PovioKitAuth
//
//  Created by Borut Tomazin on 04/09/2023.
//  Copyright © 2025 Povio Inc. All rights reserved.
//

import UIKit
import PovioKitAuthCore

public final class LinkedInAuthenticator {
  private let storage: UserDefaults
  private let storageIsAuthenticatedKey = "signIn.isAuthenticated"
  private let linkedInAPI: LinkedInAPI
  
  public init(storage: UserDefaults? = nil,
              linkedInAPI: LinkedInAPI = .init()) {
    self.storage = storage ?? .init(suiteName: "povioKit.auth.linkedIn") ?? .standard
    self.linkedInAPI = linkedInAPI
  }
}

// MARK: - Public Methods
extension LinkedInAuthenticator: Authenticator {
  /// SignIn user.
  ///
  /// Will asynchronously return the `Response` object on success or `Error` on error.
  public func signIn(authCode: String, configuration: Configuration) async throws -> Response {
    let authRequest: LinkedInAPI.LinkedInAuthRequest = .init(
      code: authCode,
      redirectUri: configuration.redirectUrl.absoluteString,
      clientId: configuration.clientId,
      clientSecret: configuration.clientSecret
    )
    let authResponse = try await linkedInAPI.login(with: authRequest)
    let profileResponse = try await linkedInAPI.loadProfile(with: .init(token: authResponse.accessToken))
    let emailResponse = try await linkedInAPI.loadEmail(with: .init(token: authResponse.accessToken))
    
    storage.set(true, forKey: storageIsAuthenticatedKey)
    
    var nameComponents = PersonNameComponents()
    nameComponents.givenName = profileResponse.localizedFirstName
    nameComponents.familyName = profileResponse.localizedLastName
    
    return Response(
      userId: profileResponse.id,
      token: authResponse.accessToken,
      nameComponents: nameComponents,
      email: emailResponse.emailAddress,
      expiresAt: authResponse.expiresIn
    )
  }
  
  /// Clears the signIn footprint and logs out the user immediatelly.
  public func signOut() {
    storage.removeObject(forKey: storageIsAuthenticatedKey)
  }
  
  /// Returns the current authentication state.
  public var isAuthenticated: Authenticated {
    storage.bool(forKey: storageIsAuthenticatedKey)
  }
  
  /// Boolean if given `url` should be handled.
  ///
  /// Call this from UIApplicationDelegate’s `application:openURL:options:` method.
  public func canOpenUrl(_ url: URL, application: UIApplication, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
    true
  }
}
