#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Relay tests"
(
  cd "${ROOT}/relay"
  npm test
  npm run lint
)

echo "==> iOS Core tests"
(
  export PATH="${HOME}/swift/usr/bin:${PATH}"
  cd "${ROOT}/ios/GoogleChatMultiCore"
  if command -v swift >/dev/null 2>&1; then
    swift test
  else
    echo "swift not installed; skip Core tests (run on macOS/Xcode or install Swift toolchain)"
  fi
)

echo "All available automated tests passed."
