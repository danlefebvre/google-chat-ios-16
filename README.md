# google-chat-ios-16

Personal multi-account Google Chat client aimed at **iOS 16.7 / iPhone 8**, where the official Chat app (iOS 18+) no longer runs.

## Why

- Official Google Chat requires iOS 18+, so iPhone 8 is stuck.
- Want personal + work chats (and notifications) in **one window**, not account switching.
- Avoid a paid Apple Developer account for push.

## Plan

See **[docs/PLAN.md](docs/PLAN.md)** for the full product/technical plan.

## Repo layout

```text
docs/PLAN.md          Product & architecture plan
relay/                Workspace Events → ntfy relay (TypeScript, vitest TDD)
ios/GoogleChatCore/   Shared Swift package (inbox, auth models, deep links)
ios/GoogleChatMulti/  SwiftUI app (iOS 16+)
scripts/              Phase 0 smoke tests & bootstrap helpers
```

## Quick start

### Relay (notifications)

```bash
./scripts/bootstrap-relay.sh
cd relay && npm install && npm test && npm run dev
./scripts/phase0-ntfy-test.sh
```

### iOS app (requires macOS)

```bash
cd ios && xcodegen generate && open GoogleChatMulti.xcodeproj
cd ios/GoogleChatCore && swift test
```

### Phase 0 Google API smoke test

After OAuth on a test account:

```bash
ACCESS_TOKEN=ya29... ./scripts/phase0-google-chat-smoke.sh
```

## Status

**MVP scaffold implemented** (TDD):

- Relay: health, manual ntfy publish, Pub/Sub handler, mutes, quiet hours, account teardown
- iOS core: unified inbox merge/filter/search, account ids, Chat API client, Keychain token store, SwiftUI shell
- Scripts: Phase 0 ntfy + Google Chat smoke tests

Remaining for production on device: GoogleSignIn wiring, GRDB cache, Workspace Events subscription registration, relay deploy with real credentials.

## Locked decisions

- Free Apple sideload + **ntfy.sh** alerts (message previews)
- N Google accounts (start with personal + work); Workspace admin will allowlist OAuth
- Heavy MVP: spaces/DMs, text, reactions, attachments
