# iOS app (GoogleChatMulti)

Native SwiftUI client targeting **iOS 16.0+** (iPhone 8 / 16.7).

## Layout

- `GoogleChatCore/` — Swift package with testable domain logic (inbox merge, account ids, deep links)
- `GoogleChatMulti/` — SwiftUI app shell (home, thread, accounts)
- `project.yml` — [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec

## Build (macOS + Xcode)

```bash
# Generate Xcode project (requires XcodeGen: brew install xcodegen)
cd ios
xcodegen generate

open GoogleChatMulti.xcodeproj
```

Set signing to your free Apple ID team. No push entitlement is required (ntfy handles alerts).

## Run tests (TDD)

```bash
cd ios/GoogleChatCore
swift test
```

Core logic tests cover inbox merging, account ids, sync keys, and deep links. Wire GoogleSignIn + GTMAppAuth in the app target when completing OAuth.

## URL scheme

`googlechatmulti://space/{accountId}/{spaceName}` — used by ntfy tap actions from the relay.
