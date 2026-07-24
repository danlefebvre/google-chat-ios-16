# Google Chat Multi — Relay

Notification relay: Google Workspace Events (Pub/Sub) → **ntfy.sh** with message previews.

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/health` | Liveness check |
| `POST` | `/test-notify` | Manual ntfy publish (Phase 0 smoke test) |
| `POST` | `/pubsub` | Pub/Sub push receiver for Workspace Events |

## Environment

```bash
export NTFY_TOPIC="your-secret-topic"
export NTFY_ACCESS_TOKEN="optional-token"
export NTFY_BASE_URL="https://ntfy.sh"   # default
export PORT=8080
```

## Development (TDD)

```bash
npm install
npm test          # vitest
npm run dev       # tsx watch
npm run build && npm start
```

## Docker

```bash
docker build -t google-chat-relay .
docker run -e NTFY_TOPIC=your-topic -p 8080:8080 google-chat-relay
```

## Account teardown order

1. Delete Workspace Events subscription
2. Revoke relay-stored refresh token
3. Remove account from relay store
4. Wipe device Keychain entries (iOS app)
