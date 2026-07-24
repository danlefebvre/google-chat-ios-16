# iOS app (Google Chat Multi)

Native SwiftUI client for iOS 16+ with multi-account OAuth, unified inbox, and deep links for ntfy tap actions.

## Structure

```text
ios/
  GoogleChatMulti/          # SwiftUI app target
  Packages/GoogleChatCore/  # Shared logic + XCTest suite
```

## Requirements

- macOS with Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- iOS 16.0 deployment target (iPhone 8 compatible)

## Generate Xcode project

```bash
cd ios/GoogleChatMulti
xcodegen generate
open GoogleChatMulti.xcodeproj
```

Set `GOOGLE_OAUTH_CLIENT_ID` in the target build settings (or `Info.plist`) with your Google Cloud OAuth iOS client id.

## Run tests (TDD)

```bash
cd ios/Packages/GoogleChatCore
swift test
```

## MVP auth note

The account manager includes a token-paste bootstrap screen for Phase 0 smoke tests. Replace with GoogleSignIn + AppAuth interactive OAuth before regular use.

## Deep links

The app registers the `gchatmulti://` URL scheme. ntfy notifications from the relay include click actions like:

`gchatmulti://space/spaces%2Fabc123`
