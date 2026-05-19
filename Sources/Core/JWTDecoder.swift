//
//  JWTDecoder.swift
//  PovioKitAuth
//
//  Created by Borut Tomazin on 10/1/2023.
//  Copyright © 2026 Povio Inc. All rights reserved.
//

import Foundation

/// JWTDecoder for decoding JSON Web Tokens (JWT) tokens
/// Inspired by https://github.com/auth0/jwt-decode
public struct JWTDecoder {
  public private(set) var header: [String: Any] = [:]
  public private(set) var payload: [String: Any] = [:]
  public let token: String
  
  public init(token: String) throws {
    self.token = token
    try decode()
  }
}

public extension JWTDecoder {
  /// Decoder-specific errors thrown while parsing a JWT token.
  enum Error: Swift.Error, LocalizedError, Equatable {
    case invalidStructure
    case invalidBase64(component: String)
    case invalidJson(component: String)
    
    public var errorDescription: String? {
      switch self {
      case .invalidStructure:
        return "JWT token structure is invalid. Expected three dot-separated components."
      case .invalidBase64(let component):
        return "Failed to decode Base64URL for JWT \(component) component."
      case .invalidJson(let component):
        return "Failed to parse JSON in JWT \(component) component."
      }
    }
  }
  
  var algorithm: String? {
    header["alg"] as? String
  }
  
  var issuer: String? {
    string(for: "iss")
  }
  
  var subject: String? {
    string(for: "sub")
  }
  
  var identifier: String? {
    string(for: "jti")
  }
  
  var issuedAt: Date? {
    date(for: "iat")
  }
  
  var expiresAt: Date? {
    date(for: "exp")
  }
  
  var notBefore: Date? {
    date(for: "nbf")
  }
  
  var isExpired: Bool {
    expiresAt.map { $0.compare(.init()) != .orderedDescending } ?? false
  }
  
  /// Decode a strongly typed value from payload claims.
  /// Useful for custom claims represented as nested JSON.
  func claim<T: Decodable>(for key: String, as type: T.Type = T.self) -> T? {
    decodeClaim(from: payload, for: key, as: type)
  }
  
  /// Decode a strongly typed value from header claims.
  func headerClaim<T: Decodable>(for key: String, as type: T.Type = T.self) -> T? {
    decodeClaim(from: header, for: key, as: type)
  }
  
  func bool(for key: String) -> Bool? {
    switch payload[key] {
    case let value as Bool:
      return value
    case let value as NSNumber:
      return value.boolValue
    case let value as String:
      switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
      case "true", "1":
        return true
      case "false", "0":
        return false
      default:
        return nil
      }
    default:
      return nil
    }
  }
  
  func string(for key: String) -> String? {
    payload[key] as? String
  }
  
  func double(for key: String) -> Double? {
    switch payload[key] {
    case let value as Double:
      return value
    case let value as Int:
      return Double(value)
    case let value as NSNumber:
      return value.doubleValue
    case let value as String:
      return Double(value)
    default:
      return nil
    }
  }
  
  func int(for key: String) -> Int? {
    switch payload[key] {
    case let value as Int:
      return value
    case let value as Double:
      return Int(value)
    case let value as NSNumber:
      return value.intValue
    case let value as String:
      return Int(value)
    default:
      return nil
    }
  }
  
  func date(for key: String) -> Date? {
    guard let interval = double(for: key) else { return nil }
    return Date(timeIntervalSince1970: interval)
  }
}

// MARK: - Private Methods
private extension JWTDecoder {
  struct ClaimContainer<T: Decodable>: Decodable {
    let value: T
  }
  
  mutating func decode() throws {
    let components = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    guard components.count == 3 else { throw Error.invalidStructure }
    
    self.header = try decode(component: components[0], name: "header")
    self.payload = try decode(component: components[1], name: "payload")
  }
  
  func decode(component: String, name: String) throws -> [String: Any] {
    let data = try decode(base64: component, name: name)
    guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
          let payload = json as? [String: Any] else {
      throw Error.invalidJson(component: name)
    }
    
    return payload
  }
  
  func decode(base64: String, name: String) throws -> Data {
    var decoded = base64
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    
    let remainder = decoded.count % 4
    if remainder > 0 {
      decoded += String(repeating: "=", count: 4 - remainder)
    }
    
    guard let data = Data(base64Encoded: decoded) else {
      throw Error.invalidBase64(component: name)
    }
    return data
  }
  
  func decodeClaim<T: Decodable>(from source: [String: Any], for key: String, as type: T.Type) -> T? {
    guard let rawValue = source[key] else { return nil }
    
    if let value = rawValue as? T {
      return value
    }
    
    guard JSONSerialization.isValidJSONObject(["value": rawValue]),
          let data = try? JSONSerialization.data(withJSONObject: ["value": rawValue]),
          let decoded = try? JSONDecoder().decode(ClaimContainer<T>.self, from: data) else {
      return nil
    }
    
    return decoded.value
  }
}
