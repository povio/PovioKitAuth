//
//  HttpClient.swift
//  PovioKitAuth
//
//  Created by Borut Tomazin on 22/05/2024.
//  Copyright © 2025 Povio Inc. All rights reserved.
//

import Foundation

enum HttpClientError: Swift.Error {
  case invalidResponse
  case unsuccessfulStatusCode(code: Int, responseBody: Data)
}

struct HttpClient {
  func request<D: Decodable>(
    method: String,
    url: URL,
    headers: [String: String]?,
    body: Data? = nil,
    decodeTo decode: D.Type,
    with decoder: JSONDecoder = .init()
  ) async throws -> D {
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = method
    urlRequest.allHTTPHeaderFields = headers
    urlRequest.httpBody = body
    
    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    
    guard let httpResponse = response as? HTTPURLResponse else {
      throw HttpClientError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw HttpClientError.unsuccessfulStatusCode(code: httpResponse.statusCode, responseBody: data)
    }
    
    return try decoder.decode(decode, from: data)
  }
}
