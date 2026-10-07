#!/bin/zsh
# Build, bundle, sign and (optionally) notarize "Checkup for Stardew Valley.app".
#
#   ./build.sh                       ad-hoc signed app in ./build (local testing)
#   ./build.sh --open                …and launch it
#   ./build.sh --sign devid          Developer ID + hardened runtime (direct download)
#   ./build.sh --sign devid --notarize
#
# Options: debug|release (default release), --universal (arm64 + x86_64)
#
# Environment:
#   TEAM_ID              Apple team id (or put it in .release.env / ~/.config/mac-app-kit/defaults.env, both git-ignored)
#   NOTARY_PROFILE       notarytool keychain profile (default notarize-profile), or
#   APPLE_ID / APPLE_APP_PASSWORD / APPLE_TEAM_ID for notarytool with an app-specific password, or
#   ASC_KEY_ID / ASC_ISSUER_ID to notarize with the App Store Connect API key
set -euo pipefail
cd "$(dirname "$0")"

CONFIG=release
SIGN=none
NOTARIZE=0
OPEN=0
UNIVERSAL=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    debug|release) CONFIG=$1 ;;
    --sign) SIGN=$2; shift ;;
    --notarize) NOTARIZE=1 ;;
    --open) OPEN=1 ;;
    --universal) UNIVERSAL=1 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
  shift
done

APP_NAME="Checkup for Stardew Valley"
BUNDLE_ID="com.patlaplante.StardewCheckup"
# Personal defaults live outside the repo: ~/.config/mac-app-kit/defaults.env, then ./.release.env (both optional).
for f in "$HOME/.config/mac-app-kit/defaults.env" ./.release.env; do [[ -f $f ]] && source "$f"; done
BUILD_DIR="$PWD/build"
APP="$BUILD_DIR/$APP_NAME.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"

# ---------------------------------------------------------------- build
ARCH_FLAGS=()
if [[ $UNIVERSAL == 1 ]]; then ARCH_FLAGS=(--arch arm64 --arch x86_64); fi
echo "==> Building ($CONFIG$([[ $UNIVERSAL == 1 ]] && echo ", universal"))…"
swift build -c "$CONFIG" "${ARCH_FLAGS[@]}" --product StardewCheckup
BIN="$(swift build -c "$CONFIG" "${ARCH_FLAGS[@]}" --show-bin-path)"

# ---------------------------------------------------------------- bundle
echo "==> Bundling…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/StardewCheckup" "$APP/Contents/MacOS/StardewCheckup"
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET"
swiftc -O Resources/make-icon.swift -o "$BUILD_DIR/make-icon" 2>/dev/null
"$BUILD_DIR/make-icon" "$ICONSET" > /dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# ---------------------------------------------------------------- sign
find_identity() {   # prints the first identity whose name matches $1 and team $2
  security find-identity -v -p codesigning | grep "$1" | grep "($2)" | head -1 | sed -E 's/.*"(.*)".*/\1/'
}
SIGN_FLAGS=(--force --timestamp --options runtime)
case "$SIGN" in
  none)
    IDENTITY="-"
    SIGN_FLAGS=(--force)
    ;;
  dev)
    IDENTITY="$(security find-identity -v -p codesigning | grep 'Apple Development' | head -1 | sed -E 's/.*"(.*)".*/\1/')"
    [[ -n $IDENTITY ]] || { echo "error: no Apple Development certificate in keychain" >&2; exit 1; }
    SIGN_FLAGS=(--force --timestamp=none --options runtime)
    ;;
  devid)
    : "${TEAM_ID:?set TEAM_ID (Apple team id) in the environment or .release.env}"
    IDENTITY="$(find_identity 'Developer ID Application' "$TEAM_ID")"
    if [[ -z $IDENTITY ]]; then
      echo "error: no \"Developer ID Application\" certificate for team $TEAM_ID in the keychain." >&2
      echo "       Create one at https://developer.apple.com/account/resources/certificates and double-click to install." >&2
      exit 1
    fi
    ;;
  *) echo "unknown --sign mode: $SIGN (none|dev|devid)" >&2; exit 1 ;;
esac

xattr -cr "$APP"
echo "==> Signing ($SIGN: $IDENTITY)…"
codesign "${SIGN_FLAGS[@]}" --sign "$IDENTITY" --identifier "$BUNDLE_ID" "$APP"
codesign --verify --strict --verbose=2 "$APP"
touch "$APP"
echo "==> App: $APP"

# ---------------------------------------------------------------- notarize (Developer ID)
if [[ $NOTARIZE == 1 ]]; then
  [[ $SIGN == devid ]] || { echo "error: --notarize requires --sign devid" >&2; exit 1; }
  ZIP="$BUILD_DIR/StardewCheckup-$VERSION.zip"
  echo "==> Notarizing…"
  ditto -c -k --keepParent "$APP" "$ZIP"
  if [[ -n ${ASC_KEY_ID:-} ]]; then
    xcrun notarytool submit "$ZIP" --key "$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8" \
      --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" --wait
  elif [[ -n ${APPLE_ID:-} ]]; then
    xcrun notarytool submit "$ZIP" --apple-id "$APPLE_ID" --team-id "${APPLE_TEAM_ID:-$TEAM_ID}" \
      --password "$APPLE_APP_PASSWORD" --wait
  else
    xcrun notarytool submit "$ZIP" --keychain-profile "${NOTARY_PROFILE:-notarize-profile}" --wait
  fi
  xcrun stapler staple "$APP"
  ditto -c -k --keepParent "$APP" "$ZIP"      # re-zip with the ticket stapled
  spctl --assess --type execute --verbose=2 "$APP"
  echo "==> Notarized: $ZIP"
fi

if [[ $OPEN == 1 ]]; then open "$APP"; fi
