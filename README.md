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
  ios/          # SwiftUI app + GoogleChatCore (SPM, unit-tested)
  relay/        # Go: Workspace Events / Pub/Sub → ntfy.sh
  scripts/      # local smoke helpers
```

## Locked decisions

- Free Apple sideload + **ntfy.sh** alerts (message previews)
- N Google accounts (start with personal + work); Workspace admin will allowlist OAuth
- Heavy MVP: spaces/DMs, text, reactions, attachments
- Account-removal teardown: relay (subscription → token → binding) before device Keychain wipe

## Develop

```bash
# All automated tests (relay + GoogleChatCore)
./scripts/test-all.sh

# Relay only
cd relay && go test ./...
NTFY_TOPIC=your-secret-topic ./scripts/run-relay.sh
./scripts/phase0-smoke.sh

# iOS domain tests
cd ios && swift test
# On macOS: brew install xcodegen && cd ios && xcodegen generate && open GoogleChatMulti.xcodeproj
```

## Status

Implementation started (TDD):

- Relay: health, manual publish, Pub/Sub push → ntfy preview, mutes/quiet hours, subscription TTL refresh, account teardown
- iOS core: multi-account IDs, inbox merge/filter/search, Chat API client/models, sync upsert, attachments budget, deep links, SwiftUI shell
