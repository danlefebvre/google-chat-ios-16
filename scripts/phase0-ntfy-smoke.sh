#!/usr/bin/env bash
set -euo pipefail

TOPIC="${NTFY_TOPIC:-}"
TOKEN="${NTFY_ACCESS_TOKEN:-}"
BASE_URL="${NTFY_BASE_URL:-https://ntfy.sh}"

if [[ -z "$TOPIC" ]]; then
  echo "Set NTFY_TOPIC to your hard-to-guess topic name." >&2
  exit 1
fi

TITLE="${1:-[Test] Google Chat Multi}"
BODY="${2:-Phase 0 smoke test from scripts/phase0-ntfy-smoke.sh}"

HEADERS=(-H "Title: ${TITLE}" -H "Tags: test,google-chat")
if [[ -n "$TOKEN" ]]; then
  HEADERS+=(-H "Authorization: Bearer ${TOKEN}")
fi

echo "Publishing to ${BASE_URL}/${TOPIC}"
curl -fsS -X POST "${HEADERS[@]}" -d "${BODY}" "${BASE_URL}/${TOPIC}"
echo
echo "Check the ntfy iOS app on your iPhone 8 for the notification."
