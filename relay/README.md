# Google Chat notification relay

Small HTTP service that receives Google Workspace Events (via Pub/Sub push), formats message previews, and publishes to **ntfy.sh**.

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/health` | Liveness |
| POST | `/test/notify` | Manual ntfy publish (Phase 0) |
| POST | `/pubsub/push` | Pub/Sub push receiver (`X-Account-Id` header) |
| POST | `/accounts` | Register account binding (MVP) |
| DELETE | `/accounts/:accountId` | Teardown per PLAN.md |

## Development (TDD)

```bash
cd relay
npm install
npm test          # vitest
npm run dev       # tsx watch
```

## Configuration

Copy `.env.example` to `.env` or export variables. Required: `NTFY_SERVER`, `NTFY_TOPIC`.

## Deploy

Build and run on Cloud Run / Fly with the same env vars. Point Pub/Sub push subscriptions at `POST /pubsub/push` with an `X-Account-Id` header per Google account.
