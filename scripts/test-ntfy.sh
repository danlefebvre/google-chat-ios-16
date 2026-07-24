#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <relay-base-url>"
  echo "Example: $0 http://localhost:8080"
  exit 1
fi

BASE_URL="${1%/}"

curl -fsS -X POST "$BASE_URL/test/notify" \
  -H 'Content-Type: application/json' \
  -d '{
    "accountLabel": "Work",
    "spaceTitle": "#eng-standup",
    "senderName": "Alice",
    "messagePreview": "deploy looks good",
    "spaceResourceName": "spaces/demo"
  }'

echo
echo "Sent test notification to relay."
