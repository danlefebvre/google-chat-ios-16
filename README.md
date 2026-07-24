# google-chat-ios-16

Personal multi-account Google Chat client aimed at **iOS 16.7 / iPhone 8**, where the official Chat app (iOS 18+) no longer runs.

## Why

- Official Google Chat requires iOS 18+, so iPhone 8 is stuck.
- Want personal + work chats (and notifications) in **one window**, not account switching.

## Plan

See **[docs/PLAN.md](docs/PLAN.md)** for the full product/technical plan:

- Native SwiftUI + Google Chat API (not a web wrapper)
- Multi-account OAuth with a merged inbox
- **APNs-first** dual-account push via a small relay (local notifications are fallback only)
- TestFlight distribution (not App Store–first)

## Status

Planning only — implementation not started.
