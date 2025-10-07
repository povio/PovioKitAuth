# FacebookAuthenticator

Auth provider for social login with Facebook.

## Installation

Install it from a [separate repo](https://github.com/povio/PovioKitAuthFacebook).

## Usage

```swift
import PovioKitAuthFacebook

// initialization
let authenticator = FacebookAuthenticator()

// signIn user with default permissions
let result = try await authenticator
  .signIn(from: <view-controller-instance>)

// signIn user with custom permissions  
let result = try await authenticator
  .signIn(from: <view-controller-instance>, with: [<array-of-custom-permissions>])

// get authentication status
let state = authenticator.isAuthenticated

// signOut user
authenticator.signOut() // all provider data regarding the use auth is cleared at this point

// handle url
authenticator.canOpenUrl(_: application: options:) // call this from `application:openURL:options:` in UIApplicationDelegate
```
