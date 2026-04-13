//
//  LinkedInWebView.swift
//  PovioKitAuth
//
//  Created by Borut Tomazin on 04/09/2023.
//  Copyright © 2025 Povio Inc. All rights reserved.
//

import SwiftUI
@preconcurrency import WebKit

@available(iOS 15.0, *)
public struct LinkedInWebView: UIViewRepresentable {
  @Environment(\.dismiss) var dismiss
  // Keep an unpredictable value for OAuth state validation.
  public typealias SuccessHandler = ((code: String, state: String)) -> Void
  public typealias ErrorHandler = () -> Void
  private let requestState: String = UUID().uuidString.replacingOccurrences(of: "-", with: "")
  private let webView: WKWebView
  private let configuration: LinkedInAuthenticator.Configuration
  public let onSuccess: SuccessHandler?
  public let onFailure: ErrorHandler?
  
  public init(with configuration: LinkedInAuthenticator.Configuration,
              onSuccess: @escaping SuccessHandler,
              onFailure: @escaping ErrorHandler) {
    self.configuration = configuration
    let config = WKWebViewConfiguration()
    config.websiteDataStore = WKWebsiteDataStore.default()
    webView = WKWebView(frame: .zero, configuration: config)
    self.onSuccess = onSuccess
    self.onFailure = onFailure
  }
  
  public func makeUIView(context: Context) -> some UIView {
    webView
  }
  
  public func updateUIView(_ uiView: UIViewType, context: Context) {
    guard !context.coordinator.didLoadInitialRequest else { return }
    guard let webView = uiView as? WKWebView else { return }
    guard let authURL = configuration.authorizationUrl(state: requestState) else {
      dismiss()
      return
    }
    webView.navigationDelegate = context.coordinator
    webView.load(.init(url: authURL))
    context.coordinator.didLoadInitialRequest = true
  }
  
  public func makeCoordinator() -> Coordinator {
    Coordinator(self, requestState: requestState)
  }
}

@available(iOS 15.0, *)
public extension LinkedInWebView {
  class Coordinator: NSObject, WKNavigationDelegate {
    private let parent: LinkedInWebView
    private let requestState: String
    fileprivate var didLoadInitialRequest: Bool = false
    
    public init(_ parent: LinkedInWebView, requestState: String) {
      self.parent = parent
      self.requestState = requestState
    }
    
    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
      // if authCancel endpoint was called, dismiss the view
      if let url = navigationAction.request.url,
         url.absoluteString.hasPrefix(parent.configuration.authCancel.absoluteString) {
        decisionHandler(.cancel)
        parent.dismiss()
        return
      }
      
      // extract the authorization code from the redirect url
      guard let url = navigationAction.request.url,
            url.host == parent.configuration.redirectUrl.host,
            let components = URLComponents(string: url.absoluteString),
            let state = components.queryItems?.first(where: { $0.name == "state" })?.value,
            requestState == state,
            let code = components.queryItems?.first(where: { $0.name == "code" }) else {
        decisionHandler(.allow)
        return
      }
      parent.onSuccess?((code.value ?? "", parent.requestState))
      decisionHandler(.cancel)
      parent.dismiss()
    }
  }
}
