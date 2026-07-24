# google-chat-ntfy-relay

Small always-on relay: **Google Workspace Events → Pub/Sub → ntfy.sh** with message previews.

## Quick start

```bash
cp .env.example .env
# fill ADMIN_TOKEN, RELAY_TOKEN_SECRET, NTFY_* 
npm install
npm test
npm run dev
```

Health: `GET /health`  
Manual Phase 0 smoke: `POST /admin/test-ntfy` (Bearer admin token)

**Security:** `ADMIN_TOKEN` is a relay-wide secret for ops routes only. Do **not** embed it in the iOS app. Registration accepts a Google refresh token (for Workspace Events) and returns an opaque relay-scoped credential; teardown/mute-style user account auth uses that credential, not the Google refresh token.

## Important routes

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/health` | Liveness |
| POST | `/pubsub/push` | Pub/Sub push endpoint |
| POST | `/accounts` | App: register account (body includes refresh token; response includes `relayCredential`) |
| DELETE | `/accounts/:accountId` | App: teardown (`Authorization: Bearer <relayCredential>`) |
| POST | `/admin/test-ntfy` | Manual preview publish (admin token) |
| POST | `/admin/accounts` | Ops: register Google account + create events subscription |
| DELETE | `/admin/accounts/:accountId` | Ops: teardown (subscription → revoke token → wipe) |
| POST | `/admin/accounts/:accountId/mute` | Mute account |
| POST | `/admin/accounts/:accountId/spaces/mute` | Mute space |
| PUT | `/admin/quiet-hours` | Configure quiet hours |
| POST | `/admin/renew-subscriptions` | Renew expiring Workspace Events subscriptions |

## Deploy

Dockerfile is included for Cloud Run / Fly. Provide the env vars from `.env.example`.

Account state defaults to a JSON file (`ACCOUNT_STORE_PATH`, default `data/accounts.json` → `/app/data/accounts.json` in the image). **That file store requires durable storage** — mount a persistent volume at `/app/data` (the image declares `VOLUME /app/data`). Deployments without a durable mount must configure an external store (Firestore/SQLite/etc.) instead of relying on ephemeral container disk; otherwise linked accounts are lost on restart or redeploy. For multi-replica production, use a shared volume or that external store.
