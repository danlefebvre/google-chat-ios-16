#!/usr/bin/env bash
# Build an unsigned GoogleChatMulti.ipa for AltServer sideload.
# Writes GoogleChatMulti.ipa into the current working directory.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS_DIR="$ROOT/ios"
PROJECT="$IOS_DIR/GoogleChatMulti.xcodeproj"
SCHEME="GoogleChatMulti"
OUT_IPA="${PWD}/GoogleChatMulti.ipa"
DERIVED="${TMPDIR:-/tmp}/GoogleChatMulti-ipa-$$"
APP="$DERIVED/Build/Products/Release-iphoneos/GoogleChatMulti.app"

cleanup() { rm -rf "$DERIVED"; }
trap cleanup EXIT

if [[ ! -d "$PROJECT" ]]; then
  echo "error: missing Xcode project at $PROJECT" >&2
  exit 1
fi

echo "→ Building Release (unsigned) for device…"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "$APP" ]]; then
  echo "error: app bundle not found at $APP" >&2
  exit 1
fi

STAGE="$(mktemp -d)"
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"
rm -f "$OUT_IPA"
(cd "$STAGE" && zip -qr "$OUT_IPA" Payload)
rm -rf "$STAGE"

echo "✓ $OUT_IPA ($(du -h "$OUT_IPA" | awk '{print $1}'))"
echo "  Sideload: ⌥-click AltServer → Sideload .ipa…"
