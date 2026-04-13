//
//  DemoApp.swift
//  PovioKitAuthDemo
//
//  Created by Borut Tomazin on 10/05/2024.
//  Copyright © 2026 Povio Inc. All rights reserved.
//

import SwiftUI

@main
struct DemoApp: App {
  var body: some Scene {
    WindowGroup {
      SignInView(viewModel: .init())
    }
  }
}
