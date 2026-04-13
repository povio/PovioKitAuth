//
//  SignInView.swift
//  PovioKitAuthDemo
//
//  Created by Borut Tomazin on 10/05/2024.
//  Copyright © 2026 Povio Inc. All rights reserved.
//

import SwiftUI

struct SignInView: View {
  let viewModel: SignInViewModel
  @State private var showErrorAlert: Bool = false
  @State private var showSuccessAlert: Bool = false
  
  var body: some View {
    VStack(spacing: 20) {
      Button {
        viewModel.signInWithApple()
      } label: {
        Text("SignIn with Apple")
      }
      Button {
        viewModel.signInWithGoogle()
      } label: {
        Text("SignIn with Google")
      }
      Button {
        viewModel.signInWithFacebook()
      } label: {
        Text("SignIn with Facebook")
      }
      Button {
        viewModel.signInWithLinkedIn()
      } label: {
        Text("SignIn with LinkedIn")
      }
    }
    .onChange(of: viewModel.error) { oldValue, newValue in
      showErrorAlert = true
    }
    .onChange(of: viewModel.success) { oldValue, newValue in
      showSuccessAlert = true
    }
    .alert("Error", isPresented: $showErrorAlert) {
      Button("Ok", action: {})
    } message: {
      Text(viewModel.error)
    }
    .alert("Success", isPresented: $showSuccessAlert) {
      Button("Ok", action: {})
    } message: {
      Text(viewModel.success)
    }
  }
}

#Preview {
  SignInView(viewModel: .init())
}
