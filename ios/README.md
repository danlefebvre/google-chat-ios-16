# iOS client (`GoogleChatMulti`)

Native SwiftUI multi-account Google Chat client targeting **iOS 16.0+** (iPhone 8).

## Layout

| Path | Role |
| --- | --- |
| `Sources/GoogleChatCore` | Testable core: Auth, ChatAPI, Sync, Inbox, SQLite cache, Relay client, deep links |
| `Tests/GoogleChatCoreTests` | Unit tests (run on macOS/Linux via SwiftPM) |
| `GoogleChatMulti/` | SwiftUI app shell (home, thread, accounts, in-app banner fallback) |
| `project.yml` | XcodeGen spec for the iOS app target |

## Tests (TDD core)

```bash
cd ios
swift test
```

## Build the app (macOS + Xcode)

```bash
brew install xcodegen   # once
cd ios
xcodegen generate
open GoogleChatMulti.xcodeproj
```

- Set your free Apple team in Signing
- Copy `Config.xcconfig.example` → `Config.xcconfig` and set OAuth client + relay URL
- Sideload to iPhone 8; install **ntfy** separately and subscribe to the relay topic
- No APNs entitlement (ntfy-first)

## Deep links

`googlechatmulti://open?accountId={issuer|sub}&space=spaces/{id}` — used as ntfy click actions.
