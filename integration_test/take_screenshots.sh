#!/usr/bin/env bash
# Retakes the screenshots with docs/demo-backup.json: desktop ones on Linux,
# phone ones on a running Android emulator (it installs a debug build there).
# Usage: integration_test/take_screenshots.sh [linux|android]...
set -euo pipefail
cd "$(dirname "$0")/.."
demo=$(gzip -9c docs/demo-backup.json | base64 -w0)
devices=("$@")
[ $# -eq 0 ] && devices=(linux android)
for device in "${devices[@]}"; do
  [ "$device" = android ] && device=$(adb get-serialno)
  flutter drive -d "$device" --driver=test_driver/integration_test.dart \
    --target=integration_test/screenshots_test.dart --dart-define=DEMO_BACKUP="$demo"
done
