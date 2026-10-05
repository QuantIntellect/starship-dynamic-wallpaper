#!/bin/bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != Darwin || "$(uname -m)" != arm64 ]]; then
  echo "Building requires an Apple silicon Mac. Download the ready-made HEIC files from Releases instead." >&2
  exit 1
fi
if (( $(sw_vers -productVersion | cut -d. -f1) < 15 )); then
  echo "Building requires macOS 15 or later." >&2
  exit 1
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Install Xcode Command Line Tools to build, or use the ready-made release downloads." >&2
  exit 1
fi
BUILD_DIR="$REPO_DIR/.build"
RUN_DIR="$BUILD_DIR/render"
mkdir -p "$BUILD_DIR/bin" "$BUILD_DIR/module-cache" "$RUN_DIR/work" "$RUN_DIR/outputs" "$REPO_DIR/dist"
cp "$REPO_DIR/assets/launch-original.jpg" "$RUN_DIR/work/source.jpg"
for stage in build_day_cycle build_hdr build_solar verify; do
  xcrun swiftc -O -target arm64-apple-macos15.0 -module-cache-path "$BUILD_DIR/module-cache" \
    "$REPO_DIR/src/$stage.swift" -o "$BUILD_DIR/bin/$stage"
done
cd "$RUN_DIR"
"$BUILD_DIR/bin/build_day_cycle"
"$BUILD_DIR/bin/build_hdr"
"$BUILD_DIR/bin/build_solar"
"$BUILD_DIR/bin/verify" outputs/Launch-Solar-HDR.heic outputs/Launch-Day-Cycle-HDR.heic
cp outputs/Launch-Solar-HDR.heic outputs/Launch-Day-Cycle-HDR.heic "$REPO_DIR/dist/"
cd "$REPO_DIR/dist"
shasum -a 256 Launch-Solar-HDR.heic Launch-Day-Cycle-HDR.heic > SHA256SUMS.txt
printf '\nBuilt and verified both wallpapers in %s/dist\n' "$REPO_DIR"
