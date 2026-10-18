#!/bin/bash
# Personal-use build: ad-hoc signed, with the upstream updater disabled.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
bash "$ROOT/build-arm.sh"

PRODUCTS="$ROOT/build/arm64/Build/Products/Release"
[[ -d "$PRODUCTS/Gas Mask.app" ]] || {
    echo "Missing build product: $PRODUCTS/Gas Mask.app" >&2
    exit 1
}
# Personal settings and signing must not alter Xcode's incremental build products.
PACKAGE_DIR=$(mktemp -d "$ROOT/build/personal.XXXXXX")
trap 'rm -rf "$PACKAGE_DIR"' EXIT
APP="$PACKAGE_DIR/Gas Mask.app"
ditto "$PRODUCTS/Gas Mask.app" "$APP"
PLIST="$APP/Contents/Info.plist"

# SPM supplies Sparkle as a binary framework. Ensure it is embedded before signing.
if [[ ! -d "$APP/Contents/Frameworks/Sparkle.framework" ]]; then
    [[ -d "$PRODUCTS/Sparkle.framework" ]] || {
        echo "Sparkle.framework is missing from both the app and build products." >&2
        exit 1
    }
    mkdir -p "$APP/Contents/Frameworks"
    ditto "$PRODUCTS/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
fi

/usr/bin/plutil -replace GasMaskDisableUpdates -bool YES "$PLIST"
/usr/bin/plutil -replace SUEnableAutomaticChecks -bool NO "$PLIST"
/usr/bin/plutil -replace SUAllowsAutomaticUpdates -bool NO "$PLIST"

# The main executable must be ARM-only; embedded frameworks may be universal.
EXECUTABLE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST")
[[ "$(lipo -archs "$APP/Contents/MacOS/$EXECUTABLE")" == arm64 ]] || {
    echo "Expected an arm64-only main executable." >&2
    exit 1
}

# Sign from the inside out, including Sparkle's helpers and XPC services.
# No hardened runtime is enabled for this local ad-hoc build.
while IFS= read -r -d '' item; do
    if [[ -f "$item" ]] && /usr/bin/file -b "$item" | /usr/bin/grep -q 'Mach-O'; then
        lipo -verify_arch arm64 "$item"
        codesign --force --sign - --timestamp=none "$item"
    elif [[ -d "$item" ]]; then
        case "$item" in
            *.app|*.framework|*.xpc|*.bundle)
                codesign --force --sign - --timestamp=none "$item"
                ;;
        esac
    fi
done < <(find "$APP" -depth -print0)
codesign --verify --deep --strict --verbose=2 "$APP"

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")
DMG="$ROOT/build/Gas-Mask-${VERSION}-arm64-personal.dmg"
bash "$ROOT/Release/create-dmg.sh" "$APP" "$DMG"
shasum -a 256 "$DMG" > "$DMG.sha256"
echo "Personal-use DMG: $DMG"
