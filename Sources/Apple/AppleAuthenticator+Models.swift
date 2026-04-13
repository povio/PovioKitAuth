//
//  AppleAuthenticator+Models.swift
//  PovioKitAuth
//
//  Created by Borut Tomazin on 28/10/2022.
//  Copyright © 2026 Povio Inc. All rights reserved.
//

import AuthenticationServices
import Foundation

public extension AppleAuthenticator {
  struct Response {
    public let userId: String
    public let token: String
    public let authCode: String
    public let nameComponents: PersonNameComponents?
    public let email: Email
    public let expiresAt: Date
    
    /// User full name represented by `givenName` and `familyName`
    public var name: String? {
      nameComponents?.name
    }
  }
  
  struct Email: Codable {
    public let address: String
    public let isPrivate: Bool
    public let isVerified: Bool
  }
  
  enum Error: Swift.Error {
    case system(_ error: Swift.Error)
    case cancelled
    case signInInProgress
    case invalidIdentityToken
    case unhandledAuthorization
    case credentialsRevoked
    case missingExpiration
    case missingEmail
  }
  
  struct UserData: Codable {
    let name: PersonNameComponents?
    let email: Email
  }
}
