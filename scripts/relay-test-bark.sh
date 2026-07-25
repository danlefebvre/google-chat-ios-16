#!/usr/bin/env bash
# Calls the relay admin endpoint to prove relay → Bark → iPhone path.
set -euo pipefail

BASE_URL="${RELAY_BASE_URL:-http://127.0.0.1:8080}"
ADMIN_TOKEN="${ADMIN_TOKEN:?Set ADMIN_TOKEN}"

curl -sS --fail-with-body -X POST "${BASE_URL}/admin/test-bark" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "accountLabel": "Work",
    "spaceTitle": "#eng-standup",
    "senderName": "Alice",
    "messageText": "deploy looks good"
  }'
echo
