# Google Chat notification relay

TypeScript relay that consumes Google Workspace Events (via Pub/Sub push) and publishes message previews to [ntfy.sh](https://ntfy.sh).

## Features

- `GET /health` health check
- `POST /pubsub/push` Pub/Sub push handler for Chat message events
- `POST /test/notify` manual ntfy publish for Phase 0 smoke tests
- Per-account / per-space mutes and quiet hours
- Ordered account teardown (subscription delete → token revoke → store remove)

## Configuration

| Variable | Required | Default |
| --- | --- | --- |
| `PORT` | no | `8080` |
| `NTFY_BASE_URL` | no | `https://ntfy.sh` |
| `NTFY_TOPIC` | yes | — |
| `NTFY_ACCESS_TOKEN` | no | — |
| `DEEP_LINK_SCHEME` | no | `gchatmulti` |

## Development (TDD)

```bash
cd relay
npm install
npm test
npm run dev
```

## Manual ntfy smoke test

```bash
NTFY_TOPIC=your-secret-topic npm run dev
../scripts/test-ntfy.sh http://localhost:8080
```

## Deploy

Build and run the compiled server on Cloud Run, Fly.io, or similar. Point a Pub/Sub push subscription at `POST /pubsub/push`.
