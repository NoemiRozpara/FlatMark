#!/usr/bin/env bash
# Capture the running demo for manual smoke inspection, not pixel or viewport qualification.
# Requires a booted iPhone simulator or a logged-in macOS desktop session.
# Filenames use the runtime OS, preset, and actual screenshot pixel dimensions.
#   CAPTURES="light dark" IOS_WIDTHS="320x700 430x932" \
#     bash scripts/capture-recipe-lab.sh ios output-directory
#   MACOS_WIDTHS="600x900 1000x1200" \
#     bash scripts/capture-recipe-lab.sh macos output-directory
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLATFORM="${1:?Usage: bash scripts/capture-recipe-lab.sh ios|macos output-directory}"
OUTPUT="${2:?Provide an output directory}"
case "$PLATFORM" in
  ios|macos) ;;
  *) echo "Use ios or macos" >&2; exit 1 ;;
esac
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
MACOS_WIDTHS="${MACOS_WIDTHS:-480x900 850x1040 1200x900}"
IOS_WIDTHS="${IOS_WIDTHS:-320x700 390x844 430x932 430x1280}"
if [ "$PLATFORM" = macos ]; then
  selected=""
  for capture in ${CAPTURES:-light dark rightToLeft hostMarkers readOnly omission}; do
    if [ "$capture" = generous ]; then
      printf 'Skipping generous: macOS has no enlarged-text preset.\n' >&2
    else
      selected="$selected $capture"
    fi
  done
  CAPTURES="${selected# }"
else
  CAPTURES="${CAPTURES:-light dark generous rightToLeft hostMarkers readOnly omission}"
fi
if [ -z "$CAPTURES" ]; then
  echo "CAPTURES selected no preset." >&2
  exit 1
fi
BUNDLE=dev.flatmark.FlatMarkFixtureHost
# Stage on the output filesystem so publication can use an atomic, no-replace hard link.
WORK="$(mktemp -d "$OUTPUT/.capture-XXXXXX")"
session=""
stop_session() {
  if [ -n "$session" ]; then
    kill "$session" 2>/dev/null || true
    wait "$session" 2>/dev/null || true
    session=""
  fi
}
cleanup() { stop_session; rm -rf "$WORK"; }
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
failures=0
captures=0

# Read dimensions from the captured file, never from a requested window size or device table.
save_capture() { # save_capture <temporary image> <preset> [scroll position]
  local image="$1" preset="$2" scroll="${3:-}" pixels stem out
  if [ ! -s "$image" ]; then
    echo "Capture missing or empty: $preset $scroll" >&2
    failures=$((failures + 1))
    return
  fi
  if ! pixels="$(sips -g pixelWidth -g pixelHeight "$image" 2>/dev/null \
    | awk '/pixelWidth:/{w=$2} /pixelHeight:/{h=$2} END{if(w>0&&h>0) print w"x"h}')"; then
    pixels=""
  fi
  if ! [[ "$pixels" =~ ^[0-9]+x[0-9]+$ ]]; then
    echo "Cannot read capture pixel dimensions: $preset $scroll" >&2
    failures=$((failures + 1))
    return
  fi
  stem="$PLATFORM-$RUNTIME-$preset-$pixels"
  if [ -n "$scroll" ]; then stem="$stem-$scroll"; fi
  if ! out="$(python3 - "$image" "$OUTPUT" "$stem" <<'PY'
import os, pathlib, sys
source, directory, stem = sys.argv[1:]
number = 1
while True:
    suffix = "" if number == 1 else f"-{number}"
    destination = pathlib.Path(directory) / f"{stem}{suffix}.png"
    try:
        os.link(source, destination)
    except FileExistsError:
        number += 1
        continue
    print(destination)
    break
PY
)"; then
    echo "Cannot save capture: $preset $scroll" >&2
    failures=$((failures + 1))
    return
  fi
  rm "$image"
  captures=$((captures + 1))
  printf 'Saved %s\n' "$(basename "$out")"
}

"$ROOT/scripts/run-fixture-host.sh" "$PLATFORM" --capture light
if [ "$PLATFORM" = ios ]; then
  device="$(xcrun simctl list devices booted -j | python3 -c '
import json, sys
for runtime, devices in json.load(sys.stdin)["devices"].items():
    for device in devices:
        if device.get("state") == "Booted" and device.get("isAvailable") and "iPhone" in device["name"]:
            print(device["udid"] + " " + runtime)
            sys.exit(0)
sys.exit("No booted iPhone simulator.")')"
  read -r UDID runtime_id <<< "$device"
  RUNTIME="$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
for runtime in json.load(sys.stdin)["runtimes"]:
    if runtime["identifier"] == sys.argv[1]:
        print(runtime["version"])
        sys.exit(0)
sys.exit("Cannot determine simulator runtime version.")' "$runtime_id")"
else
  RUNTIME="$(sw_vers -productVersion)"
fi
if ! [[ "$RUNTIME" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
  echo "Invalid runtime version: $RUNTIME" >&2
  exit 1
fi

if [ "$PLATFORM" = ios ]; then
  RESIZE_OK=1
  xcrun devicectl device appResize --help >/dev/null 2>&1 || RESIZE_OK=0
  if [ "$RESIZE_OK" -eq 0 ]; then
    echo 'Resizable sessions unavailable; capturing one initial viewport per preset.' >&2
  fi
  for capture in $CAPTURES; do
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BUNDLE" --capture "$capture" >/dev/null
    sleep 2
    if [ "$RESIZE_OK" -eq 0 ]; then
      shot="$WORK/capture.png"
      rm -f "$shot"
      if xcrun simctl io "$UDID" screenshot "$shot"; then
        save_capture "$shot" "$capture"
      else
        echo "Capture failed: $capture" >&2
        failures=$((failures + 1))
      fi
      continue
    fi
    # The app must be foreground before starting a resizable session.
    session_log="$WORK/session.log"
    xcrun devicectl device appResize start --device "$UDID" --preferred-size 390x844 \
      > "$session_log" 2>&1 &
    session=$!
    sleep 12
    resid="$(grep -oE 'Resizable \([A-F0-9-]+\)' "$session_log" \
      | grep -oE '[A-F0-9-]{36}' | head -1 || true)"
    if [ -z "$resid" ]; then
      echo "Resizable session failed: $capture; is the app foreground?" >&2
      failures=$((failures + 1))
      stop_session
      continue
    fi
    for size in $IOS_WIDTHS; do
      if ! xcrun devicectl device appResize set --device "$UDID" --preferred-size "$size" \
        >/dev/null 2>&1; then
        echo "Resize failed: $capture $size" >&2
        failures=$((failures + 1))
      fi
      sleep 3
      shot="$WORK/capture.png"
      rm -f "$shot"
      if xcrun devicectl device capture screenshot --device "$UDID" \
        --display-unique-id "$resid" --destination "$shot" >/dev/null 2>&1; then
        save_capture "$shot" "$capture"
      else
        echo "Capture failed: $capture $size" >&2
        failures=$((failures + 1))
      fi
    done
    stop_session
  done
else
  GEOM_BIN="$WORK/capture-window-geometry"
  swiftc -O "$ROOT/scripts/support/capture-window-geometry.swift" -o "$GEOM_BIN"
  place_and_size() {
    osascript >/dev/null 2>&1 <<APPLESCRIPT
tell application "System Events"
    tell process "FlatMarkDemo" to set frontmost to true
    delay 0.4
    tell process "FlatMarkDemo"
        set position of window 1 to {40, 40}
        delay 0.3
        set size of window 1 to {$1, $2}
        delay 0.6
    end tell
end tell
APPLESCRIPT
  }
  send_keys() {
    osascript >/dev/null 2>&1 <<APPLESCRIPT
tell application "System Events"
    tell process "FlatMarkDemo" to set frontmost to true
    delay 0.3
    repeat $2 times
        key code $1
        delay 0.35
    end repeat
end tell
APPLESCRIPT
  }
  for capture in $CAPTURES; do
    pkill -x FlatMarkDemo 2>/dev/null || true
    sleep 1
    open -n "$ROOT/.build/demo/Build/Products/Debug/FlatMarkDemo.app" --args --capture "$capture"
    sleep 5
    for size in $MACOS_WIDTHS; do
      place_and_size "${size%x*}" "${size#*x}"
      geom="$("$GEOM_BIN" FlatMark || true)"
      if [ -z "$geom" ]; then
        echo "Window not found: $capture $size" >&2
        failures=$((failures + 1))
        continue
      fi
      IFS=$'\t' read -r wid _ <<< "$geom"
      for scroll in top middle end; do
        case "$scroll" in
          top) send_keys 115 1 ;;
          middle) send_keys 121 2 ;;
          end) send_keys 119 1 ;;
        esac
        shot="$WORK/capture.png"
        rm -f "$shot"
        if screencapture -x -o -l"$wid" "$shot" 2>/dev/null; then
          save_capture "$shot" "$capture" "$scroll"
        else
          echo "Window capture failed: $capture $size $scroll" >&2
          failures=$((failures + 1))
        fi
      done
    done
    pkill -x FlatMarkDemo 2>/dev/null || true
  done
fi
printf '%s screenshots saved; %s failures. Inspect images manually; this is not layout qualification.\n' \
  "$captures" "$failures"
if [ "$PLATFORM" = ios ]; then
  echo 'iOS captures initial viewports only; its recipe column remains 240 points wide.'
fi
[ "$failures" -eq 0 ]
