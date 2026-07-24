# iOS client (iOS 16+)

Native SwiftUI multi-account Google Chat client. Domain logic lives in the `GoogleChatCore` Swift package (testable on Linux/macOS). UI sources are under `App/`.

## Layout

```text
ios/
  Package.swift           # GoogleChatCore library + unit tests
  Sources/GoogleChatCore/ # Auth, ChatAPI, Inbox, Sync, DeepLink
  Tests/GoogleChatCoreTests/
  App/                    # SwiftUI shell (home, thread, accounts)
  project.yml             # XcodeGen spec (macOS)
```

## Tests (Linux or macOS)

```bash
cd ios
swift test
```

## Open in Xcode (macOS)

```bash
brew install xcodegen   # once
cd ios && xcodegen generate
open GoogleChatMulti.xcodeproj
```

Set your Google OAuth client IDs in the Sign-In flow (GoogleSignIn + GTMAppAuth) before device testing. Deployment target is **iOS 16.0** for iPhone 8.

## Deep links

Custom scheme `googlechatmulti://space?account={issuer|sub}&space=spaces/{id}` for ntfy tap actions.

## Account removal

Call the relay `DELETE /v1/accounts/{accountID}` **before** wiping Keychain entries on device (see plan teardown order).
