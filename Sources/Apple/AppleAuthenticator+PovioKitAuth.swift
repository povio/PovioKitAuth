//
//  AppleAuthenticator+PovioKitAuth.swift
//  PovioKitAuth
//
//  Created by Borut Tomazin on 28/10/2022.
//  Copyright © 2025 Povio Inc. All rights reserved.
//

import AuthenticationServices
import CryptoKit
import UIKit

extension UIViewController: @retroactive ASAuthorizationControllerPresentationContextProviding {
  public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    view.window ?? UIWindow()
  }
}

public extension String {
  var sha256: String {
    SHA256
      .hash(data: Data(utf8))
      .compactMap { String(format: "%02x", $0) }
      .joined()
  }
}
