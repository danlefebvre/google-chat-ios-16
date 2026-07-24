# GoogleChat Multi (iOS 16)

Native SwiftUI client for multi-account Google Chat on **iPhone 8 / iOS 16.0+**.

Notifications are **not** delivered via APNs. Install the separate **ntfy** app and run the `relay/`.

## Layout

- `GoogleChatMulti.xcodeproj` — app target (no push entitlement)
- `GoogleChatMulti/` — SwiftUI UI, Keychain auth, SQLite cache, relay client
- `GoogleChatMultiCore/` — pure Swift package (models, inbox merge, Chat API, deep links) with unit tests

## Configure

1. Open `GoogleChatMulti.xcodeproj` in Xcode on macOS.
2. Set your Development Team for free sideload signing.
3. Edit `GoogleChatMulti/Info.plist`:
   - `GIDClientID` — Google iOS OAuth client
   - URL scheme `com.googleusercontent.apps.…` for Google Sign-In
   - `RELAY_BASE_URL` / `RELAY_ADMIN_TOKEN`
4. Add the **GoogleSignIn** SPM package (`https://github.com/google/GoogleSignIn-iOS`) to the app target when building on a Mac.

## Tests

Core package (Linux or macOS):

```bash
cd GoogleChatMultiCore
swift test
```

## MVP surface

- N-account sign-in (issuer/sub Keychain keys)
- Unified inbox merge/filter/search
- Thread view with send + reactions
- Attachment picker with iPhone 8 memory limiter
- Deep link scheme `googlechatmulti://space/...`
- Foreground banner fallback when refresh fails
