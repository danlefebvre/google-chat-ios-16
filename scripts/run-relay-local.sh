#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export NTFY_BASE_URL="${NTFY_BASE_URL:-https://ntfy.sh}"
export NTFY_TOPIC="${NTFY_TOPIC:?set NTFY_TOPIC to your hard-to-guess topic}"
export NTFY_TOKEN="${NTFY_TOKEN:-}"
export TOKEN_ENCRYPTION_KEY="${TOKEN_ENCRYPTION_KEY:?set TOKEN_ENCRYPTION_KEY (see scripts/gen-encryption-key.sh) so encrypted accounts persist across restarts}"
export ACCOUNTS_PATH="${ACCOUNTS_PATH:-$ROOT/relay/data/accounts.json}"
export PORT="${PORT:-8080}"
mkdir -p "$(dirname "$ACCOUNTS_PATH")"
cd "$ROOT/relay"
go run ./cmd/relay
