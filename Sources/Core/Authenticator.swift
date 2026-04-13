//
//  Authenticator.swift
//  PovioKitAuth
//
//  Created by Borut Tomazin on 20/01/2023.
//  Copyright © 2026 Povio Inc. All rights reserved.
//

import UIKit

public protocol Authenticator {
  typealias Authenticated = Bool
  
  var isAuthenticated: Authenticated { get }
  func signOut()
  func canOpenUrl(_ url: URL, application: UIApplication, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool
}
