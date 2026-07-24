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

## Important routes

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/health` | Liveness |
| POST | `/pubsub/push` | Pub/Sub push endpoint |
| POST | `/admin/test-ntfy` | Manual preview publish |
| POST | `/admin/accounts` | Register Google account + create events subscription |
| DELETE | `/admin/accounts/:accountId` | Teardown (subscription → revoke token → wipe) |
| POST | `/admin/accounts/:accountId/mute` | Mute account |
| POST | `/admin/accounts/:accountId/spaces/mute` | Mute space |
| PUT | `/admin/quiet-hours` | Configure quiet hours |

## Deploy

Dockerfile is included for Cloud Run / Fly. Provide the env vars from `.env.example`.

In-memory account store is MVP scaffolding — swap `InMemoryStore` for Firestore/SQLite before multi-instance production.
