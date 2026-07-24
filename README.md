# google-chat-ios-16

Personal multi-account Google Chat client aimed at **iOS 16.7 / iPhone 8**, where the official Chat app (iOS 18+) no longer runs.

## Why

- Official Google Chat requires iOS 18+, so iPhone 8 is stuck.
- Want personal + work chats (and notifications) in **one window**, not account switching.
- Avoid a paid Apple Developer account for push.

## Plan

See **[docs/PLAN.md](docs/PLAN.md)** for the full product/technical plan:

- Native SwiftUI + Google Chat API (not a web wrapper)
- Multi-account OAuth with a merged inbox
- **ntfy-first** dual-account alerts via a small relay (no APNs in our app; free Apple sideload)
- Local in-app banners only as fallback when the Chat app is already open

## Status

Planning only — implementation not started.
