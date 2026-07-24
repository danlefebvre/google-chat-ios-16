#!/usr/bin/env bash
# Bootstrap helper: print required Google Cloud APIs and OAuth scopes.
set -euo pipefail

cat <<'EOF'
Google Cloud setup checklist (Phase 0+):

1. Create a Google Cloud project
2. Enable APIs:
   - Google Chat API
   - Google Workspace Events API
   - Cloud Pub/Sub
   - People API (optional, for DM lookup)
3. Create OAuth 2.0 client (iOS + Web for relay)
4. OAuth consent screen: Testing mode; add personal + work accounts as test users
5. Workspace admin: allowlist the OAuth client for the work domain
6. Create Pub/Sub topic + push subscription pointing at relay /pubsub endpoint
7. Set relay env (current entrypoint):
   - NTFY_TOPIC, NTFY_ACCESS_TOKEN (optional), NTFY_BASE_URL (optional), PORT (optional)
8. Planned relay env (OAuth / Pub/Sub wiring not in entrypoint yet):
   - GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET
   - PUBSUB_TOPIC, GCP_PROJECT_ID

OAuth scopes (minimal):
  openid email profile
  https://www.googleapis.com/auth/chat.spaces.readonly
  https://www.googleapis.com/auth/chat.messages
  https://www.googleapis.com/auth/chat.users.readstate
  (plus Workspace Events scopes for relay subscriptions)

Phase 0 exit criteria:
  - scripts/test-ntfy.sh reaches your iPhone 8 ntfy app
  - scripts/test-google-chat-api.sh succeeds for BOTH accounts
  - scripts/test-relay.sh publishes a preview notification via relay
EOF
