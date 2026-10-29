#!/usr/bin/env bash
# Build and launch the conventional demo app. Remaining arguments are forwarded unchanged.
# Usage: scripts/run-fixture-host.sh ios|macos [--capture preset]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLATFORM="${1:-ios}"
if [ "$#" -gt 0 ]; then shift; fi
# Stable build location also lets capture-recipe-lab.sh relaunch without rebuilding.
DERIVED="$ROOT/.build/demo"
PROJECT="$ROOT/Demo/FlatMarkDemo.xcodeproj"
case "$PLATFORM" in
  ios)
    if ! xcrun simctl list devices booted | grep -q iPhone; then
      echo 'Boot an iPhone simulator in Xcode before launching.' >&2
      exit 1
    fi
    SCHEME=FlatMarkDemo-iOS
    DESTINATION='generic/platform=iOS Simulator'
    APP="$DERIVED/Build/Products/Debug-iphonesimulator/FlatMarkDemo.app"
    ;;
  macos)
    SCHEME=FlatMarkDemo-macOS
    DESTINATION='platform=macOS'
    APP="$DERIVED/Build/Products/Debug/FlatMarkDemo.app"
    ;;
  *) echo "Use ios (default) or macos." >&2; exit 1 ;;
esac
xcodebuild -quiet -project "$PROJECT" -scheme "$SCHEME" \
  -destination "$DESTINATION" -derivedDataPath "$DERIVED" build
if [ "$PLATFORM" = ios ]; then
  xcrun simctl install booted "$APP"
  xcrun simctl terminate booted dev.flatmark.FlatMarkFixtureHost 2>/dev/null || true
  xcrun simctl launch booted dev.flatmark.FlatMarkFixtureHost "$@"
else
  open -n "$APP" --args "$@"
fi
