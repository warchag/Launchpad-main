#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "==> Building Release Binary..."
if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release
else
    swift build -c release
fi

APP_NAME="Launchpad.app"
APP_DIR="$DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Creating $APP_NAME bundle structure..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "==> Copying binary..."
cp -f "$DIR/.build/release/Launchpad" "$MACOS_DIR/Launchpad"
chmod +x "$MACOS_DIR/Launchpad"

echo "==> Copying resources (AppIcon, StatusBarIcon)..."
if [ -d "$DIR/Resources" ]; then
    cp -rf "$DIR/Resources/"* "$RESOURCES_DIR/"
fi

echo "==> Writing Info.plist..."
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Launchpad</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.worracag.Launchpad</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Launchpad</string>
    <key>CFBundleDisplayName</key>
    <string>Launchpad</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
</dict>
</plist>
EOF

echo "==> Signing application bundle..."
codesign --force --deep --sign - "$APP_DIR"

echo "==> Creating Launchpad.zip archive for distribution..."
rm -f "$DIR/Launchpad.zip"
ditto -c -k --keepParent "$APP_DIR" "$DIR/Launchpad.zip"

echo "==> Successfully created $APP_NAME and Launchpad.zip at $DIR"
