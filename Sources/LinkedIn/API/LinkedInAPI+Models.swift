//
//  LinkedInAPI+Models.swift
//  PovioKitAuth
//
//  Created by Borut Tomazin on 04/09/2023.
//  Copyright © 2026 Povio Inc. All rights reserved.
//

import Foundation

public extension LinkedInAPI {
  struct LinkedInAuthRequest: Encodable {
    let grantType: String = "authorization_code"
    let code: String
    let redirectUri: String
    let clientId: String
    let clientSecret: String
    
    public init(code: String, redirectUri: String, clientId: String, clientSecret: String) {
      self.code = code
      self.redirectUri = redirectUri
      self.clientId = clientId
      self.clientSecret = clientSecret
    }
  }
  
  struct LinkedInAuthResponse: Decodable {
    public let accessToken: String
    public let expiresIn: Date
  }
  
  struct LinkedInProfileRequest: Encodable {
    let token: String
    
    public init(token: String) {
      self.token = token
    }
  }
  
  struct LinkedInProfileResponse: Decodable {
    public let id: String
    public let localizedFirstName: String
    public let localizedLastName: String
  }
  
  struct LinkedInEmailResponse: Decodable {
    public let elements: [LinkedInEmailHandleResponse]
  }
  
  struct LinkedInEmailHandleResponse: Decodable {
    public let handle: LinkedInEmailValueResponse
    
    enum CodingKeys: String, CodingKey {
      case handle = "handle~"
    }
  }
  
  struct LinkedInEmailValueResponse: Decodable {
    public let emailAddress: String
  }
}
