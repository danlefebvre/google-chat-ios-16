#!/usr/bin/env bash
# Bootstrap helpers for Google Cloud (Chat API + Workspace Events + Pub/Sub).
# Requires: gcloud authenticated as a project owner / Workspace admin.
set -euo pipefail

PROJECT_ID="${GOOGLE_CLOUD_PROJECT:?Set GOOGLE_CLOUD_PROJECT}"
REGION="${REGION:-us-central1}"

echo "Enabling APIs on ${PROJECT_ID}..."
gcloud services enable \
  chat.googleapis.com \
  workspaceevents.googleapis.com \
  pubsub.googleapis.com \
  people.googleapis.com \
  --project="${PROJECT_ID}"

TOPIC="${PUBSUB_TOPIC:-chat-events}"
echo "Ensuring Pub/Sub topic ${TOPIC}..."
gcloud pubsub topics describe "${TOPIC}" --project="${PROJECT_ID}" >/dev/null 2>&1 \
  || gcloud pubsub topics create "${TOPIC}" --project="${PROJECT_ID}"

# Workspace Events / Chat API push delivery requires Pub/Sub Publisher on the topic.
# For Chat API interaction events use chat-api-push; override CHAT_EVENTS_SA for add-on SAs.
CHAT_EVENTS_SA="${CHAT_EVENTS_SA:-chat-api-push@system.gserviceaccount.com}"
echo "Granting roles/pubsub.publisher on ${TOPIC} to ${CHAT_EVENTS_SA}..."
gcloud pubsub topics add-iam-policy-binding "${TOPIC}" \
  --project="${PROJECT_ID}" \
  --member="serviceAccount:${CHAT_EVENTS_SA}" \
  --role="roles/pubsub.publisher" \
  --quiet

echo "Done."
echo "Next:"
echo "  1) Create OAuth client (iOS + Web) in Testing mode; add personal + work as test users"
echo "  2) Workspace admin: allowlist the OAuth client under API controls"
echo "  3) Deploy relay/ with NTFY_TOPIC + NTFY_ACCESS_TOKEN + PUBSUB_VERIFY_TOKEN + RELAY_API_TOKEN"
echo "  4) Point a Pub/Sub push subscription at https://<relay>/v1/pubsub/push?token=..."
