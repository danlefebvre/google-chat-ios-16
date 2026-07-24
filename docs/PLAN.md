# Plan: Multi-Account Google Chat Client for iOS 16.7 / iPhone 8

## Problem

- Official **Google Chat** on the App Store now requires **iOS 18+**, so it will not install or update on an **iPhone 8** stuck on **iOS 16.7.16**.
- Existing Google clients typically keep accounts separate (account switcher), so personal + work notifications and threads are not visible in one place.
- Goal: a personal (or small-group) iOS app that:
  1. Runs on **iOS 16.0+** (validated on iPhone 8 / 16.7.16)
  2. Shows **multiple Google accounts’ chats in the same window**
  3. Delivers **reliable notifications from both personal and work** accounts via **APNs**

This plan is for building that client. It is not a drop-in clone of every Chat/Gemini feature.

---

## Recommended product shape

**Native SwiftUI app** that talks to the **Google Chat API** with **per-account OAuth**, plus a **required small relay backend** that turns Google Chat events into **APNs** pushes.

| Approach | Fit | Why |
| --- | --- | --- |
| **A. Native Chat API client + APNs relay (recommended)** | Best | True multi-account session, unified inbox, controllable deployment target, first-class dual-account push |
| B. Multi-WKWebView of `chat.google.com` | Weak | Cookie/session isolation is brittle; background push almost impossible; Google often breaks embedded login |
| C. Safari / Home Screen web app only | Stopgap only | Works today for reading/sending, but multi-account + reliable dual-account push is poor |

Ship **A**. Use Safari only as a temporary bridge while the native MVP is built.

**Decision locked:** APNs is first-class. Local notifications are only a **fallback** (foreground / rare background poll), not the primary alert path.

---

## Constraints that drive the design

### Device / OS

- Target: `IPHONEOS_DEPLOYMENT_TARGET = 16.0`
- Device class: iPhone 8 (A11, 2 GB RAM) — keep UI simple, avoid heavy image pipelines, paginate aggressively
- Distribution: **not** the App Store initially
  - Paid Apple Developer account + **TestFlight** (preferred; also required for straightforward APNs), or
  - Xcode direct install with push-capable provisioning
- Xcode / macOS required to build and sign; this repo will hold the iOS project and the notification relay service

### Google platform

- Must create a **Google Cloud project**, enable **Google Chat API**, **Google Workspace Events API**, and **Pub/Sub** (+ People API as needed)
- OAuth consent screen in **Testing** mode is enough for personal use (add both Google accounts as test users)
- Chat message/space scopes are often **restricted/sensitive** — public App Store distribution would need Google verification; personal Testing mode avoids that
- **Workspace admin** can block third-party OAuth apps — work account access may need admin approval of the OAuth client
- Official Google Sign-In iOS SDK is awkward for concurrent multi-account; plan on **GoogleSignIn for the interactive flow + GTMAppAuth/Keychain for storing multiple authorizations** (keyed by `sub` / email)

### Notifications (APNs-first)

iOS cannot receive Google’s own Chat pushes inside a third-party app. Primary path:

1. iOS app registers for remote notifications and sends its **APNs device token** to the relay, tied to each signed-in Google account `sub`
2. Relay creates **Google Workspace Events** subscriptions per account (user-level `//chat.googleapis.com/spaces/-` where available)
3. Events land on **Pub/Sub** → relay handler
4. Relay sends an **APNs** alert (account id + space id in payload for deep link)

**Fallback only:** while the app is open (or if a background refresh happens to run), poll Chat and post a local notification if the relay is down. Do not treat local-only delivery as success.

Requires:

- Apple Developer Program (push certificate or key)
- Always-on relay (Cloud Run / Fly / similar)
- Stored refresh tokens or event-subscription credentials on the relay (encrypted at rest)

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
- Attachments: download via Chat media API; upload via attachments upload (later phase if heavy)

### Notifications

- **APNs** is the default alert path for both accounts
- Payload includes account id + space id; tap opens the correct thread under the correct account
- Per-account mute + per-space mute (store locally; sync Chat notification settings later if API allows)
- Quiet hours on device and/or relay

---

## Feature scope by phase

### Phase 0 — Feasibility gate (do this first)

1. Confirm both accounts can complete OAuth against a Testing consent screen.
2. Call `spaces.list` and `spaces.messages.list` for each token.
3. If work account fails: check Workspace admin “API controls” / OAuth app access.
4. Prove one end-to-end APNs path: Workspace Event (or manual test publish) → relay → device alert.

**Exit criteria:** both accounts return spaces/messages, and a test APNs notification reaches the iPhone 8.

### Phase 1 — MVP (chat + first-class APNs)

**Client**

- Multi-account sign-in / sign-out / token refresh
- Unified conversation list (merged, sorted by last activity)
- Open space / DM, paginated message history
- Send text messages; basic reactions
- Mark space read (`users.spaces.spaceReadState`)
- APNs registration + deep links
- Offline cache of recent threads (**GRDB/SQLite**)
- Account-colored badges throughout
- Local notification fallback only when app is already active / relay unreachable

**Relay (ships with MVP)**

- Register/unregister device tokens per Google account
- Maintain Workspace Events subscriptions + Pub/Sub consumer
- Send APNs alerts: title = space, body = truncated text (or privacy-safe “New message”), thread-id grouping per space
- Refresh subscription TTLs; retry failed deliveries
- Per-account notification toggles honored before send

Out of MVP: Meet huddles, Gemini summaries, smart chips, Drive previews, custom sections parity, apps/bots marketplace, full search parity.

### Phase 2 — Deeper Chat parity (as needed)

- Threads / replies UI
- File attach & image preview
- Unread sectioning closer to chat.google.com home
- People lookup / find DM
- Read receipts / typing if exposed and worth the complexity
- Share extension (“send to Chat”)
- Richer notification previews / mute sync with Chat settings

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
│  Local DB + UNUserNotificationCenter         │
│  (APNs registration + deep links)            │
└───────┬──────────────────────────▲───────────┘
        │ HTTPS (Chat API / OAuth) │ APNs
        ▼                          │
 Google Chat API / OAuth           │
        │                          │
        ▼                          │
 Relay (Cloud Run / Fly / similar)─┘
  ← Pub/Sub (Workspace Events)
  stores device tokens + account bindings
```

### Suggested modules

| Module | Responsibility |
| --- | --- |
| `Auth` | OAuth start, multi-account Keychain, refresh, logout |
| `ChatAPI` | Thin REST wrappers: spaces, messages, members, read state, media |
| `Sync` | Per-account fetchers, pagination, conflict-free upserts |
| `Inbox` | Merge/sort/filter across accounts |
| `Notifications` | APNs registration, relay enrollment, deep links; local fallback |
| `UI` | Home list, thread, account manager, composer |
| `relay` | Events → Pub/Sub → APNs; token & subscription lifecycle |

### Stack choices

- **Language/UI:** Swift 5.9+, SwiftUI (iOS 16 APIs only — no iOS 17+ Observation/`@Observable` required features without backports)
- **Networking:** URLSession + async/await
- **Auth:** AppAuth / GTMAppAuth + GoogleSignIn for UI
- **Persistence:** SQLite (GRDB) for predictable memory on 2 GB devices
- **Min OS:** iOS 16.0
- **Relay (MVP):** TypeScript or Go on Cloud Run; APNs auth key (`.p8`); secrets in Secret Manager; one Pub/Sub topic per environment

### OAuth scopes (start minimal)

Request only what MVP needs, for example:

- `openid` `email` `profile`
- `https://www.googleapis.com/auth/chat.spaces.readonly`
- `https://www.googleapis.com/auth/chat.messages` (or readonly + `chat.messages.create` if split works for your flows)
- Workspace Events scopes required for user/space subscriptions used by the relay

Re-consent when scopes expand.

---

## Security & privacy (personal app)

- Tokens only in **Keychain** on device (not UserDefaults)
- Relay stores the minimum needed for push (device token, account `sub`, event subscription ids); encrypt refresh tokens at rest
- Prefer privacy-safe APNs bodies (“New message in {space}”) unless explicit opt-in for message preview
- Certificate pinning optional; at least ATS defaults
- App Check / App Attest: usable on iPhone 8 (A11 Secure Enclave), but **do not enforce** until sideload/TestFlight flows are proven — enforcement can lock you out during development
- Clear data wipe on account remove (device + relay bindings)

---

## Distribution plan for iPhone 8

1. Enroll in **Apple Developer Program** (needed for practical APNs + TestFlight).
2. Create an APNs auth key; configure the app’s push capability.
3. Set deployment target 16.0; run on the physical iPhone 8 early and often.
4. Internal TestFlight builds for ongoing updates without cables.
5. Do **not** pursue public App Store + Google OAuth verification unless the audience grows beyond personal/family use.

---

## Risks & mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Work Workspace blocks OAuth client | Can’t see work chats / can’t subscribe to events | Ask admin to allow the app; or use a Workspace “internal” OAuth app under the company project |
| Restricted scopes / unverified app warning | Scary consent screen | Keep OAuth in Testing; add accounts as test users |
| Relay or Pub/Sub outage | Missed pushes | Local fallback while app open; health checks; retry queue |
| Workspace Events subscription expiry | Silent push death | TTL refresh job; alert if subscription create/renew fails |
| Chat API ≠ full product UI (no Gemini, partial web parity) | Feature gaps | Scope MVP to messaging; deep-link to Safari for rare actions |
| iPhone 8 memory pressure | Crashes scrolling media-heavy spaces | Aggressive pagination, purge image cache, avoid loading full histories |
| Google API / Events policy changes | Breaks sync/push | Isolate API layer; keep poll fallback for inbox sync |

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
    GoogleChatMulti/           ← Xcode project (SwiftUI + APNs)
  relay/                       ← MVP: Workspace Events + Pub/Sub + APNs
  scripts/                     ← bootstrap Google Cloud / APNs / secrets helpers
```

---

## Decision checklist

1. **Push requirement:** **APNs first-class** (decided). Local notifications are fallback only.
2. **Work account admin access:** Can you allowlist a custom OAuth client?
3. **Apple Developer account:** Paid (TestFlight + APNs) assumed — confirm.
4. **Accounts in v1:** Exactly two (personal + work), or N accounts?
5. **Feature floor:** Text + DMs only, or spaces + reactions + attachments from day one?
6. **Notification privacy:** Preview message text in APNs, or generic “New message in {space}”?

Default assumptions if unstated: **N accounts (start with 2)**, **APNs relay in MVP**, **paid TestFlight**, **text + reactions + unified inbox first**, **privacy-safe notification bodies by default**.

---

## Implementation order (once remaining decisions are set)

1. Scaffold iOS 16 SwiftUI app + Google Cloud OAuth iOS client + APNs capability
2. Scaffold relay (health check, APNs send-test endpoint)
3. Multi-account Keychain auth; enroll device token with relay per account
4. Workspace Events → Pub/Sub → APNs path for both accounts
5. `spaces.list` → local DB → unified home UI
6. Thread view + send message
7. Deep links from APNs into the correct account/thread
8. Harden for iPhone 8 (memory, pagination, offline) + relay TTL/retry
9. Optional later: attachments, search, richer parity

---

## Success criteria

- Both personal and work accounts signed in simultaneously
- One home list shows conversations from both, clearly labeled
- Opening a thread sends as the correct account
- New messages from **either** account alert via **APNs** while the app is backgrounded/killed
- Tap on a notification opens the right account + space
- App installs and remains usable on **iPhone 8 / iOS 16.7.16**
