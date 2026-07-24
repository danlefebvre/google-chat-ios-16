#!/usr/bin/env bash
# Phase 0: send a test notification to ntfy.sh and verify the topic is reachable.
set -euo pipefail

NTFY_BASE_URL="${NTFY_BASE_URL:-https://ntfy.sh}"
NTFY_TOPIC="${NTFY_TOPIC:?Set NTFY_TOPIC to your secret topic name}"
NTFY_ACCESS_TOKEN="${NTFY_ACCESS_TOKEN:-}"

TITLE="${1:-[Test] Google Chat Relay}"
BODY="${2:-Phase 0 smoke test from scripts/test-ntfy.sh}"

URL="${NTFY_BASE_URL%/}/${NTFY_TOPIC}"
HEADERS=(-H "Title: ${TITLE}" -H "Content-Type: text/plain; charset=utf-8")
if [[ -n "${NTFY_ACCESS_TOKEN}" ]]; then
  HEADERS+=(-H "Authorization: Bearer ${NTFY_ACCESS_TOKEN}")
fi

echo "Publishing to ${URL}"
HTTP_CODE=$(curl -sS -o /tmp/ntfy-response.txt -w "%{http_code}" -X POST "${HEADERS[@]}" -d "${BODY}" "${URL}")

if [[ "${HTTP_CODE}" -ge 200 && "${HTTP_CODE}" -lt 300 ]]; then
  echo "OK (${HTTP_CODE}) — check the ntfy app on your iPhone 8"
  exit 0
fi

echo "FAILED (${HTTP_CODE})"
cat /tmp/ntfy-response.txt
exit 1
