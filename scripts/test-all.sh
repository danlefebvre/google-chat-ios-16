#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> relay go test"
(cd "$ROOT/relay" && go test ./...)

SWIFTLY_ENV="${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"
if [[ -f "$SWIFTLY_ENV" ]]; then
  # shellcheck source=/dev/null
  source "$SWIFTLY_ENV"
fi

if command -v swift >/dev/null 2>&1; then
  echo "==> ios swift test"
  (cd "$ROOT/ios" && swift test)
else
  echo "swift not installed; skipping ios tests"
fi
