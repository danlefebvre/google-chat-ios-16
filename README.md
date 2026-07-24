# google-chat-ios-16

Personal multi-account Google Chat client aimed at **iOS 16.7 / iPhone 8**, where the official Chat app (iOS 18+) no longer runs.

## Why

- Official Google Chat requires iOS 18+, so iPhone 8 is stuck.
- Want personal + work chats (and notifications) in **one window**, not account switching.
- Avoid a paid Apple Developer account for push.

## Architecture

```text
iPhone 8
├─ GoogleChat Multi (sideload, SwiftUI)  → Google Chat API (multi-account OAuth)
└─ ntfy iOS app                          ← ntfy.sh pushes
                                          ↑
                               relay/ (Workspace Events → Pub/Sub → ntfy)
```

See **[docs/PLAN.md](docs/PLAN.md)** for the full product/technical plan.

## Repo layout

| Path | Role |
| --- | --- |
| `ios/` | SwiftUI app + `GoogleChatMultiCore` package |
| `relay/` | TypeScript ntfy relay (Cloud Run / Fly) |
| `scripts/` | Phase 0 bootstrap helpers |
| `docs/PLAN.md` | Locked product decisions |

## Locked decisions

- Free Apple sideload + **ntfy.sh** alerts (message previews)
- N Google accounts (start with personal + work); Workspace admin will allowlist OAuth
- Heavy MVP: spaces/DMs, text, reactions, attachments

## Status

MVP implementation in progress:

- [x] Relay with TDD (`npm test` — health, ntfy publish, mutes, quiet hours, teardown, renewal)
- [x] iOS Core package with TDD (`swift test` — account IDs, inbox merge, deep links, Chat API)
- [x] SwiftUI app scaffold (inbox, thread, accounts, Keychain, SQLite cache, deep links)
- [ ] Phase 0 on-device: ntfy install + OAuth smoke + relay→ntfy alert on iPhone 8
- [ ] Wire real Google Cloud project / Workspace Events subscriptions

## Develop

### Relay

```bash
cd relay
cp .env.example .env   # fill secrets
npm install
npm test
npm run dev
```

### iOS Core tests

```bash
cd ios/GoogleChatMultiCore
swift test
```

### Full automated suite

```bash
./scripts/run-tests.sh
```

If Swift is unavailable (e.g. Linux CI without a toolchain), set `SKIP_SWIFT_TESTS=1` to opt in to skipping Core tests. Without that flag the script fails instead of reporting a full-suite pass.

### Phase 0 helpers

```bash
./scripts/bootstrap-ntfy.sh
./scripts/bootstrap-google-cloud.sh YOUR_GCP_PROJECT
./scripts/relay-test-ntfy.sh
```

Open `ios/GoogleChatMulti.xcodeproj` on a Mac to sideload to the iPhone 8.
