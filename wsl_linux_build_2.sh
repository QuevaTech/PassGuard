#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/flutter/bin:$PATH"
cd /mnt/c/Users/Hasan/projects/PassGuard
flutter --version
flutter config --enable-linux-desktop
flutter build linux --release
