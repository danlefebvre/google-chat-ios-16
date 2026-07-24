#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELAY_DIR="$ROOT_DIR/relay"

echo "==> Installing relay dependencies"
(cd "$RELAY_DIR" && npm install)

echo "==> Running relay tests"
(cd "$RELAY_DIR" && npm test)

echo "==> Building relay"
(cd "$RELAY_DIR" && npm run build)

if command -v xcodegen >/dev/null 2>&1; then
  echo "==> Generating Xcode project"
  (cd "$ROOT_DIR/ios/GoogleChatMulti" && xcodegen generate)
else
  echo "==> Skipping Xcode project generation (install xcodegen on macOS)"
fi

if command -v xcodebuild >/dev/null 2>&1; then
  echo "==> Running iOS core package tests"
  (cd "$ROOT_DIR/ios/Packages/GoogleChatCore" && swift test)
else
  echo "==> Skipping Swift tests (requires macOS + Xcode)"
fi

echo "Done."
