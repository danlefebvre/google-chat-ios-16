# Google Chat → ntfy relay

Always-on service that turns Google Workspace Events (via Pub/Sub) into **ntfy.sh** pushes with message previews.

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/healthz` | Liveness |
| `POST` | `/pubsub/push` | Pub/Sub push consumer |
| `POST` | `/v1/test-publish` | Manual ntfy publish (Phase 0) |
| `GET/POST` | `/v1/accounts` | List / register Google accounts |
| `DELETE` | `/v1/accounts/{id}` | Teardown: delete subscription → revoke token → invalidate ntfy → wipe |
| `POST` | `/v1/mutes` | Per-account / per-space mute |

## Required env

- `NTFY_TOPIC` — hard-to-guess topic on ntfy.sh
- `TOKEN_ENCRYPTION_KEY` — 64 hex chars (32-byte AES key)
- `NTFY_BASE_URL` — default `https://ntfy.sh`
- `NTFY_TOKEN` — optional access token
- `ACCOUNTS_PATH` — default `./data/accounts.json` (must be on durable storage in Cloud Run/Fly; ephemeral disk loses bindings on restart)
- `QUIET_HOURS_*` — optional quiet window

## Local

```bash
export NTFY_TOPIC=your-secret-topic
export TOKEN_ENCRYPTION_KEY=$(openssl rand -hex 32)
go test ./...
go run ./cmd/relay
curl -X POST localhost:8080/v1/test-publish \
  -H 'content-type: application/json' \
  -d '{"accountLabel":"Work","spaceTitle":"#eng-standup","sender":"Alice","preview":"deploy looks good"}'
```
