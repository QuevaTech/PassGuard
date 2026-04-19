#!/bin/bash
set -e

APP_NAME="PassGuard Vault"
DMG_NAME="PassGuard Vault"
RELEASE_DIR="releases/macos"
BUILD_DIR="build/macos/Build/Products/Release"

echo "==> Checking dependencies..."
if ! command -v create-dmg &>/dev/null; then
  echo "create-dmg not found. Installing via Homebrew..."
  brew install create-dmg
fi

echo "==> Building release..."
flutter build macos --release

echo "==> Copying .app to releases/..."
mkdir -p "$RELEASE_DIR"
rm -rf "$RELEASE_DIR/$APP_NAME.app"
cp -R "$BUILD_DIR/$APP_NAME.app" "$RELEASE_DIR/"

echo "==> Creating DMG..."
rm -f "$RELEASE_DIR/$DMG_NAME.dmg"

create-dmg \
  --volname "$APP_NAME" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "$APP_NAME.app" 150 185 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 450 185 \
  --no-internet-enable \
  "$RELEASE_DIR/$DMG_NAME.dmg" \
  "$RELEASE_DIR/$APP_NAME.app"

SIZE=$(du -sh "$RELEASE_DIR/$DMG_NAME.dmg" | cut -f1)
echo ""
echo "==> Done: $RELEASE_DIR/$DMG_NAME.dmg ($SIZE)"
