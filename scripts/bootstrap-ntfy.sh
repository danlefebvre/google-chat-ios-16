#!/usr/bin/env bash
# Phase 0 helper: create a hard-to-guess ntfy topic + optional access token reminder.
set -euo pipefail

TOPIC="${1:-chat-$(openssl rand -hex 16)}"
BASE_URL="${NTFY_BASE_URL:-https://ntfy.sh}"

echo "ntfy topic (secret-but-not-private):"
echo "  ${BASE_URL}/${TOPIC}"
echo
echo "On the iPhone 8:"
echo "  1. Install the ntfy app (confirm iOS 16 still supported)."
echo "  2. Subscribe to the topic above."
echo "  3. Prefer an access token / AutoLogin if you enable auth on the topic."
echo
echo "Export for the relay:"
echo "  export NTFY_BASE_URL=${BASE_URL}"
echo "  export NTFY_TOPIC=${TOPIC}"
echo "  export NTFY_ACCESS_TOKEN=tk_your_token"
echo
echo "Smoke test publish:"
echo "  curl -d 'Alice: deploy looks good' \\"
echo "    -H 'Title: [Work] #eng-standup' \\"
echo "    -H 'Tags: speech_balloon' \\"
echo "    ${BASE_URL}/${TOPIC}"
