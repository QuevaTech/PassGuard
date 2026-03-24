#!/usr/bin/env bash
set -euo pipefail

cd /mnt/c/Users/Hasan/projects/PassGuard

APP_NAME="passguard_vault_v0"
VERSION="1.0.0"
BUNDLE="build/linux/x64/release/bundle"
APPDIR="build/linux/AppDir"
OUTDIR="build/linux/appimage"

if [ ! -f "$BUNDLE/$APP_NAME" ]; then
  echo "Linux bundle binary not found: $BUNDLE/$APP_NAME"
  exit 1
fi

rm -rf "$APPDIR" "$OUTDIR"
mkdir -p "$APPDIR/usr/bin" \
         "$APPDIR/usr/lib" \
         "$APPDIR/usr/share/applications" \
         "$APPDIR/usr/share/icons/hicolor/256x256/apps" \
         "$OUTDIR"

cp "$BUNDLE/$APP_NAME" "$APPDIR/usr/bin/"
cp -r "$BUNDLE/lib/." "$APPDIR/usr/lib/"
cp -r "$BUNDLE/data" "$APPDIR/usr/"
cp "assets/icons/app_icon.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/$APP_NAME.png"

cat > "$APPDIR/$APP_NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=PassGuard Vault
Exec=$APP_NAME
Icon=$APP_NAME
Categories=Utility;Security;
Terminal=false
EOF

cp "$APPDIR/$APP_NAME.desktop" "$APPDIR/usr/share/applications/$APP_NAME.desktop"

cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/lib:${LD_LIBRARY_PATH:-}"
exec "$HERE/usr/bin/passguard_vault_v0" "$@"
EOF

chmod +x "$APPDIR/AppRun" "$APPDIR/usr/bin/$APP_NAME"
ln -sf "usr/share/icons/hicolor/256x256/apps/$APP_NAME.png" "$APPDIR/$APP_NAME.png"
ln -sf "$APP_NAME.png" "$APPDIR/.DirIcon"

TOOLS_DIR="$HOME/.local/appimage-tools"
mkdir -p "$TOOLS_DIR"
APPIMAGETOOL="$TOOLS_DIR/appimagetool.AppImage"
if [ ! -f "$APPIMAGETOOL" ]; then
  wget -q -O "$APPIMAGETOOL" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
  chmod +x "$APPIMAGETOOL"
fi

OUTPUT="$OUTDIR/PassGuardVault-${VERSION}-x86_64.AppImage"
ARCH=x86_64 APPIMAGETOOL_APPIMAGE_EXTRACT_AND_RUN=1 "$APPIMAGETOOL" "$APPDIR" "$OUTPUT"

ls -lh "$OUTPUT"
