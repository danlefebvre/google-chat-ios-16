#!/usr/bin/env bash
# Phase 0: smoke-test relay health + manual ntfy publish endpoint.
set -euo pipefail

RELAY_URL="${RELAY_URL:-http://localhost:8080}"

echo "GET ${RELAY_URL}/health"
curl -sS -f "${RELAY_URL}/health" | tee /tmp/relay-health.json
echo

echo "POST ${RELAY_URL}/test-notify"
curl -sS -f -X POST "${RELAY_URL}/test-notify" \
  -H "Content-Type: application/json" \
  -d '{
    "accountLabel": "Work",
    "spaceTitle": "#eng-standup",
    "senderName": "Alice",
    "messageText": "deploy looks good"
  }' | tee /tmp/relay-test-notify.json
echo
echo "OK — relay health and test-notify succeeded"
