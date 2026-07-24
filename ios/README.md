# GoogleChatMulti (iOS 16)

Native SwiftUI multi-account Google Chat client for **iOS 16.0+** / iPhone 8.

## Layout

| Path | Role |
| --- | --- |
| `Sources/GoogleChatCore` | Auth, Chat API, inbox merge, sync, deep links, offline cache |
| `Tests/GoogleChatCoreTests` | Unit tests (run on Linux/macOS via `swift test`) |
| `App/` | SwiftUI shell: home, thread, accounts, in-app banner fallback |
| `project.yml` | XcodeGen spec (no APNs entitlement) |

## Test (TDD core)

```bash
cd ios
swift test
```

## Build on macOS

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
2. Create a Google Cloud OAuth iOS client; put the client ID into `project.yml`
3. Generate and open:

```bash
cd ios
xcodegen generate
open GoogleChatMulti.xcodeproj
```

4. Add **GoogleSignIn** SPM dependency in Xcode and complete `GoogleSignInCoordinator.signIn`
5. Sideload with a free Apple ID (profiles expire ~7 days)

## OAuth scopes (minimal)

- `openid` `email` `profile`
- `https://www.googleapis.com/auth/chat.spaces.readonly`
- `https://www.googleapis.com/auth/chat.messages`
- `https://www.googleapis.com/auth/chat.users.readstate`

## Notifications

System pushes come from the **ntfy** app + `relay/`. This target has **no** APS entitlement.
Deep links use `googlechatmulti://spaces/{accountId}/{spaceName}`.
