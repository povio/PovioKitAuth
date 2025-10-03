//
//  URL+PovioKitAuth.swift
//  PovioKitAuth
//
//  Created by Borut Tomazin on 22/05/2024.
//  Copyright © 2025 Povio Inc. All rights reserved.
//

import Foundation

extension URL: @retroactive ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    guard let url = URL(string: value) else {
      fatalError("Invalid URL string!")
    }
    self = url
  }
}
