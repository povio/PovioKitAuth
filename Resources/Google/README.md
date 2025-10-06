# GoogleAuthenticator

Auth provider for social login with Google.

## Installation

Install it from a [separate repo](https://github.com/povio/PovioKitAuthGoogle).

## Usage

```swift
import PovioKitAuthGoogle

// initialization
let authenticator = GoogleAuthenticator()

// signIn user
let result = try await authenticator
  .signIn(from: <view-controller-instance>)

// get authentication status
let state = authenticator.isAuthenticated

// signOut user
authenticator.signOut() // all provider data regarding the use auth is cleared at this point

// handle url
authenticator.canOpenUrl(_: application: options:) // call this from `application:openURL:options:` in UIApplicationDelegate
```
