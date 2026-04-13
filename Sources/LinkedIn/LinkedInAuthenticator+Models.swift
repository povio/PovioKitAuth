//
//  LinkedInAuthenticator+Models.swift
//  PovioKitAuth
//
//  Created by Borut Tomazin on 30/01/2023.
//  Copyright © 2025 Povio Inc. All rights reserved.
//

import Foundation

public extension LinkedInAuthenticator {
  struct Configuration {
    let clientId: String
    let clientSecret: String
    let permissions: String
    let redirectUrl: URL
    var authEndpoint: URL = "https://www.linkedin.com/oauth/v2/authorization"
    var authCancel: URL = "https://www.linkedin.com/oauth/v2/login-cancel"
    var audience: String?
    public var codeVerifier: String?
    var codeChallenge: String?
    var codeChallengeMethod: String?
    
    public init(
      clientId: String,
      clientSecret: String,
      permissions: String,
      redirectUrl: URL
    ) {
      self.clientId = clientId
      self.clientSecret = clientSecret
      self.permissions = permissions
      self.redirectUrl = redirectUrl
    }
    
    public init(
      clientId: String,
      clientSecret: String,
      permissions: String,
      redirectUrl: URL,
      authEndpoint: URL,
      authCancel: URL,
      audience: String?,
      codeVerifier: String?,
      codeChallenge: String?,
      codeChallengeMethod: String?
    ) {
      self.clientId = clientId
      self.clientSecret = clientSecret
      self.permissions = permissions
      self.redirectUrl = redirectUrl
      self.authEndpoint = authEndpoint
      self.authCancel = authCancel
      self.audience = audience
      self.codeVerifier = codeVerifier
      self.codeChallenge = codeChallenge
      self.codeChallengeMethod = codeChallengeMethod
    }
    
    public func authorizationUrl(state: String) -> URL? {
      guard var urlComponents = URLComponents(url: authEndpoint, resolvingAgainstBaseURL: false) else { return nil }
      var queryItems: [URLQueryItem] = [
        .init(name: "response_type", value: "code"),
        .init(name: "connection", value: "linkedin"),
        .init(name: "client_id", value: clientId),
        .init(name: "redirect_uri", value: redirectUrl.absoluteString),
        .init(name: "state", value: state),
        .init(name: "scope", value: permissions)
      ]
      
      if let audience {
        queryItems.append(.init(name: "audience", value: audience))
      }
      if let codeChallenge {
        queryItems.append(.init(name: "code_challenge", value: codeChallenge))
      }
      if let codeChallengeMethod {
        queryItems.append(.init(name: "code_challenge_method", value: codeChallengeMethod))
      }
      
      urlComponents.queryItems = queryItems
      return urlComponents.url
    }
  }
  
  struct Response {
    public let userId: String
    public let token: String
    public let nameComponents: PersonNameComponents
    public let email: String
    public let expiresAt: Date
    
    /// User full name represented by `givenName` and `familyName`
    public var name: String? {
      nameComponents.name
    }
  }
}
