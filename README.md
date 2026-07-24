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
docs/PLAN.md
ios/                 # SwiftUI app + GoogleChatCore (SwiftPM)
relay/               # Go: Workspace Events / Pub/Sub → ntfy.sh
scripts/             # GCP bootstrap + ntfy smoke tests
```

## Status

MVP implementation in progress:

- **Relay:** health, manual ntfy publish, Pub/Sub push → preview alerts, mutes, quiet hours, account teardown, subscription TTL refresh
- **iOS core:** multi-account auth keys `{issuer,sub}`, Chat API client, sync, unified inbox merge, SQLite cache, deep links, attachment memory policy, relay registration/removal
- **iOS UI:** home list, thread (send/react/attach picker), account manager, in-app banner fallback, `googlechatmulti://` URL scheme

## Quick start

### Relay

```bash
cd relay
export NTFY_TOPIC=your-secret-topic
export NTFY_ACCESS_TOKEN=optional
go test ./...
go run ./cmd/relay
```

### iOS core tests

```bash
cd ios
swift test
```

### iOS app (macOS)

```bash
cd ios && xcodegen generate && open GoogleChatMulti.xcodeproj
```

### Phase 0 smoke

```bash
./scripts/test-ntfy.sh direct   # needs NTFY_TOPIC
./scripts/test-ntfy.sh relay    # needs relay running
./scripts/bootstrap-gcp.sh      # needs gcloud + GOOGLE_CLOUD_PROJECT
```

## Locked decisions

- Free Apple sideload + **ntfy.sh** alerts (message previews)
- N Google accounts (start with personal + work); Workspace admin will allowlist OAuth
- Heavy MVP: spaces/DMs, text, reactions, attachments
- Account removal: relay teardown before device Keychain wipe
