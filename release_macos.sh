#!/usr/bin/env bash
# Build, sign (Developer ID), notarize and package Upscaler as a DMG that opens on any Mac.
# Run from the project root: ./release_macos.sh
#
# Reuses the Epic Focus signing and notarization credentials:
# - Signing identity: Developer ID Application: Connor Dodge LLC
# - Notarization: keychain profile "EpicFocus" (xcrun notarytool store-credentials), or
#   NOTARY_APPLE_ID / NOTARY_PASSWORD env vars
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

APP="build/macos/Build/Products/Release/Upscaler.app"
DIST="dist"
ZIP="$DIST/Upscaler.zip"
DMG="$DIST/Upscaler.dmg"
IDENTITY="Developer ID Application: Connor Dodge LLC (VLMSCL48SL)"
TEAM_ID="VLMSCL48SL"
KEYCHAIN_PROFILE="EpicFocus"
ENTITLEMENTS="macos/Runner/Release.entitlements"

echo "=== Building ==="
flutter build macos --release

# Everything executable needs Developer ID + hardened runtime + timestamp for notarization.
# Inside-out: nested code first, the app bundle last.
echo "=== Signing ==="
codesign --force --options runtime --timestamp --sign "$IDENTITY" \
  "$APP/Contents/Resources/realesrgan/realesrgan-ncnn-vulkan"
for fw in "$APP/Contents/Frameworks/"*.framework; do
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$fw"
done
find "$APP" -name "*.dylib" -exec codesign --force --options runtime --timestamp --sign "$IDENTITY" {} \;
codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"

echo "=== Notarizing ==="
mkdir -p "$DIST"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
if [[ -n "${NOTARY_APPLE_ID:-}" && -n "${NOTARY_PASSWORD:-}" ]]; then
  xcrun notarytool submit "$ZIP" --apple-id "$NOTARY_APPLE_ID" \
    --team-id "${NOTARY_TEAM_ID:-$TEAM_ID}" --password "$NOTARY_PASSWORD" --wait
else
  xcrun notarytool submit "$ZIP" --keychain-profile "$KEYCHAIN_PROFILE" --wait
fi
rm -f "$ZIP"

echo "=== Stapling ==="
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose "$APP"

# DMG (not zip) preserves framework symlinks. A drag-to-Applications link makes installing obvious.
echo "=== Creating DMG ==="
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Upscaler.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Upscaler" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

echo ""
echo "Done: $DMG"
ls -lh "$DMG"
