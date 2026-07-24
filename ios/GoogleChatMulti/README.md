# Google Chat Multi (iOS 16+)

SwiftUI multi-account Google Chat client. Open `Package.swift` in **Xcode 15+** on macOS to build for a physical iPhone 8 (iOS 16.7) or simulator.

## Modules

| Module | Responsibility |
| --- | --- |
| `GoogleChatCore` | Models, Auth store, Chat API parsing, Inbox merge/filter, GRDB cache |
| `GoogleChatMulti` | SwiftUI app shell (home, thread, account manager) |

## Requirements

- iOS 16.0 deployment target
- Xcode 15+ on macOS for signing (free Apple ID sideload)
- Google OAuth client configured for iOS bundle id
- [ntfy](https://ntfy.sh) iOS app installed for background notifications

## URL scheme

Register `gchatmulti` in Xcode → Target → Info → URL Types:

```
gchatmulti://space/{accountId}:{spaceName}
```

Used by ntfy tap actions to open a conversation.

## Tests

```bash
# On macOS with Xcode:
xcodebuild test -scheme GoogleChatMulti -destination 'platform=iOS Simulator,name=iPhone 15'
```

Or in Xcode: **Product → Test** (`Cmd+U`).

## OAuth (production wiring)

The account manager placeholder adds demo data. Wire **GoogleSignIn** + **GTMAppAuth** in an Xcode app target:

1. Add SPM dependencies: `GoogleSignIn`, `AppAuth`
2. Replace `addPlaceholderAccount()` with the real sign-in flow
3. Store `StoredAuthorization` in Keychain-backed `AuthorizationStore`
4. Register refresh tokens with the relay for Workspace Events subscriptions

## Scopes

See `OAuthScopes.minimal` in `GoogleChatCore`.
