#!/usr/bin/env bash
# Phase 0 — Google Chat API smoke test for one OAuth access token.
# Usage: ACCESS_TOKEN=ya29... ./scripts/phase0-google-chat-smoke.sh
set -euo pipefail

: "${ACCESS_TOKEN:?Set ACCESS_TOKEN to a valid Google OAuth access token}"

echo "== spaces.list =="
curl -fsS -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://chat.googleapis.com/v1/spaces?pageSize=5&filter=spaceType%20%3D%20%22SPACE%22%20OR%20spaceType%20%3D%20%22DIRECT_MESSAGE%22" \
  | head -c 2000
echo ""

SPACE_NAME="${SPACE_NAME:-}"
if [[ -z "${SPACE_NAME}" ]]; then
  SPACE_NAME=$(curl -fsS -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "https://chat.googleapis.com/v1/spaces?pageSize=1" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('spaces',[{}])[0].get('name',''))" 2>/dev/null || true)
fi

if [[ -n "${SPACE_NAME}" && "${SPACE_NAME}" != "" ]]; then
  echo "== messages.list for ${SPACE_NAME} =="
  curl -fsS -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "https://chat.googleapis.com/v1/${SPACE_NAME}/messages?pageSize=5" \
    | head -c 2000
  echo ""
else
  echo "No spaces found — add SPACE_NAME=spaces/XXX to probe messages.list"
fi

echo "Smoke test finished."
