#!/usr/bin/env bash
# Phase 0: verify Google Chat API access for a bearer token (spaces.list).
set -euo pipefail

ACCESS_TOKEN="${ACCESS_TOKEN:?Set ACCESS_TOKEN to a valid Google OAuth access token}"

TMPFILE="$(mktemp)"
trap 'rm -f "${TMPFILE}"' EXIT

echo "GET spaces.list"
HTTP_CODE=$(curl -sS -o "${TMPFILE}" -w "%{http_code}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://chat.googleapis.com/v1/spaces?pageSize=10")

if [[ "${HTTP_CODE}" -ge 200 && "${HTTP_CODE}" -lt 300 ]]; then
  SPACE_COUNT=$(python3 -c "import json; print(len(json.load(open('${TMPFILE}')).get('spaces',[])))")
  echo "OK (${HTTP_CODE}) — ${SPACE_COUNT} space(s) returned"
  exit 0
fi

echo "FAILED (${HTTP_CODE})"
cat "${TMPFILE}"
exit 1
