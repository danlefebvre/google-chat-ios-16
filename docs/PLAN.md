# Plan: Multi-Account Google Chat Client for iOS 16.7 / iPhone 8

## Problem

- Official **Google Chat** on the App Store now requires **iOS 18+**, so it will not install or update on an **iPhone 8** stuck on **iOS 16.7.16**.
- Existing Google clients typically keep accounts separate (account switcher), so personal + work notifications and threads are not visible in one place.
- Goal: a personal (or small-group) iOS app that:
  1. Runs on **iOS 16.0+** (validated on iPhone 8 / 16.7.16)
  2. Shows **multiple Google accounts’ chats in one window**
  3. Delivers **notifications from both personal and work** accounts

This plan is for building that client. It is not a drop-in clone of every Chat/Gemini feature.

---

## Recommended product shape

**Native SwiftUI app** that talks to the **Google Chat API** with **per-account OAuth**, plus a **small optional backend** for real push notifications.

| Approach | Fit | Why |
| --- | --- | --- |
| **A. Native Chat API client (recommended)** | Best | True multi-account session, unified inbox, controllable deployment target, local/push notifications you own |
| B. Multi-WKWebView of `chat.google.com` | Weak | Cookie/session isolation is brittle; background push almost impossible; Google often breaks embedded login |
| C. Safari / Home Screen web app only | Stopgap only | Works today for reading/sending, but multi-account + reliable dual-account push is poor |

Ship **A**. Use Safari only as a temporary bridge while the native MVP is built.

---

## Constraints that drive the design

### Device / OS

- Target: `IPHONEOS_DEPLOYMENT_TARGET = 16.0`
- Device class: iPhone 8 (A11, 2 GB RAM) — keep UI simple, avoid heavy image pipelines, paginate aggressively
- Distribution: **not** the App Store initially
  - Paid Apple Developer account + **TestFlight** (preferred), or
  - Xcode direct install / AltStore sideload
- Xcode / macOS required to build and sign; this repo will hold the iOS project and any notification relay service

### Google platform

- Must create a **Google Cloud project**, enable **Google Chat API** (+ People API as needed)
- OAuth consent screen in **Testing** mode is enough for personal use (add both Google accounts as test users)
- Chat message/space scopes are often **restricted/sensitive** — public App Store distribution would need Google verification; personal Testing mode avoids that
- **Workspace admin** can block third-party OAuth apps — work account access may need admin approval of the OAuth client
- Official Google Sign-In iOS SDK is awkward for concurrent multi-account; plan on **GoogleSignIn for the interactive flow + GTMAppAuth/Keychain for storing multiple authorizations** (keyed by `sub` / email)

### Notifications reality check

iOS cannot receive Google’s own Chat pushes inside a third-party app. Options:

1. **MVP (no server):** background `BGAppRefreshTask` + periodic Chat API poll while allowed; local notifications when new messages appear. Unreliable when the OS throttles refresh.
2. **Reliable push (recommended next step):** tiny backend that:
   - Creates **Google Workspace Events** subscriptions per user (`//chat.googleapis.com/spaces/-` style user-level targets where available)
   - Receives events via **Pub/Sub**
   - Maps them to **APNs** device tokens registered by the iOS app  
   Without this relay, “notifications from both accounts” will be best-effort only.

---

## Core user experience

### Unified home (one window)

Single home list that merges conversations from all signed-in accounts:

```
[Work]  #eng-standup     Alice: deploy looks good     2m
[Home]  Family            Mom: dinner at 7?           11m
[Work]  DM · Sam          You: sent the doc           1h
```

Each row carries:

- Account badge (color + short label: Work / Personal)
- Space/DM title, last message preview, unread state, timestamp
- Stable composite id: `{accountId}:{spaceName}`

Controls:

- Filter chips: All / Work / Personal (or per-account)
- Search across currently loaded accounts
- Account manager: add / remove / re-auth

### Thread view

- Standard chat bubble list for one space
- Account context sticky in the nav bar (so you never send as the wrong identity)
- Send/edit/delete/react using that account’s token only
- Attachments: download via Chat media API; upload via attachments upload (phase 2 if heavy)

### Notifications

- Notification payload includes account id + space id
- Tap opens the correct thread under the correct account
- Per-account mute + per-space mute (store locally; sync Chat notification settings later if API allows)

---

## Feature scope by phase

### Phase 0 — Feasibility gate (do this first)

1. Confirm both accounts can complete OAuth against a Testing consent screen.
2. Call `spaces.list` and `spaces.messages.list` for each token.
3. If work account fails: check Workspace admin “API controls” / OAuth app access.
4. Decide push path: local-only MVP vs. commit to a relay service.

**Exit criteria:** both accounts return spaces/messages on a physical iPhone 8 or iOS 16 simulator.

### Phase 1 — MVP client (must-have Chat parity)

- Multi-account sign-in / sign-out / token refresh
- Unified conversation list (merged, sorted by last activity)
- Open space / DM, paginated message history
- Send text messages; basic reactions
- Mark space read (`users.spaces.spaceReadState`)
- Local notifications via background refresh + foreground socket-less polling
- Offline cache of recent threads (SQLite or SwiftData with iOS 16-compatible store — prefer **GRDB/SQLite** for broader control on iOS 16)
- Account-colored badges throughout

Out of MVP: Meet huddles, Gemini summaries, smart chips, Drive previews, custom sections parity, apps/bots marketplace, full search parity.

### Phase 2 — Reliable dual-account push

- iOS registers APNs token with backend, associated to each Google account `sub`
- Backend maintains Workspace Events subscriptions + Pub/Sub push/pull
- Relay creates APNs alerts: title = space, body = truncated text, thread-id grouping per space
- Re-subscribe / refresh subscription TTLs
- Quiet hours / per-account notification toggles

### Phase 3 — Deeper Chat parity (as needed)

- Threads / replies UI
- File attach & image preview
- Unread sectioning closer to chat.google.com home
- People lookup / find DM
- Read receipts / typing if exposed and worth the complexity
- Share extension (“send to Chat”)

---

## Technical architecture

```
┌──────────────────────────────────────────────┐
│ iPhone 8 / iOS 16.7                          │
│  SwiftUI App                                 │
│  ┌────────────┐  ┌─────────────────────────┐ │
│  │ AccountStore│  │ InboxMerger            │ │
│  │ (Keychain)  │→ │ (per-account fetchers) │ │
│  └────────────┘  └───────────┬─────────────┘ │
│       │ ChatAPIClient × N    │               │
│       ▼                      ▼               │
│  Local DB + NotificationCenter               │
└───────────────┬──────────────────────────────┘
                │ HTTPS
                ▼
        Google Chat API / OAuth
                │
                ▼ (Phase 2)
        Relay (Cloud Run / Fly / similar)
         ← Pub/Sub (Workspace Events)
         → APNs
```

### Suggested modules

| Module | Responsibility |
| --- | --- |
| `Auth` | OAuth start, multi-account Keychain, refresh, logout |
| `ChatAPI` | Thin REST wrappers: spaces, messages, members, read state, media |
| `Sync` | Per-account pollers, pagination, conflict-free upserts |
| `Inbox` | Merge/sort/filter across accounts |
| `Notifications` | Local scheduling; APNs registration; deep links |
| `UI` | Home list, thread, account manager, composer |

### Stack choices

- **Language/UI:** Swift 5.9+, SwiftUI (iOS 16 APIs only — no iOS 17+ Observation/`@Observable` required features without backports)
- **Networking:** URLSession + async/await
- **Auth:** AppAuth / GTMAppAuth + GoogleSignIn for UI
- **Persistence:** SQLite (GRDB) for predictable memory on 2 GB devices
- **Min OS:** iOS 16.0
- **Backend (Phase 2):** TypeScript or Go on Cloud Run; secrets in Secret Manager; one Pub/Sub topic per environment

### OAuth scopes (start minimal)

Request only what MVP needs, for example:

- `openid` `email` `profile`
- `https://www.googleapis.com/auth/chat.spaces.readonly`
- `https://www.googleapis.com/auth/chat.messages` (or readonly + `chat.messages.create` if split works for your flows)
- Later: memberships, media, notification settings as features land

Re-consent when scopes expand.

---

## Security & privacy (personal app)

- Tokens only in **Keychain** (not UserDefaults)
- No message bodies on the relay beyond what APNs needs (prefer “New message in {space}” if you want minimal server retention)
- Certificate pinning optional; at least ATS defaults
- App Check / App Attest: usable on iPhone 8 (A11 Secure Enclave), but **do not enforce** until sideload/TestFlight flows are proven — enforcement can lock you out during development
- Clear data wipe on account remove

---

## Distribution plan for iPhone 8

1. Enroll in Apple Developer Program (or use short-lived free provisioning knowing it expires ~7 days).
2. Set deployment target 16.0; run on the physical iPhone 8 early and often.
3. Internal TestFlight build for ongoing updates without cables.
4. Do **not** pursue public App Store + Google OAuth verification unless the audience grows beyond personal/family use.

---

## Risks & mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Work Workspace blocks OAuth client | Can’t see work chats | Ask admin to allow the app; or use a Workspace “internal” OAuth app under the company project |
| Restricted scopes / unverified app warning | Scary consent screen | Keep OAuth in Testing; add accounts as test users |
| Background refresh too weak for notifications | Missed pings | Phase 2 APNs relay |
| Chat API ≠ full product UI (no Gemini, partial web parity) | Feature gaps | Scope MVP to messaging; deep-link to Safari for rare actions |
| iPhone 8 memory pressure | Crashes scrolling media-heavy spaces | Aggressive pagination, purge image cache, avoid loading full histories |
| Google API / Events policy changes | Breaks sync/push | Isolate API layer; keep poll fallback |

---

## Stopgaps while building

1. **Safari** → `https://chat.google.com/app/home` (and a second Safari profile / tab group for the other account).
2. If Gmail on that device still exposes Chat, use it only as a temporary notifier — do not depend on it long term.
3. Desktop Chat / browser for anything the phone MVP cannot do yet.

---

## Suggested repo layout (when implementation starts)

```
/
  README.md
  docs/PLAN.md                 ← this document
  ios/
    GoogleChatMulti/           ← Xcode project (SwiftUI)
  relay/                       ← Phase 2 APNs + Pub/Sub service
  scripts/                     ← bootstrap Google Cloud / secrets helpers
```

---

## Decision checklist (answer before coding)

1. **Push requirement:** Accept imperfect local notifications for MVP, or build the relay in Phase 1?
2. **Work account admin access:** Can you allowlist a custom OAuth client?
3. **Apple Developer account:** Paid (TestFlight) or free sideload?
4. **Accounts in v1:** Exactly two (personal + work), or N accounts?
5. **Feature floor:** Text + DMs only, or spaces + reactions + attachments from day one?

Default assumptions if unstated: **N accounts (start with 2)**, **MVP without relay**, **paid TestFlight**, **text + reactions + unified inbox first**.

---

## Implementation order (once decisions are set)

1. Scaffold iOS 16 SwiftUI app + Google Cloud OAuth iOS client
2. Multi-account Keychain auth
3. `spaces.list` → local DB → unified home UI
4. Thread view + send message
5. Background poll + local notifications + deep links
6. Harden for iPhone 8 (memory, pagination, offline)
7. Optional: relay service + APNs
8. Optional: attachments, search, richer parity

---

## Success criteria

- Both personal and work accounts signed in simultaneously
- One home list shows conversations from both, clearly labeled
- Opening a thread sends as the correct account
- New messages can alert from both accounts (local at minimum; APNs when relay ships)
- App installs and remains usable on **iPhone 8 / iOS 16.7.16**
