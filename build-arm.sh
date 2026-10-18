#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)

# Use a standard Xcode installation without changing the global xcode-select setting.
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
if ! xcodebuild -version >/dev/null 2>&1; then
    echo "Full Xcode is required. Install it, open it once to finish setup, then retry." >&2
    echo "For a nonstandard installation, set DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer." >&2
    exit 1
fi

xcodebuild -project "$ROOT/Gas Mask.xcodeproj" -scheme "Gas Mask" \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$ROOT/build/arm64" \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    build
