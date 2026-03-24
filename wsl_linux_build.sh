#!/usr/bin/env bash
set -e
export PATH="$HOME/flutter/bin:$PATH"
cd /mnt/c/Users/Hasan/projects/PassGuard
flutter config --enable-linux-desktop
flutter build linux --release