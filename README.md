# google-chat-ios-16

Personal multi-account Google Chat client aimed at **iOS 16.7 / iPhone 8**, where the official Chat app (iOS 18+) no longer runs.

## Why

- Official Google Chat requires iOS 18+, so iPhone 8 is stuck.
- Want personal + work chats (and notifications) in **one window**, not account switching.
- Avoid a paid Apple Developer account for push.

## Plan

See **[docs/PLAN.md](docs/PLAN.md)** for the full product/technical plan.

## Repository layout

```text
ios/GoogleChatMulti/     SwiftUI app + GoogleChatCore library (SPM)
relay/                   Workspace Events → Pub/Sub → ntfy relay (TypeScript)
scripts/                 Phase 0 smoke tests (ntfy, Google Chat API, relay)
docs/PLAN.md             Product & technical plan
```

## Locked decisions

- Free Apple sideload + **ntfy.sh** alerts (message previews)
- N Google accounts (start with personal + work); Workspace admin will allowlist OAuth
- Heavy MVP: spaces/DMs, text, reactions, attachments

## Status

**MVP scaffold implemented** (TDD where runnable in CI):

| Area | Status |
| --- | --- |
| Relay health + test-notify + pubsub → ntfy | Done (20 vitest tests) |
| Phase 0 scripts | Done (`scripts/`) |
| iOS core (Auth, ChatAPI, Sync, Inbox) | Done with XCTest suite |
| SwiftUI shell (home, thread, accounts) | Done |
| Google OAuth sign-in UI | Placeholder — wire GoogleSignIn in Xcode |
| Workspace Events subscription lifecycle | Relay helpers + teardown; GCP deploy manual |
| Attachments / reactions API wiring | Models ready; UI stubs remain |

## Quick start

### Relay (Linux / macOS / Cloud Run)

```bash
cd relay
npm install
npm test
export NTFY_TOPIC=your-secret-topic
npm run dev
```

### Phase 0 validation

```bash
NTFY_TOPIC=your-topic ./scripts/test-ntfy.sh
ACCESS_TOKEN=ya29... ./scripts/test-google-chat-api.sh
RELAY_URL=http://localhost:8080 ./scripts/test-relay.sh
```

### iOS (macOS + Xcode)

Open `ios/GoogleChatMulti/Package.swift` in Xcode, set your development team, run on iPhone 8 or simulator. See [ios/GoogleChatMulti/README.md](ios/GoogleChatMulti/README.md).

## Next steps

1. Complete Phase 0 on a physical iPhone 8 (ntfy app + both Google accounts)
2. Deploy relay to Cloud Run; create Pub/Sub push subscription → `/pubsub`
3. Wire GoogleSignIn in Xcode and connect live Chat API sync
4. Implement attachments with memory-safe thumbnails on A11 devices
