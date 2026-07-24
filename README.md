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
| `ios/` | SwiftUI app + `GoogleChatMultiCore` package (committed `.xcodeproj`) |
| `relay/` | TypeScript ntfy relay (Cloud Run / Fly) |
| `scripts/` | Phase 0 bootstrap helpers |
| `docs/PLAN.md` | Locked product decisions |

## Locked decisions

- Free Apple sideload + **ntfy.sh** alerts (message previews)
- N Google accounts (start with personal + work); Workspace admin will allowlist OAuth
- Heavy MVP: spaces/DMs, text, reactions, attachments

## Status

Consolidated MVP base (best of parallel implementation PRs):

- [x] Relay with TDD (`npm test` — health, ntfy publish, mutes, quiet hours, teardown, renewal, Pub/Sub auth)
- [x] iOS Core package with TDD (`swift test` — account IDs, inbox merge, deep links, Chat API, media)
- [x] SwiftUI app scaffold (inbox, thread, accounts, GoogleSignIn, Keychain, SQLite cache, deep links)
- [x] Attachment upload wired through Chat media API; capped media download helper
- [ ] Phase 0 on-device: ntfy install + OAuth smoke + relay→ntfy alert on iPhone 8
- [ ] Wire real Google Cloud project / Workspace Events subscriptions
- [ ] Add GoogleSignIn SPM package reference in Xcode (coordinator is ready)

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
make test
# or:
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

## Consolidation notes

This branch merges the strongest pieces from parallel MVP PRs:

| Source | Kept |
| --- | --- |
| PR #6 | Base: Xcode project, GoogleSignIn, encrypted durable relay store, admin/user auth split |
| PR #8 | Capped media download, Pub/Sub verify token, HTTP server timeouts, broader OAuth scopes, Makefile |
| PR #7 | `InAppBanner` model for foreground fallback |
| PR #9 | End-to-end attachment upload → message create wiring |
