# Notification relay (Google Chat → ntfy)

MVP relay that turns Google Workspace Events (via Pub/Sub push) into **ntfy.sh** notifications with message previews.

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/healthz` | Liveness |
| `POST` | `/v1/test/publish` | Manual preview publish (Phase 0 smoke test) |
| `POST` | `/v1/pubsub/push` | Pub/Sub push consumer |
| `DELETE` | `/v1/accounts/{accountID}` | Teardown: delete Workspace Events sub → revoke token → drop binding |

## Config

| Env | Required | Default | Notes |
| --- | --- | --- | --- |
| `PORT` | no | `8080` | Listen port |
| `NTFY_BASE_URL` | no | `https://ntfy.sh` | ntfy server |
| `NTFY_TOPIC` | for publish | — | Hard-to-guess topic |
| `NTFY_ACCESS_TOKEN` | recommended | — | Bearer token for ntfy |
| `QUIET_HOURS` | no | — | `HH:MM-HH:MM` UTC, e.g. `22:00-07:00` |
| `ACCOUNT_STORE` | no | — | Set to `memory` for explicit local-dev in-memory store |
| `ACCOUNT_STORE_PATH` | deploy | — | JSON path for durable encrypted account store |
| `ACCOUNT_STORE_KEY` | deploy | — | 32-byte key as 64 hex chars (AES-GCM) |
| `RELAY_API_TOKEN` | recommended | — | When set, mutating routes require `Authorization: Bearer …` |

## Local

```bash
cd relay
go test ./...
NTFY_TOPIC=your-secret-topic NTFY_ACCESS_TOKEN=... go run ./cmd/relay

curl -s localhost:8080/healthz
curl -s -X POST localhost:8080/v1/test/publish \
  -H 'content-type: application/json' \
  -d '{"accountLabel":"Work","spaceTitle":"#eng-standup","sender":"Alice","text":"deploy looks good"}'
```

## Teardown order (locked)

1. Delete Workspace Events subscription  
2. Revoke/delete stored refresh token  
3. Remove ntfy binding / account record  
4. (Client) wipe device Keychain binding afterward  
