# Plan: Multi-Account Google Chat Client for iOS 16.7 / iPhone 8

## Problem

- Official **Google Chat** on the App Store now requires **iOS 18+**, so it will not install or update on an **iPhone 8** stuck on **iOS 16.7.16**.
- Existing Google clients typically keep accounts separate (account switcher), so personal + work notifications and threads are not visible in one place.
- Goal: a personal (or small-group) iOS app that:
  1. Runs on **iOS 16.0+** (validated on iPhone 8 / 16.7.16)
  2. Shows **multiple Google accounts’ chats in the same window**
  3. Delivers **reliable notifications from both personal and work** accounts via **ntfy** (no paid Apple Developer account)

This plan is for building that client. It is not a drop-in clone of every Chat/Gemini feature.

---

## Recommended product shape

**Native SwiftUI app** that talks to the **Google Chat API** with **per-account OAuth**, plus a **required small relay backend** that turns Google Chat events into **ntfy** pushes.

| Approach | Fit | Why |
| --- | --- | --- |
| **A. Native Chat API client + ntfy relay (recommended)** | Best | True multi-account session, unified inbox, free Apple sideload, reliable dual-account alerts via ntfy’s existing push |
| B. Multi-WKWebView of `chat.google.com` | Weak | Cookie/session isolation is brittle; background push almost impossible; Google often breaks embedded login |
| C. Safari / Home Screen web app only | Stopgap only | Works today for reading/sending, but multi-account UX is poor |

Ship **A**. Use Safari only as a temporary bridge while the native MVP is built.

**Decisions locked:**

- **Notifications:** **ntfy** is first-class (not APNs in our app).
- **Apple account:** **Free** Xcode / sideload is enough for the Chat client (no TestFlight / no app push entitlement).
- Local notifications in our app are only a **fallback** while the app is open.

---

## Constraints that drive the design

### Device / OS

- Target: `IPHONEOS_DEPLOYMENT_TARGET = 16.0`
- Device class: iPhone 8 (A11, 2 GB RAM) — keep UI simple, avoid heavy image pipelines, paginate aggressively
- Distribution: **free Apple ID sideload** via Xcode (profiles expire ~7 days) or AltStore-style refresh
- Also install the **ntfy iOS app** on the same phone (confirm it still supports iOS 16 before build work goes deep)
- Xcode / macOS required to build and sign; this repo holds the iOS project and the notification relay

### Google platform

- Must create a **Google Cloud project**, enable **Google Chat API**, **Google Workspace Events API**, and **Pub/Sub** (+ People API as needed)
- OAuth consent screen in **Testing** mode is enough for personal use (add both Google accounts as test users)
- Chat message/space scopes are often **restricted/sensitive** — public App Store distribution would need Google verification; personal Testing mode avoids that
- **Workspace admin** can block third-party OAuth apps — work account access may need admin approval of the OAuth client
- Official Google Sign-In iOS SDK is awkward for concurrent multi-account; plan on **GoogleSignIn for the interactive flow + GTMAppAuth/Keychain for storing multiple authorizations** (keyed by `sub` / email)

### Notifications (ntfy-first)

Our sideloaded app cannot use APNs without a paid Apple Developer Program membership. Instead:

1. You subscribe in the **ntfy** app to a private topic (or topics), e.g. `https://ntfy.sh/your-secret-topic` or a self-hosted server
2. Relay creates **Google Workspace Events** subscriptions per Google account
3. Events land on **Pub/Sub** → relay handler
4. Relay `POST`s to ntfy with title/body/tags; ntfy’s iOS app delivers the system notification
5. Optional: include a deep link / tap action URL back into the Chat app or `chat.google.com`

**Fallback only:** while our Chat app is open, poll and show an in-app/local banner if ntfy/relay is down.

**ntfy hosting options:**

| Option | Cost | Notes |
| --- | --- | --- |
| Public `ntfy.sh` | Free | Use a **hard-to-guess topic** + access token if available; rate limits apply |
| Self-hosted ntfy | Free (VPS) | Best privacy/control; relay points at your server |

Requires:

- Always-on relay (Cloud Run / Fly / similar) for Google → ntfy
- Stored Google refresh tokens / event-subscription credentials on the relay (encrypted at rest)
- ntfy topic URL (+ auth) configured as a relay secret

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
- Attachments: download via Chat media API; upload later if heavy

### Notifications (via ntfy)

Example ntfy alerts:

```
[Work] #eng-standup
Alice: deploy looks good
```

```
[Personal] Family
Mom: dinner at 7?
```

- One topic for everything (simplest), or separate topics per Google account
- Per-account / per-space mute honored in the relay before publish
- Quiet hours in relay and/or ntfy app settings
- Privacy default: generic “New message in {space}” unless preview is enabled

---

## Feature scope by phase

### Phase 0 — Feasibility gate (do this first)

1. Confirm **ntfy iOS app** installs and notifies on the iPhone 8 / iOS 16.7.16.
2. Confirm both Google accounts can complete OAuth against a Testing consent screen.
3. Call `spaces.list` and `spaces.messages.list` for each token.
4. If work account fails: check Workspace admin “API controls” / OAuth app access.
5. Prove one end-to-end path: test publish → ntfy on device; then Workspace Event (or manual) → relay → ntfy.

**Exit criteria:** both accounts return spaces/messages, and a relay→ntfy test alert reaches the iPhone 8.

### Phase 1 — MVP (chat + first-class ntfy)

**Client (free sideload)**

- Multi-account sign-in / sign-out / token refresh
- Unified conversation list (merged, sorted by last activity)
- Open space / DM, paginated message history
- Send text messages; basic reactions
- Mark space read (`users.spaces.spaceReadState`)
- Offline cache of recent threads (**GRDB/SQLite**)
- Account-colored badges throughout
- Optional: custom URL scheme so ntfy tap-actions can open a space
- In-app/local banner fallback only when already foregrounded

**Relay (ships with MVP)**

- Maintain Workspace Events subscriptions + Pub/Sub consumer for each Google account
- Publish to ntfy (title = `[Account] space`, body = truncated text or privacy-safe line)
- Refresh subscription TTLs; retry failed deliveries
- Honor per-account / per-space mutes + quiet hours
- Config: ntfy base URL, topic, auth token

Out of MVP: Meet huddles, Gemini summaries, smart chips, Drive previews, custom sections parity, apps/bots marketplace, full search parity, native APNs.

### Phase 2 — Deeper Chat parity (as needed)

- Threads / replies UI
- File attach & image preview
- Unread sectioning closer to chat.google.com home
- People lookup / find DM
- Share extension (“send to Chat”)
- Richer ntfy actions (Open / Mute space)
- Optional later: paid Apple Dev + APNs if you ever want alerts inside our app itself

---

## Technical architecture

```
┌──────────────────────────────────────────────┐
│ iPhone 8 / iOS 16.7                          │
│  ┌─────────────────────┐  ┌────────────────┐ │
│  │ Chat app (sideload) │  │ ntfy iOS app   │ │
│  │ multi-account UI    │  │ system pushes  │ │
│  └─────────┬───────────┘  └────────▲───────┘ │
│            │                       │         │
└────────────┼───────────────────────┼─────────┘
             │ HTTPS Chat API        │ ntfy push
             ▼                       │
      Google Chat / OAuth            │
             │                       │
             ▼                       │
      Relay (Cloud Run / Fly) ───────┘
       ← Pub/Sub (Workspace Events)
       POST https://ntfy.sh/<topic>  (or self-hosted)
```

### Suggested modules

| Module | Responsibility |
| --- | --- |
| `Auth` | OAuth start, multi-account Keychain, refresh, logout |
| `ChatAPI` | Thin REST wrappers: spaces, messages, members, read state, media |
| `Sync` | Per-account fetchers, pagination, conflict-free upserts |
| `Inbox` | Merge/sort/filter across accounts |
| `UI` | Home list, thread, account manager, composer |
| `relay` | Events → Pub/Sub → ntfy; subscription lifecycle; mutes |

### Stack choices

- **Language/UI:** Swift 5.9+, SwiftUI (iOS 16 APIs only)
- **Networking:** URLSession + async/await
- **Auth:** AppAuth / GTMAppAuth + GoogleSignIn for UI
- **Persistence:** SQLite (GRDB)
- **Min OS:** iOS 16.0
- **Relay (MVP):** TypeScript or Go on Cloud Run/Fly; secrets for Google + ntfy; one Pub/Sub topic per environment

### OAuth scopes (start minimal)

- `openid` `email` `profile`
- `https://www.googleapis.com/auth/chat.spaces.readonly`
- `https://www.googleapis.com/auth/chat.messages` (or readonly + `chat.messages.create` if split works)
- Workspace Events scopes required for subscriptions used by the relay

Re-consent when scopes expand.

---

## Security & privacy (personal app)

- Google tokens only in **Keychain** on device
- Relay stores minimum needed for events + ntfy publish; encrypt refresh tokens at rest
- ntfy topic must be unguessable; prefer access tokens / self-hosted auth
- Privacy-safe notification bodies by default
- Clear data wipe on account remove (device + relay bindings)

---

## Distribution plan for iPhone 8

1. Free Apple ID + Xcode install of the Chat app (re-sign/refresh when the 7-day profile expires), or AltStore automation
2. Install **ntfy** from the App Store; subscribe to the private topic
3. Deploy relay; wire Google accounts + ntfy secret
4. Skip App Store / TestFlight / paid Apple push unless requirements change later

---

## Risks & mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| ntfy iOS app drops iOS 16 support | No reliable alerts | Verify Phase 0; fallback to Bark/self-host/email |
| Public ntfy.sh rate limits / topic guessing | Missed or leaked alerts | Secret topic + token; or self-host |
| Work Workspace blocks OAuth client | Can’t see work chats / events | Admin allowlist or company-internal OAuth app |
| Restricted scopes / unverified app warning | Scary consent screen | Keep OAuth in Testing; add test users |
| Relay or Pub/Sub outage | Missed pushes | Health checks; retry; in-app fallback when open |
| Workspace Events subscription expiry | Silent alert death | TTL refresh job; alert via ntfy if renew fails |
| Free provisioning expiry | Chat app stops launching | Calendar reminder / AltStore refresh |
| iPhone 8 memory pressure | Scroll crashes | Pagination, image cache limits |

---

## Stopgaps while building

1. **Safari** → `https://chat.google.com/app/home` (second profile/tab group for the other account)
2. Manual ntfy test messages to validate the phone path early
3. Desktop Chat / browser for anything the phone MVP cannot do yet

---

## Suggested repo layout (when implementation starts)

```
/
  README.md
  docs/PLAN.md                 ← this document
  ios/
    GoogleChatMulti/           ← Xcode project (SwiftUI, no APNs entitlement)
  relay/                       ← MVP: Workspace Events + Pub/Sub + ntfy publisher
  scripts/                     ← bootstrap Google Cloud / ntfy / secrets helpers
```

---

## Decision checklist

1. **Push channel:** **ntfy** (decided). Not APNs in our app.
2. **Apple Developer:** **Free sideload** (decided). Paid only if we later want TestFlight/APNs.
3. **Work account admin access:** Can you allowlist a custom OAuth client?
4. **Accounts in v1:** Exactly two (personal + work), or N accounts?
5. **Feature floor:** Text + DMs only, or spaces + reactions (+ attachments later)?
6. **Notification privacy:** Preview message text in ntfy, or generic “New message in {space}”?
7. **ntfy hosting:** Public `ntfy.sh` or self-hosted?

Default assumptions if unstated: **N accounts (start with 2)**, **ntfy relay in MVP**, **free Apple sideload**, **text + reactions + unified inbox first**, **privacy-safe bodies**, **public ntfy.sh with secret topic + token** (self-host later if needed).

---

## Implementation order (once remaining decisions are set)

1. Phase 0: ntfy on iPhone 8 + Google OAuth smoke tests
2. Scaffold relay (health check, manual → ntfy publish)
3. Scaffold iOS 16 SwiftUI app + Google OAuth (multi-account Keychain)
4. Workspace Events → Pub/Sub → ntfy for both accounts
5. `spaces.list` → local DB → unified home UI
6. Thread view + send message
7. Optional deep links / ntfy click actions into the app
8. Harden for iPhone 8 + relay TTL/retry + mutes
9. Optional later: attachments, search, richer parity

---

## Success criteria

- Both personal and work accounts signed in simultaneously in the Chat app
- One home list shows conversations from both, clearly labeled
- Opening a thread sends as the correct account
- New messages from **either** account alert via **ntfy** while the Chat app is backgrounded/killed
- App installs via free sideload and remains usable on **iPhone 8 / iOS 16.7.16**
