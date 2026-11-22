#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="${EASIER_SCREENSHOTS_BUILD_DIR:-$project_dir/build}"
app="$build_dir/Easier Screenshots.app"

mkdir -p "$build_dir" "$app/Contents/MacOS"
scratch_dir="$(mktemp -d "$build_dir/.compile.XXXXXX")"
trap 'rm -rf "$scratch_dir"' EXIT

sdk="$(xcrun --sdk macosx --show-sdk-path)"
for arch in arm64 x86_64; do
    xcrun --sdk macosx swiftc -O -sdk "$sdk" -target "$arch-apple-macosx14.0" \
        -module-cache-path "$build_dir/ModuleCache" \
        "$project_dir"/Sources/*.swift -o "$scratch_dir/$arch"
done

cp "$project_dir/Info.plist" "$app/Contents/Info.plist"
xcrun lipo -create "$scratch_dir/arm64" "$scratch_dir/x86_64" -output "$app/Contents/MacOS/EasierScreenshots"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
printf 'Built %s\n' "$app"
