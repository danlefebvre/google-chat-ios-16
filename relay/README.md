# google-chat-bark-relay

Small always-on relay: **Google Workspace Events → Pub/Sub → Bark** with message previews and app-icon badges.

## Quick start

1. Install **Bark** from the App Store on the iPhone.
2. Open Bark and copy your device key (from the test URL, e.g. `https://api.day.app/<deviceKey>/…`).
3. Configure the relay:

```bash
cp .env.example .env
# fill ADMIN_TOKEN, RELAY_TOKEN_SECRET, BARK_DEVICE_KEY
npm install
npm test
npm run dev
```

Health: `GET /health`  
Manual smoke: `POST /admin/test-bark` (Bearer admin token)

**Security:** `ADMIN_TOKEN` is a relay-wide secret for ops routes only. Do **not** embed it in the iOS app. Registration accepts a Google refresh token (for Workspace Events) and returns an opaque relay-scoped credential; teardown/mute-style user account auth uses that credential, not the Google refresh token.

## Important routes

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/health` | Liveness (+ current badge count) |
| POST | `/pubsub/push` | Pub/Sub push endpoint |
| POST | `/accounts` | App: register account (body includes refresh token; response includes `relayCredential`) |
| DELETE | `/accounts/:accountId` | App: teardown (`Authorization: Bearer <relayCredential>`) |
| POST | `/admin/test-bark` | Manual preview publish with badge (admin token) |
| POST | `/admin/badge/reset` | Reset Bark badge to 0 (admin token) |
| POST | `/admin/accounts` | Ops: register Google account + create events subscription |
| DELETE | `/admin/accounts/:accountId` | Ops: teardown (subscription → revoke token → wipe) |
| POST | `/admin/accounts/:accountId/mute` | Mute account |
| POST | `/admin/accounts/:accountId/spaces/mute` | Mute space |
| PUT | `/admin/quiet-hours` | Configure quiet hours |
| POST | `/admin/renew-subscriptions` | Renew expiring Workspace Events subscriptions |

## Badge behavior

Each Chat notification increments a durable badge counter and sends it to Bark (`badge: N`). Opening Bark usually clears the iOS icon badge; call `POST /admin/badge/reset` (or open Bark) when you want the counter back to zero for the next wave of alerts.

Tap actions use the same `googlechatmulti://space/…` deep links as before.

## Deploy

Dockerfile is included for Cloud Run / Fly / Coolify. Provide the env vars from `.env.example` — replace former `NTFY_*` vars with `BARK_BASE_URL` + `BARK_DEVICE_KEY`.

Account state defaults to a JSON file (`ACCOUNT_STORE_PATH`, default `data/accounts.json` → `/app/data/accounts.json` in the image). **That file store requires durable storage** — mount a persistent volume at `/app/data` (the image declares `VOLUME /app/data`). Deployments without a durable mount must configure an external store (Firestore/SQLite/etc.) instead of relying on ephemeral container disk; otherwise linked accounts are lost on restart or redeploy. For multi-replica production, use a shared volume or that external store.
