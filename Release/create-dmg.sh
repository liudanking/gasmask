#!/bin/bash
# Create a simple drag-to-Applications DMG without Finder/AppleScript automation.
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 /path/to/Application.app /path/to/output.dmg" >&2
    exit 1
fi
APP=$1
OUTPUT=$2
if [[ ! -d "$APP" || ! -f "$APP/Contents/Info.plist" ]]; then
    echo "Not an application bundle: $APP" >&2
    exit 1
fi
if [[ "$OUTPUT" != *.dmg ]]; then
    echo "Output must have a .dmg extension." >&2
    exit 1
fi
codesign --verify --deep --strict "$APP"

mkdir -p "$(dirname "$OUTPUT")"
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/gasmask-dmg.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
mkdir "$STAGE/contents"
ditto "$APP" "$STAGE/contents/$(basename "$APP")"
ln -s /Applications "$STAGE/contents/Applications"

# Build and verify a temporary image before replacing a previous successful DMG.
hdiutil create -srcfolder "$STAGE/contents" -volname 'Gas Mask' \
    -fs HFS+ -format UDZO "$STAGE/result.dmg"
hdiutil verify "$STAGE/result.dmg"
mv -f "$STAGE/result.dmg" "$OUTPUT"
echo "Created: $OUTPUT"
