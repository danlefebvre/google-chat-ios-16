# iOS app

Native SwiftUI client for iOS 16+ (validated target: iPhone 8 / iOS 16.7.16).

## Layout

```text
ios/
  Package.swift              # GoogleChatCore library + unit tests
  Sources/GoogleChatCore/    # Auth, ChatAPI, Sync, Inbox, Persistence
  Tests/GoogleChatCoreTests/
  GoogleChatMulti/           # SwiftUI app sources
```

## Open in Xcode

1. Open `ios/Package.swift` in Xcode 15+.
2. File → New → Project → iOS App, name `GoogleChatMulti`, save inside `ios/`.
3. Add local package dependency on `GoogleChatCore`.
4. Replace the generated app files with `GoogleChatMulti/App`, `Views`, and `ViewModels`.
5. Set deployment target to **iOS 16.0**, bundle id of your choice, and add URL scheme `gchatmulti` (see `GoogleChatMulti/Info.plist`).
6. Add Google Sign-In + AppAuth dependencies when wiring real OAuth (demo account buttons are placeholders).

## Run tests (macOS)

```bash
cd ios
swift test
```

## OAuth scopes

See `Sources/GoogleChatCore/Auth/AccountStore.swift` (`OAuthScopes.required`).

## Deep links

ntfy tap actions use `gchatmulti://space/<encoded-space-resource-name>` to open a thread.
