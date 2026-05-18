## Migration Guides

### Migration from versions < 3.1.0
* [Core] `JWTDecoder.Error`: `.invalidBase64` / `.invalidJson` now take a `component` (`"header"` or `"payload"`). Added `claim`, `headerClaim`, `double`, `int`. Improved `bool` / `date` parsing.

### Migration from versions < 3.0.0
* [Facebook] In order to continue using FacebookAuthenticator, you'll need to install it as a [separate dependency](https://github.com/povio/PovioKitAuthFacebook). 
* [Google] In order to continue using GoogleAuthenticator, you'll need to install it as a [separate dependency](https://github.com/povio/PovioKitAuthGoogle/).

### Migration from versions < 2.0.0
* [Apple] Response field `name` is now optional.
* [All] Migrated all authenticators from promises to async/await. If you insist working with promises, do not update.

### Migration from versions < 1.4.0
* [Google] Response field `token` was renamed to `accessToken`. You'll need to handle it on the call site. Additionally, `idToken` field was added in the response.  
