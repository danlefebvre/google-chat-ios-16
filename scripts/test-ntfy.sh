#!/usr/bin/env bash
set -euo pipefail

# Phase 0 helper: publish a preview notification to ntfy (direct or via relay).
# Usage:
#   NTFY_TOPIC=secret ./scripts/test-ntfy.sh
#   RELAY_URL=http://localhost:8080 ./scripts/test-ntfy.sh

TOPIC="${NTFY_TOPIC:-}"
BASE="${NTFY_BASE_URL:-https://ntfy.sh}"
TOKEN="${NTFY_TOKEN:-}"
RELAY_URL="${RELAY_URL:-}"

if [[ -n "${RELAY_URL}" ]]; then
  curl -fsS -X POST "${RELAY_URL%/}/v1/test-publish" \
    -H 'content-type: application/json' \
    -d '{"accountLabel":"Work","spaceTitle":"#eng-standup","sender":"Alice","preview":"deploy looks good"}'
  echo "Published via relay ${RELAY_URL}"
  exit 0
fi

if [[ -z "${TOPIC}" ]]; then
  echo "Set NTFY_TOPIC or RELAY_URL" >&2
  exit 1
fi

ARGS=(-H 'Title: [Work] #eng-standup' -H 'Tags: speech_balloon' -d 'Alice: deploy looks good')
if [[ -n "${TOKEN}" ]]; then
  ARGS+=(-H "Authorization: Bearer ${TOKEN}")
fi
curl -fsS -X POST "${BASE%/}/${TOPIC}" "${ARGS[@]}"
echo "Published to ${BASE%/}/${TOPIC}"
