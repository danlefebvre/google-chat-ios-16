#!/usr/bin/env bash
# Phase 0 helpers: relay health + manual ntfy publish smoke test.
set -euo pipefail

RELAY_URL="${RELAY_URL:-http://127.0.0.1:8080}"

echo "==> health"
curl -fsS --connect-timeout 5 --max-time 30 "$RELAY_URL/healthz"
echo

echo "==> manual ntfy publish (preview)"
curl -fsS -X POST "$RELAY_URL/v1/test/publish" \
  --connect-timeout 5 \
  --max-time 30 \
  -H 'content-type: application/json' \
  -d '{"accountLabel":"Work","spaceTitle":"#eng-standup","sender":"Alice","text":"deploy looks good"}'
echo
echo "Check the ntfy iOS app for the preview notification."
