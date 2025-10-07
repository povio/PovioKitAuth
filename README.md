<p align="center">
    <img src="Resources/PovioKit.png" width="400" max-width="90%" alt="PovioKit" />
</p>

<p align="center">
    <a href="https://swiftpackageregistry.com/poviolabs/PovioKitAuth" alt="Package">
        <img src="https://img.shields.io/badge/SPM-Swift-lightgrey.svg" />
    </a>
    <a href="https://www.swift.org" alt="Swift">
        <img src="https://img.shields.io/badge/Swift-5-orange.svg" />
    </a>
    <a href="./LICENSE" alt="License">
        <img src="https://img.shields.io/badge/Licence-MIT-red.svg" />
    </a>
    <a href="https://github.com/poviolabs/PovioKitAuth/actions/workflows/Tests.yml" alt="Tests Status">
        <img src="https://github.com/poviolabs/PovioKitAuth/actions/workflows/Tests.yml/badge.svg" />
    </a>
</p>

<p align="center">
    Welcome to <b>PovioKitAuth</b>.
    <br />Auth packages with support for social providers as listed below.
</p>

## Packages

| [Core](Resources/Core) | [Apple](Resources/Apple) | [Google](Resources/Google) | [Facebook](Resources/Facebook) | [LinkedIn](Resources/LinkedIn) |
| :-: | :-: | :-: | :-: | :-: |

## Installation

### Swift Package Manager
- In Xcode, click `File` -> `Add Packages...`  
- Insert `https://github.com/poviolabs/PovioKitAuth` in the Search field.
- Select a desired `Dependency Rule`. Usually "Up to Next Major Version" with "2.1.0".
- Select "Add Package" button and check one or all given products from the list:
  - *PovioKitAuthCore* (core library)
  - *PovioKitAuthApple* (Apple auth components)
  - *PovioKitAuthLinkedIn* (LinkedIn auth components)
- Select "Add Package" again and you are done.

### Migration

Please read the [Migration](MIGRATING.md) document.

## Usage
You can leverage use of `SocialAuthenticationManager` as to simplify managing multiple instances at once.

### Use SocialAuthenticationManager directly as is
```swift
import PovioKitAuthCore
import PovioKitAuthApple
import PovioKitAuthFacebook

let manager = SocialAuthenticationManager(authenticators: [AppleAuthenticator(), LinkedInAuthenticator()])

// signIn user with Apple
let appleAuthenticator = manager.authenticator(for: AppleAuthenticator.self)
let result = try await appleAuthenticator?
  .signIn(from: <view-controller-instance>, with: .random(length: 32))
  
// signIn user with Facebook
let facebookAuthenticator = manager.authenticator(for: FacebookAuthenticator.self)
let result = try await facebookAuthenticator?
  .signIn(from: <view-controller-instance>, with: [.email])
  
// return currently authenticated authenticator
let authenticated: Authenticator? = manager.authenticator

// sign out currently signedIn authenticator
manager.signOut()

// check if any authenticator is authenticated
let boolValue = manager.isAuthenticated

// check if authenticated authenticator can open url
let canOpen = manager.canOpenUrl(<url>, application: <app>, options: <options>) 
```

### Use SocialAuthenticationManager with wrapper
```swift
final class WrapperManager {
  private let socialAuthManager: SocialAuthenticationManager
  
  init() {
    socialAuthManager = SocialAuthenticationManager(authenticators: [
      AppleAuthenticator(),
      GoogleAuthenticator(),
      SnapchatAuthenticator()
    ])
  }
}

extension AuthManager: Authenticator {
  var isAuthenticated: Authenticated {
    socialAuthManager.isAuthenticated
  }
  
  var currentAuthenticator: Authenticator? {
    socialAuthManager.currentAuthenticator
  }
  
  func authenticator<A: Authenticator>(for type: A.Type) -> A? {
    socialAuthManager.authenticator(for: type)
  }
  
  func signOut() {
    socialAuthManager.signOut()
  }
  
  func canOpenUrl(_ url: URL, application: UIApplication, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
    socialAuthManager.canOpenUrl(url, application: application, options: options)
  }
}
```

### Create a new authenticator
You can easily add new authenticator that is not built-in with PovioKitAuth package.

```swift
final class SnapchatAuthenticator: Authenticator {
  public func signIn(from presentingViewController: UIViewController) async throws -> Response {
    try await withCheckedThrowingContinuation { continuation in
      SCSDKLoginClient.login(from: presentingViewController) { [weak self] success, error in
        guard success, error == nil else {
          continuation.resume(throwing: error)
          return
        }
        
        let query = "{me{displayName, bitmoji{avatar}}}"
        let variables = ["page": "bitmoji"]
        SCSDKLoginClient.fetchUserData(withQuery: query, variables: variables) { resources in
          ...
          continuation.resume(returning: response)
        }
      }
    }
  }
  
  func signOut() {
    SCSDKLoginClient.clearToken()
  }
  
  var isAuthenticated: Authenticated {
    SCSDKLoginClient.isUserLoggedIn
  }
  
  func canOpenUrl(_ url: URL, application: UIApplication, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
    SCSDKLoginClient.application(application, open: url, options: options)
  }
}
```

## License

PovioKitAuth is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
