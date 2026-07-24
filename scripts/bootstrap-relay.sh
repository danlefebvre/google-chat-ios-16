#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELAY_DIR="${ROOT_DIR}/relay"

if [[ ! -f "${RELAY_DIR}/.env" ]]; then
  if [[ ! -f "${RELAY_DIR}/.env.example" ]]; then
    cat > "${RELAY_DIR}/.env.example" <<'EOF'
NTFY_BASE_URL=https://ntfy.sh
NTFY_TOPIC=replace-with-long-random-topic
NTFY_ACCESS_TOKEN=
PORT=8080
DEEP_LINK_SCHEME=gchatmulti
EOF
  fi
  cp "${RELAY_DIR}/.env.example" "${RELAY_DIR}/.env"
  echo "Created relay/.env from .env.example — edit NTFY_TOPIC before running."
fi

cd "${RELAY_DIR}"
npm install
npm test
npm run build

echo "Relay ready. Start with: cd relay && set -a && source .env && set +a && npm start"
