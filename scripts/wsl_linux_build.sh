#!/usr/bin/env bash
set -e
export PATH="$HOME/flutter/bin:$PATH"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
flutter config --enable-linux-desktop
flutter build linux --release