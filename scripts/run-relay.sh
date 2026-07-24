#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/relay"
export PORT="${PORT:-8080}"
export NTFY_BASE_URL="${NTFY_BASE_URL:-https://ntfy.sh}"
if [[ -z "${NTFY_TOPIC:-}" ]]; then
  echo "Set NTFY_TOPIC (and optionally NTFY_ACCESS_TOKEN) before publishing." >&2
fi
exec go run ./cmd/relay
