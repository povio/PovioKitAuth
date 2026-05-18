//
//  LinkedInAPI.swift
//  PovioKitAuth
//
//  Created by Borut Tomazin on 04/09/2023.
//  Copyright © 2026 Povio Inc. All rights reserved.
//

import Foundation

protocol LinkedInAPIProtocol {
  func login(with request: LinkedInAPI.LinkedInAuthRequest) async throws -> LinkedInAPI.LinkedInAuthResponse
  func loadProfile(with request: LinkedInAPI.LinkedInProfileRequest) async throws -> LinkedInAPI.LinkedInProfileResponse
  func loadEmail(with request: LinkedInAPI.LinkedInProfileRequest) async throws -> LinkedInAPI.LinkedInEmailValueResponse
}

public struct LinkedInAPI {
  private let client: HttpClient
  
  public init() {
    self.client = .init()
  }
  
  init(client: HttpClient) {
    self.client = client
  }
}

extension LinkedInAPI: LinkedInAPIProtocol {}

public extension LinkedInAPI {
  func login(with request: LinkedInAuthRequest) async throws -> LinkedInAuthResponse {
    guard let url = URL(string: Endpoints.accessToken.url) else {
      throw Error.invalidUrl
    }

    var components = URLComponents()
    components.queryItems = [
      .init(name: "grant_type", value: request.grantType),
      .init(name: "code", value: request.code),
      .init(name: "client_id", value: request.clientId),
      .init(name: "client_secret", value: request.clientSecret),
      .init(name: "redirect_uri", value: request.redirectUri)
    ]
    guard let bodyString = components.percentEncodedQuery else {
      throw Error.invalidRequest
    }
    let bodyData = Data(bodyString.utf8)
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let secondsRemaining = try container.decode(Int.self)
      return Date().addingTimeInterval(TimeInterval(secondsRemaining))
    }
    
    let response = try await client.request(
      method: "POST",
      url: url,
      headers: ["Content-Type": "application/x-www-form-urlencoded; charset=utf-8"],
      body: bodyData,
      decodeTo: LinkedInAuthResponse.self,
      with: decoder
    )
    
    return response
  }
  
  func loadProfile(with request: LinkedInProfileRequest) async throws -> LinkedInProfileResponse {
    guard let url = URL(string: Endpoints.profile.url) else { throw Error.invalidUrl }
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let response = try await client.request(
      method: "GET",
      url: url,
      headers: ["Authorization": "Bearer \(request.token)"],
      decodeTo: LinkedInProfileResponse.self,
      with: decoder
    )
    
    return response
  }
  
  func loadEmail(with request: LinkedInProfileRequest) async throws -> LinkedInEmailValueResponse {
    guard let url = URL(string: Endpoints.email.url) else { throw Error.invalidUrl }
    
    let response = try await client.request(
      method: "GET",
      url: url,
      headers: ["Authorization": "Bearer \(request.token)"],
      decodeTo: LinkedInEmailResponse.self
    )
    
    guard let emailObject = response.elements.first?.handle else {
      throw Error.invalidResponse
    }
    
    return emailObject
  }
}

// MARK: - Error
public extension LinkedInAPI {
  enum Error: Swift.Error {
    case missingParameters
    case invalidUrl
    case invalidRequest
    case invalidResponse
  }
}
