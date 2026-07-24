#!/usr/bin/env bash
# Copy relay env template and print next steps for Google Cloud + ntfy.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT}/relay/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  cp "${ROOT}/relay/.env.example" "${ENV_FILE}"
  echo "Created ${ENV_FILE} — edit NTFY_TOPIC and tokens before starting the relay."
else
  echo "${ENV_FILE} already exists."
fi

cat <<'EOF'

Next steps (PLAN.md Phase 0–1):
1. Create a Google Cloud project; enable Chat API, Workspace Events API, Pub/Sub.
2. Configure OAuth consent (Testing) and add personal + work accounts as test users.
3. Pick a hard-to-guess ntfy topic on https://ntfy.sh and set NTFY_TOPIC + NTFY_ACCESS_TOKEN.
4. cd relay && npm install && npm run dev
5. ./scripts/phase0-ntfy-test.sh
6. Complete OAuth on device; run ./scripts/phase0-google-chat-smoke.sh with ACCESS_TOKEN.

EOF
