#!/usr/bin/env bash
# Builds the Swift package and wraps the binary in a signed .app bundle at build/Gainsayer.app.
#
# Signing: set SIGN_IDENTITY to a code-signing identity in your keychain. If unset, a self-signed
# certificate named "Gainsayer Dev" is used when present, otherwise the build is ad-hoc signed.
# Ad-hoc signatures change on every build, which makes macOS forget the app's permissions.
set -euo pipefail
cd "$(dirname "$0")/.."

NAME=Gainsayer
CONFIG=${CONFIG:-release}
OUT="build/$NAME.app"

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/$NAME"

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN" "$OUT/Contents/MacOS/$NAME"
cp Support/Info.plist "$OUT/Contents/Info.plist"
printf 'APPL????' > "$OUT/Contents/PkgInfo"

IDENTITY=${SIGN_IDENTITY:-}
if [[ -z "$IDENTITY" ]] && security find-identity -v -p codesigning 2>/dev/null | grep -q '"Gainsayer Dev"'; then
    IDENTITY="Gainsayer Dev"
fi
if [[ -z "$IDENTITY" ]]; then
    echo "warning: no 'Gainsayer Dev' certificate found, ad-hoc signing (see README)" >&2
    IDENTITY="-"
fi

codesign --force --sign "$IDENTITY" "$OUT"
echo "Built $OUT (signed with: $IDENTITY)"
