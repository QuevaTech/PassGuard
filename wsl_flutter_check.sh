#!/usr/bin/env bash
set -e
export PATH="$HOME/flutter/bin:$PATH"
which flutter || true
ls -l "$HOME/flutter/bin/flutter" || true
flutter --version