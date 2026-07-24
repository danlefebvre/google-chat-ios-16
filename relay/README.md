# Notification relay

Turns Google Workspace Events (via Pub/Sub) into **ntfy.sh** pushes with message previews.

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/healthz` | Health check |
| `POST` | `/v1/notify/test` | Manual publish `{ "title", "body" }` |
| `POST` | `/v1/pubsub/push?token=...` | Pub/Sub push consumer |
| `GET/POST` | `/v1/accounts` | List / register Google accounts |
| `DELETE` | `/v1/accounts/{id}` | Teardown (subscription → revoke token → clear ntfy → wipe) |
| `POST` | `/v1/mutes` | Mute/unmute account or space |

## Config

| Env | Description |
| --- | --- |
| `HTTP_ADDR` | Listen address (default `:8080`) |
| `RELAY_ENV` | `development` / `production` (`NTFY_TOPIC` required in production) |
| `NTFY_BASE_URL` | Default `https://ntfy.sh` |
| `NTFY_TOPIC` | Secret-but-not-private topic |
| `NTFY_ACCESS_TOKEN` | Optional ntfy access token |
| `QUIET_HOURS_START` / `QUIET_HOURS_END` | Local quiet window (equal = disabled) |
| `PUBSUB_VERIFY_TOKEN` | Query token for push endpoint |
| `TOKEN_ENCRYPTION_KEY` | 32-byte key for encrypting refresh tokens at rest |

## Local

```bash
export NTFY_TOPIC=your-secret-topic
export NTFY_ACCESS_TOKEN=optional
go test ./...
go run ./cmd/relay
curl -s localhost:8080/healthz
curl -s -X POST localhost:8080/v1/notify/test \
  -H 'content-type: application/json' \
  -d '{"title":"[Work] test","body":"Alice: hello from relay"}'
```
