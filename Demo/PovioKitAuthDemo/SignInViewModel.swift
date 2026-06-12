//
//  SignInViewModel.swift
//  PovioKitAuthDemo
//
//  Created by Borut Tomazin on 10/05/2024.
//  Copyright © 2026 Povio Inc. All rights reserved.
//

import UIKit
import SwiftUI
import PovioKitCore
import PovioKitAuthCore
import PovioKitAuthApple
import PovioKitAuthGoogle
import PovioKitAuthFacebook
import PovioKitAuthLinkedIn
import Observation

@MainActor
@Observable
final class SignInViewModel {
  private let socialAuthManager: SocialAuthenticationManager
  
  var error: String = ""
  var success: String = ""
  
  init() {
    socialAuthManager = SocialAuthenticationManager(authenticators: [
      AppleAuthenticator(),
      GoogleAuthenticator(),
      FacebookAuthenticator(),
      LinkedInAuthenticator()
    ])
  }
}

extension SignInViewModel {
  func signInWithApple() {
    guard let auth = socialAuthManager.authenticator(for: AppleAuthenticator.self) else { return }
    
    Task { @MainActor in
      do {
        _ = try await auth.signIn(from: UIViewController())
        self.success = "SignIn with Apple succeeded."
      } catch AppleAuthenticator.Error.cancelled {
        Logger.debug("Apple Auth cancelled.")
      } catch {
        Logger.error(error.localizedDescription)
        self.error = error.localizedDescription
      }
    }
  }
  
  // TODO: provide `GoogleService-Info.plist` configuration file
  func signInWithGoogle() {
    guard let auth = socialAuthManager.authenticator(for: GoogleAuthenticator.self) else { return }
    
    Task { @MainActor in
      do {
        _ = try await auth.signIn(from: UIViewController())
        self.success = "SignIn with Google succeeded."
      } catch GoogleAuthenticator.Error.cancelled {
        Logger.debug("Apple Auth cancelled.")
      } catch {
        Logger.error(error.localizedDescription)
        self.error = error.localizedDescription
      }
    }
  }
  
  // TODO: provide `FacebookAppID` to the `Info.plist`
  func signInWithFacebook() {
    guard let auth = socialAuthManager.authenticator(for: FacebookAuthenticator.self) else { return }
    
    Task { @MainActor in
      do {
        _ = try await auth.signIn(from: UIViewController())
        self.success = "SignIn with Facebook succeeded."
      } catch FacebookAuthenticator.Error.cancelled {
        Logger.debug("Apple Auth cancelled.")
      } catch {
        Logger.error(error.localizedDescription)
        self.error = error.localizedDescription
      }
    }
  }
  
  // TODO: provide configuration details
  func signInWithLinkedIn() {
    guard let auth = socialAuthManager.authenticator(for: LinkedInAuthenticator.self) else { return }
    
    Task { @MainActor in
      do {
        _ = try await auth.signIn(authCode: "...", configuration: .init(
          clientId: "...",
          clientSecret: "...",
          permissions: "email profile openid offline_access",
          redirectUrl: "..."))
        self.success = "SignIn with LinkedIn succeeded."
      } catch {
        Logger.error(error.localizedDescription)
        self.error = error.localizedDescription
      }
    }
  }
}
