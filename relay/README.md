# Relay

Small HTTP service that receives Google Workspace Events (via Pub/Sub push), formats message previews, and publishes to **ntfy.sh**.

## Quick start

```bash
./scripts/bootstrap-relay.sh
cd relay
set -a && source .env && set +a
npm start
```

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/health` | Liveness probe |
| POST | `/test/notify` | Manual ntfy publish (`{ "title", "body" }`) |
| POST | `/pubsub/push` | Pub/Sub push receiver |
| GET/POST/DELETE | `/accounts` | Register or tear down relay-side account bindings |

## Tests (TDD)

```bash
cd relay
npm test
```

## Environment

Copy `.env.example` to `.env`:

- `NTFY_BASE_URL` — default `https://ntfy.sh`
- `NTFY_TOPIC` — secret-but-not-private topic name
- `NTFY_ACCESS_TOKEN` — optional bearer token
- `DEEP_LINK_SCHEME` — default `gchatmulti`

## Docker

```bash
docker build -t google-chat-relay relay/
docker run --env-file relay/.env -p 8080:8080 google-chat-relay
```
