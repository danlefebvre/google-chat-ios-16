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
docs/PLAN.md          Product & technical plan
ios/                  SwiftUI app + GoogleChatCore (SPM)
relay/                Workspace Events → ntfy relay (TypeScript)
scripts/              Phase 0 smoke tests & bootstrap helpers
```

## Status

**MVP scaffold implemented** (TDD for relay; XCTest targets for iOS core):

- Relay: health check, ntfy publisher with previews, Pub/Sub handler, mutes, account teardown
- iOS core: multi-account models, inbox merge/filter, Chat API client, GRDB cache, deep links
- iOS UI: unified home, thread view, account manager (demo sign-in placeholders for real OAuth)
- Scripts: ntfy smoke test, relay bootstrap, Phase 0 checklist

## Locked decisions

- Free Apple sideload + **ntfy.sh** alerts (message previews)
- N Google accounts (start with personal + work); Workspace admin will allowlist OAuth
- Heavy MVP: spaces/DMs, text, reactions, attachments

## Getting started

### 1. Phase 0 (device + Google Cloud)

```bash
./scripts/phase0-checklist.sh
NTFY_TOPIC=your-topic ./scripts/phase0-ntfy-smoke.sh
```

### 2. Relay

```bash
./scripts/bootstrap-relay.sh
cd relay && set -a && source .env && set +a && npm start
```

### 3. iOS app

See **[ios/README.md](ios/README.md)** — open in Xcode on macOS, iOS 16 deployment target, wire Google Sign-In when ready.

## Tests

```bash
cd relay && npm test
cd ios && swift test   # macOS + Xcode required
```
