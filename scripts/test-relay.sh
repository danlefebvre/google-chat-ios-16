#!/usr/bin/env bash
# Phase 0: smoke-test relay health + manual ntfy publish endpoint.
set -euo pipefail

RELAY_URL="${RELAY_URL:-http://localhost:8080}"

HEALTH_TMP="$(mktemp)"
NOTIFY_TMP="$(mktemp)"
trap 'rm -f "${HEALTH_TMP}" "${NOTIFY_TMP}"' EXIT

echo "GET ${RELAY_URL}/health"
curl -sS -f "${RELAY_URL}/health" | tee "${HEALTH_TMP}"
echo

echo "POST ${RELAY_URL}/test-notify"
curl -sS -f -X POST "${RELAY_URL}/test-notify" \
  -H "Content-Type: application/json" \
  -d '{
    "accountLabel": "Work",
    "spaceTitle": "#eng-standup",
    "senderName": "Alice",
    "messageText": "deploy looks good"
  }' | tee "${NOTIFY_TMP}"
echo
echo "OK — relay health and test-notify succeeded"
