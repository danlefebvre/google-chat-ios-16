#!/usr/bin/env bash
# Bootstraps Google Cloud APIs + OAuth notes for the personal Testing consent screen.
set -euo pipefail

PROJECT_ID="${1:-}"
if [[ -z "${PROJECT_ID}" ]]; then
  echo "Usage: $0 <gcp-project-id>" >&2
  exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud CLI is required." >&2
  exit 1
fi

gcloud config set project "${PROJECT_ID}"

gcloud services enable \
  chat.googleapis.com \
  workspaceevents.googleapis.com \
  pubsub.googleapis.com \
  people.googleapis.com

TOPIC="chat-events"
if ! gcloud pubsub topics describe "${TOPIC}" \
  --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud pubsub topics create "${TOPIC}" \
    --project="${PROJECT_ID}" --quiet
fi

echo
echo "Next manual steps in Google Cloud Console:"
echo "  1. OAuth consent screen → Testing; add personal + work accounts as test users."
echo "  2. Create OAuth client (iOS) and paste client ID into ios/GoogleChatMulti/Info.plist (GIDClientID)."
echo "  3. As Workspace admin, allowlist the OAuth client under API controls if work login is blocked."
echo "  4. Create a Pub/Sub push subscription pointing at https://YOUR_RELAY/pubsub/push"
echo "  5. Export relay env:"
echo "       GOOGLE_PROJECT_ID=${PROJECT_ID}"
echo "       GOOGLE_PUBSUB_TOPIC=projects/${PROJECT_ID}/topics/${TOPIC}"
echo "       GOOGLE_OAUTH_CLIENT_ID=..."
echo "       GOOGLE_OAUTH_CLIENT_SECRET=..."
echo
echo "OAuth scopes (MVP):"
echo "  openid email profile"
echo "  https://www.googleapis.com/auth/chat.spaces.readonly"
echo "  https://www.googleapis.com/auth/chat.messages"
echo "  https://www.googleapis.com/auth/chat.users.readstate"
echo "  (+ Workspace Events scopes when creating subscriptions)"
