#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> relay go test"
(cd "$ROOT/relay" && go test ./...)

if command -v swift >/dev/null 2>&1; then
  echo "==> ios swift test"
  # shellcheck disable=SC1090
  if [[ -f "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh" ]]; then
    # shellcheck source=/dev/null
    source "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"
  fi
  (cd "$ROOT/ios" && swift test)
else
  echo "swift not installed; skipping ios tests"
fi
