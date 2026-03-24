#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/flutter/bin:$PATH"
cd /mnt/c/Users/Hasan/projects/PassGuard
flutter create --platforms=linux .
flutter build linux --release
