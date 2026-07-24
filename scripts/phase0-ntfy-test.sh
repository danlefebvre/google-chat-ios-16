#!/usr/bin/env bash
# Phase 0 — prove ntfy path reaches your phone (PLAN.md step 1 & 5).
set -euo pipefail

RELAY_URL="${RELAY_URL:-http://localhost:8080}"
TITLE="${TITLE:-[Test] Google Chat Relay}"
BODY="${BODY:-Alice: deploy looks good}"

echo "POST ${RELAY_URL}/test/notify"
curl -fsS -X POST "${RELAY_URL}/test/notify" \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"${TITLE}\",\"body\":\"${BODY}\"}"

echo ""
echo "OK — check the ntfy app on your iPhone 8 for the notification."
