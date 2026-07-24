#!/usr/bin/env bash
# Phase 0 helper: publish a preview message to ntfy.sh (or local relay test endpoint).
set -euo pipefail

MODE="${1:-direct}" # direct | relay

TITLE="${TITLE:-[Work] #eng-standup}"
BODY="${BODY:-Alice: deploy looks good}"
CURL_OPTS=(--connect-timeout 5 --max-time 20)

if [[ "${MODE}" == "relay" ]]; then
  RELAY_URL="${RELAY_URL:-http://127.0.0.1:8080}"
  AUTH_HEADERS=()
  if [[ -n "${RELAY_API_TOKEN:-}" ]]; then
    AUTH_HEADERS=(-H "Authorization: Bearer ${RELAY_API_TOKEN}")
  fi
  curl -fsS "${CURL_OPTS[@]}" -X POST "${RELAY_URL}/v1/notify/test" \
    -H 'content-type: application/json' \
    "${AUTH_HEADERS[@]}" \
    -d "{\"title\":\"${TITLE}\",\"body\":\"${BODY}\"}"
  echo
  echo "Published via relay ${RELAY_URL}"
else
  TOPIC="${NTFY_TOPIC:?Set NTFY_TOPIC}"
  BASE="${NTFY_BASE_URL:-https://ntfy.sh}"
  AUTH=()
  if [[ -n "${NTFY_ACCESS_TOKEN:-}" ]]; then
    AUTH=(-H "Authorization: Bearer ${NTFY_ACCESS_TOKEN}")
  fi
  curl -fsS "${CURL_OPTS[@]}" -X POST "${BASE}/${TOPIC}" \
    -H "Title: ${TITLE}" \
    -H "Tags: chat,test" \
    "${AUTH[@]}" \
    -d "${BODY}"
  echo
  echo "Published directly to ${BASE} (topic redacted)"
fi
