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
  elif [[ "${SKIP_SWIFT_TESTS:-}" == "1" ]]; then
    echo "swift not installed; SKIP_SWIFT_TESTS=1 set — skipping Core tests"
  else
    echo "swift not installed; refusing to report a full-suite pass." >&2
    echo "Install a Swift toolchain, or set SKIP_SWIFT_TESTS=1 to opt in to skipping." >&2
    exit 1
  fi
)

echo "All available automated tests passed."
