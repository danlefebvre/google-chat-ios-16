# google-chat-ios-16

Personal multi-account Google Chat client aimed at **iOS 16.7 / iPhone 8**, where the official Chat app (iOS 18+) no longer runs.

## Why

- Official Google Chat requires iOS 18+, so iPhone 8 is stuck.
- Want personal + work chats (and notifications) in **one window**, not account switching.
- Avoid a paid Apple Developer account for push.

## Architecture

- **`ios/`** — SwiftUI app + `GoogleChatCore` package (multi-account inbox, Chat API client, GRDB cache, deep links)
- **`relay/`** — TypeScript relay: Workspace Events / Pub/Sub → **ntfy.sh** with message previews
- **`scripts/`** — bootstrap and Phase 0 smoke-test helpers

See **[docs/PLAN.md](docs/PLAN.md)** for the full product plan.

## Quick start

### Relay (Linux/macOS)

```bash
cd relay
npm install
npm test
NTFY_TOPIC=your-secret-topic npm run dev
```

Manual ntfy smoke test:

```bash
./scripts/test-ntfy.sh http://localhost:8080
```

### iOS (macOS + Xcode)

```bash
cd ios/GoogleChatMulti
xcodegen generate
open GoogleChatMulti.xcodeproj
```

Run core tests:

```bash
cd ios/Packages/GoogleChatCore && swift test
```

### Full bootstrap

```bash
chmod +x scripts/*.sh
./scripts/bootstrap.sh
```

## Status

Initial implementation scaffolded with TDD:

| Area | Status |
| --- | --- |
| Relay health + ntfy publish | Implemented + tested |
| Pub/Sub event parsing + mutes | Implemented + tested |
| iOS core (Auth, Chat API, inbox merge, GRDB) | Implemented + XCTest suite |
| SwiftUI home / thread / accounts UI | Scaffolded |
| GoogleSignIn interactive OAuth UI | Token-paste bootstrap only (Phase 0) |
| Workspace Events subscription provisioning | Relay hooks ready; GCP wiring manual |

## Locked decisions

- Free Apple sideload + **ntfy.sh** alerts (message previews)
- N Google accounts (start with personal + work); Workspace admin will allowlist OAuth
- Heavy MVP: spaces/DMs, text, reactions, attachments

## Phase 0 checklist (device)

1. Install ntfy iOS app on iPhone 8 / iOS 16.7.16 and confirm push delivery
2. Complete OAuth for personal + work accounts (Testing consent screen)
3. Call `spaces.list` / `messages.list` for each account
4. Run `./scripts/test-ntfy.sh` against deployed relay
5. Wire Workspace Events → Pub/Sub → relay push endpoint
