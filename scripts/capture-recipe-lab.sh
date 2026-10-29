#!/usr/bin/env bash
# Capture the shared playground, not a separate rendering harness.
# Requires a booted iPhone simulator or a logged-in macOS desktop with Screen Recording
# and System Events permissions. References are review-only; no pixel comparison.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLATFORM="${1:?Usage: bash scripts/capture-recipe-lab.sh ios|macos output-directory}"
OUTPUT="${2:?Provide an output directory}"
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
case "$PLATFORM" in
  ios|macos) ;;
  *) echo "Use ios or macos" >&2; exit 1 ;;
esac
"$ROOT/scripts/run-fixture-host.sh" "$PLATFORM" --capture daylight
{
  date -u
  sw_vers
  xcodebuild -version
  swift --version
  if [ "$PLATFORM" = ios ]; then xcrun simctl list devices booted; fi
} > "$OUTPUT/$PLATFORM-environment.txt"
for capture in daylight midnight generous rightToLeft hostMarkers readOnly literal omission; do
  if [ "$PLATFORM" = ios ]; then
    xcrun simctl terminate booted dev.flatmark.FlatMarkFixtureHost || true
    xcrun simctl launch booted dev.flatmark.FlatMarkFixtureHost --capture "$capture"
    sleep 2
    xcrun simctl io booted screenshot "$OUTPUT/ios-$capture.png"
  else
    pkill -x FlatMarkDemo || true
    open -n "$ROOT/.build/demo/Build/Products/Debug/FlatMarkDemo.app" --args --capture "$capture"
    sleep 2
    rect="$(osascript <<'APPLESCRIPT'
tell application "System Events" to tell process "FlatMarkDemo"
    set frontmost to true
    set position of front window to {20, 40}
    set size of front window to {850, 1040}
    set {x, y} to position of front window
    set {w, h} to size of front window
    return (x as text) & "," & (y as text) & "," & (w as text) & "," & (h as text)
end tell
APPLESCRIPT
)"
    sleep 1
    screencapture -x -R "$rect" "$OUTPUT/macos-$capture.png"
  fi
done
printf 'Captured initial viewports only. Scroll to review the rest of each document.\n'
