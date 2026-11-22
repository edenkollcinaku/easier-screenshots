#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
scratch_dir="$(mktemp -d)"
trap 'rm -rf "$scratch_dir"' EXIT

xcrun --sdk macosx swiftc -O -module-cache-path "$scratch_dir/ModuleCache" \
    "$project_dir/Sources/ScreenshotWatcher.swift" \
    "$project_dir/Tests/ScreenshotWatcherSmokeTest.swift" \
    -o "$scratch_dir/test"
"$scratch_dir/test"
