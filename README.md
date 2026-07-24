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
/
  docs/PLAN.md
  ios/          ← SwiftUI app + GoogleChatCore (SPM, TDD)
  relay/        ← Go: Workspace Events / Pub/Sub → ntfy.sh
  scripts/      ← local ntfy/relay helpers + GCP bootstrap notes
```

## Locked decisions

- Free Apple sideload + **ntfy.sh** alerts (message previews)
- N Google accounts (start with personal + work); Workspace admin will allowlist OAuth
- Heavy MVP: spaces/DMs, text, reactions, attachments
- Local in-app banners only as fallback when the Chat app is already open

## Quick start

### Relay

```bash
export NTFY_TOPIC=your-secret-topic
export TOKEN_ENCRYPTION_KEY="$(./scripts/gen-encryption-key.sh)"
cd relay && go test ./... && go run ./cmd/relay
# elsewhere:
RELAY_URL=http://localhost:8080 ./scripts/test-ntfy.sh
```

### iOS core tests

```bash
cd ios && swift test
```

### iOS app (macOS / Xcode)

See **[ios/README.md](ios/README.md)**. Generate with XcodeGen, set OAuth client IDs, sideload to iPhone 8. Install the **ntfy** App Store app and subscribe to the same topic.

## Status

MVP implementation in progress:

- [x] Relay health, ntfy preview publish, Pub/Sub consumer, mutes/quiet hours, encrypted accounts, teardown
- [x] iOS core: multi-account identity, Chat API client, inbox merge, sync upserts, deep links, offline cache, attachment limits
- [x] SwiftUI shell: unified home, thread + composer/reactions, accounts, in-app banner fallback
- [ ] Device Phase 0: OAuth smoke + ntfy on iPhone 8 (requires your Google Cloud project + phone)
- [ ] Wire GoogleSignIn SDK + live Workspace Events subscriptions in deploy
