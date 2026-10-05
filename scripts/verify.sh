#!/bin/bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != Darwin ]]; then
  echo "Verification uses Apple's Image I/O and requires macOS 15 or later." >&2
  exit 1
fi
if (( $(sw_vers -productVersion | cut -d. -f1) < 15 )); then
  echo "Verification requires macOS 15 or later." >&2
  exit 1
fi
if [[ "$#" -eq 0 ]]; then
  echo "Usage: ./scripts/verify.sh /path/to/Launch-Solar-HDR.heic [other.heic ...]" >&2
  exit 1
fi
mkdir -p "$REPO_DIR/.build/bin" "$REPO_DIR/.build/module-cache"
xcrun swiftc -O -module-cache-path "$REPO_DIR/.build/module-cache" "$REPO_DIR/src/verify.swift" -o "$REPO_DIR/.build/bin/verify"
"$REPO_DIR/.build/bin/verify" "$@"
