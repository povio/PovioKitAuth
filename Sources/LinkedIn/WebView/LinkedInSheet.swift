//
//  File.swift
//
//
//  Created by Borut Tomazin on 04/09/2023.
//

import SwiftUI

public struct LinkedInSheet: ViewModifier {
  public typealias SuccessHandler = LinkedInWebView.SuccessHandler // (Bool) -> Void
  public typealias ErrorHandler = LinkedInWebView.ErrorHandler // (Error) -> Void
  public let config: LinkedInAuthenticator.Configuration
  public let isPresented: Binding<Bool>
  public let onSuccess: SuccessHandler?
  public let onError: ErrorHandler?
  
  public func body(content: Content) -> some View {
    content
      .sheet(isPresented: isPresented) {
        LinkedInWebView(with: config) { data in
          onSuccess?(data)
        } onFailure: {
          onError?()
        }
      }
  }
}

public extension View {
  /// ViewModifier to present `LinkedInWebView` in sheet
  func linkedInSheet(with config: LinkedInAuthenticator.Configuration,
                     isPresented: Binding<Bool>,
                     onSuccess: LinkedInSheet.SuccessHandler? = nil,
                     onError: LinkedInSheet.ErrorHandler? = nil) -> some View {
    modifier(LinkedInSheet(config: config, isPresented: isPresented, onSuccess: onSuccess, onError: onError))
  }
}
