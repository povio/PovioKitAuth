//
//  AppleAuthenticator+PovioKitAuth.swift
//  PovioKitAuth
//
//  Created by Borut Tomazin on 28/10/2022.
//  Copyright © 2026 Povio Inc. All rights reserved.
//

import AuthenticationServices
import UIKit

extension UIViewController: @retroactive ASAuthorizationControllerPresentationContextProviding {
  public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    view.window ?? UIWindow()
  }
}
