#!/bin/bash
set -euo pipefail

APP_NAME="ShiftType"
BUNDLE_ID="com.sergey.shifttype"
VERSION="0.2.1"
SIGNING_IDENTITY="${SHIFTTYPE_SIGNING_IDENTITY:--}"
if [ -z "${BUILD_NUMBER:-}" ]; then
    if git rev-parse --verify HEAD >/dev/null 2>&1; then
        BUILD_NUMBER="$(printf "%03d" "$(git rev-list --count HEAD)")"
    else
        BUILD_NUMBER="001"
    fi
fi
APP_DIR="$APP_NAME.app"

swift build -c release --product "$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp ".build/release/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSMultipleInstancesProhibited</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

if [ "$SIGNING_IDENTITY" = "-" ]; then
    echo "WARNING: Signing ad hoc. Privacy permissions will not survive changed builds."
    echo "Set SHIFTTYPE_SIGNING_IDENTITY to a stable code-signing identity to preserve them."
fi

codesign --force --sign "$SIGNING_IDENTITY" "$APP_DIR"

echo "Built $APP_DIR version $VERSION ($BUILD_NUMBER)"
echo ""
echo "To install:"
echo "  cp -R $APP_DIR /Applications/"
echo ""
echo "Then open ShiftType from /Applications."
