#!/usr/bin/env bash
# Capture the shared playground, not a separate rendering harness.
#
# Requires a booted iPhone simulator, or a logged-in macOS desktop session. References are
# review-only; no pixel comparison. Device Hub does not need to be running; see
# AI-docs/DEVICE_HUB.md.
#
# Width is driven on the running app instead of being baked into one fixed viewport.
#
#   macOS  Window width drives the uncapped recipe column. System Events resizes the window;
#          the window server verifies the applied size. A fixed origin keeps captures on-screen.
#          If resizing fails, check FlatMarkAppKitParagraphText.sizeThatFits: zero-width proposals
#          must not fall through to .greatestFiniteMagnitude.
#   iOS    Uses devicectl resizable app sessions (Xcode 27+) to sweep scene geometry. The recipe
#          pins a 240-point reading column on iOS, so these captures exercise the host container
#          and chrome at each width rather than a reflowed reading column. On Xcode 26 there are
#          no resizable sessions; iOS falls back to one primary-display capture per preset and
#          records that in the manifest.
#
# Presets and widths are overridable per run:
#   CAPTURES="daylight midnight" IOS_WIDTHS="320x700 430x932" \
#     bash scripts/capture-recipe-lab.sh ios output-directory
#   MACOS_WIDTHS="600x900 1000x1200" \
#     bash scripts/capture-recipe-lab.sh macos output-directory
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

# Keep 850 points for comparison with older references; other widths exercise responsive layout.
MACOS_WIDTHS="${MACOS_WIDTHS:-480x900 850x1040 1200x900}"
IOS_WIDTHS="${IOS_WIDTHS:-320x700 390x844 430x932 430x1280}"
SEED_SIZE=390x844     # geometry an iOS session starts at, used to calibrate the capture scale
# `generous` enlarges recipe text through the iOS `accessibility2` Dynamic Type category. AppKit
# chooses its own preferred fonts, so macOS has no enlarged-text preset. Drop it from an override
# instead of recording a daylight duplicate under a name that describes nothing.
if [ "$PLATFORM" = macos ]; then
  selected=""
  for capture in ${CAPTURES:-daylight midnight rightToLeft hostMarkers readOnly omission}; do
    if [ "$capture" = generous ]; then
      printf 'Skipping generous: macOS has no enlarged-text preset.\n' >&2
    else
      selected="$selected $capture"
    fi
  done
  CAPTURES="${selected# }"
else
  CAPTURES="${CAPTURES:-daylight midnight generous rightToLeft hostMarkers readOnly omission}"
fi
if [ -z "$CAPTURES" ]; then
  echo "CAPTURES selected no preset." >&2
  exit 1
fi
BUNDLE=dev.flatmark.FlatMarkFixtureHost
MANIFEST="$OUTPUT/$PLATFORM-widths.tsv"
printf 'platform\tpreset\tscroll\trequested\tpoints\tpixels\tscale\tscaleSource\tfile\tnote\n' \
  > "$MANIFEST"

record() { printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@" >> "$MANIFEST"; }
pixels_of() {
  sips -g pixelWidth -g pixelHeight "$1" 2>/dev/null \
    | awk '/pixelWidth:/{w=$2} /pixelHeight:/{h=$2} END{if(w&&h) print w"x"h; else print "unknown"}'
}

# iOS scale comes from a capture whose rendered points are known, so no device table is hardcoded.
# Prints an integer scale, or unknown when the numbers do not divide cleanly.
seed_scale() {
  python3 - "$1" "$2" <<'PY'
import sys

def parse(value):
    try:
        w, h = value.lower().split("x")
        return float(w), float(h)
    except (ValueError, AttributeError):
        return None

px, pts = parse(sys.argv[1]), parse(sys.argv[2])
if not px or not pts or not all(pts):
    print("unknown")
    sys.exit(0)
ratios = {px[0] / pts[0], px[1] / pts[1]}
if len(ratios) != 1 or min(ratios) < 1:
    print("unknown")
    sys.exit(0)
scale = round(min(ratios))
print(scale if scale and abs(min(ratios) - scale) < 0.02 else "unknown")
PY
}

points_of_px() {
  python3 - "$1" "$2" <<'PY'
import sys

try:
    w, h = sys.argv[1].lower().split("x")
    scale = float(sys.argv[2])
    print(f"{int(round(int(w) / scale))}x{int(round(int(h) / scale))}")
except (ValueError, IndexError, ZeroDivisionError):
    print("unknown")
PY
}

# Names by what rendered, not by what was asked for. Two requests can clamp to the same geometry,
# so keep earlier captures instead of overwriting them.
unique_path() { # unique_path <stem> <suffix>
  local stem="$1" suffix="${2:-}" candidate n=2
  candidate="$OUTPUT/$stem${suffix}.png"
  while [ -e "$candidate" ]; do
    if [ -n "$suffix" ]; then candidate="$OUTPUT/$stem${suffix}-$n.png"
    else candidate="$OUTPUT/$stem-requested-$n.png"; fi
    n=$((n + 1))
  done
  printf '%s' "$candidate"
}

"$ROOT/scripts/run-fixture-host.sh" "$PLATFORM" --capture daylight
{
  date -u
  sw_vers
  xcodebuild -version
  swift --version
  if [ "$PLATFORM" = ios ]; then xcrun simctl list devices booted; fi
  printf 'CAPTURES=%s\nMACOS_WIDTHS=%s\nIOS_WIDTHS=%s\nSEED_SIZE=%s\n' \
    "$CAPTURES" "$MACOS_WIDTHS" "$IOS_WIDTHS" "$SEED_SIZE"
} > "$OUTPUT/$PLATFORM-environment.txt"

if [ "$PLATFORM" = ios ]; then
  UDID="$(xcrun simctl list devices booted -j | python3 -c '
import json, sys
for devices in json.load(sys.stdin)["devices"].values():
    for device in devices:
        if device.get("state") == "Booted" and device.get("isAvailable") \
                and "iPhone" in device["name"]:
            print(device["udid"])
            sys.exit(0)
sys.exit("No booted iPhone simulator.")')"
  RESIZE_OK=1
  # Resizable sessions are Xcode 27+. Detect once rather than failing inside every preset.
  xcrun devicectl device appResize --help >/dev/null 2>&1 || RESIZE_OK=0

  for capture in $CAPTURES; do
    xcrun simctl terminate booted "$BUNDLE" 2>/dev/null || true
    xcrun simctl launch booted "$BUNDLE" --capture "$capture" >/dev/null
    sleep 2

    if [ "$RESIZE_OK" -eq 0 ]; then
      out="$(unique_path "ios-$capture" "-viewport")"
      xcrun simctl io booted screenshot "$out"
      record ios "$capture" top "primary display" unknown "$(pixels_of "$out")" none unavailable \
        "$(basename "$out")" "Xcode 26 has no resizable sessions; single viewport"
      continue
    fi

    # Order matters: the app must already be foreground, or the session fails with
    # CoreDeviceError 24001. See AI-docs/DEVICE_HUB.md.
    session_log="$OUTPUT/.resizable-$capture.log"
    xcrun devicectl device appResize start --device "$UDID" --preferred-size "$SEED_SIZE" \
      > "$session_log" 2>&1 &
    session=$!
    sleep 12
    resid="$(grep -oE 'Resizable \([A-F0-9-]+\)' "$session_log" \
      | grep -oE '[A-F0-9-]{36}' | head -1 || true)"
    if [ -z "$resid" ]; then
      kill "$session" 2>/dev/null || true; wait "$session" 2>/dev/null || true
      out="$(unique_path "ios-$capture" "-viewport")"
      xcrun simctl io booted screenshot "$out"
      record ios "$capture" top unknown unknown "$(pixels_of "$out")" none failed \
        "$(basename "$out")" "resizable session did not start; is the app foreground?"
      continue
    fi

    # The requested size is a preference that the system and the app clamp. Neither `info
    # appResize`, which echoes the request with actualSize null, nor `info displays`, which
    # reports the display's maximum surface, reflects what rendered. Only captured pixels do, so
    # calibrate the scale once against the size `start` reported applying and derive points from it.
    scale=unknown; scale_source=unavailable
    seed_shot="$OUTPUT/.seed-$capture.png"
    if xcrun devicectl device capture screenshot --device "$UDID" \
         --display-unique-id "$resid" --destination "$seed_shot" >/dev/null 2>&1; then
      applied="$(grep -oE 'Actual size: [0-9.]+x[0-9.]+' "$session_log" \
        | tail -1 | grep -oE '[0-9.]+x[0-9.]+')"
      scale="$(seed_scale "$(pixels_of "$seed_shot")" "${applied:-$SEED_SIZE}")"
      if [ "$scale" != unknown ]; then scale_source="calibrated at ${applied:-$SEED_SIZE}"; fi
    fi
    rm -f "$seed_shot"

    for size in $IOS_WIDTHS; do
      xcrun devicectl device appResize set --device "$UDID" --preferred-size "$size" \
        >/dev/null 2>&1 || true
      sleep 3
      tmp="$OUTPUT/.ios-$capture-$size.png"
      if ! xcrun devicectl device capture screenshot --device "$UDID" \
             --display-unique-id "$resid" --destination "$tmp" >/dev/null 2>&1 \
         || [ ! -s "$tmp" ]; then
        record ios "$capture" top "$size" unknown unknown unknown unknown "-" "capture failed"
        rm -f "$tmp"; continue
      fi
      px="$(pixels_of "$tmp")"
      if [ "$scale" != unknown ]; then
        pts="$(points_of_px "$px" "$scale")"
        if [ "$pts" = "$size" ]; then note=exact; else note=clamped; fi
      else
        pts=unknown; note="points unknown"
      fi
      if [ "$pts" = unknown ]; then out="$(unique_path "ios-$capture-px-$px" "")"
      else out="$(unique_path "ios-$capture-$pts" "")"; fi
      mv "$tmp" "$out"
      if [ "$note" = clamped ]; then
        printf '  %s: requested %s, rendered %s\n' "$capture" "$size" "$pts" >&2
      fi
      record ios "$capture" top "$size" "$pts" "$px" "$scale" "$scale_source" \
        "$(basename "$out")" "$note"
    done
    kill "$session" 2>/dev/null || true; wait "$session" 2>/dev/null || true
    rm -f "$session_log"
  done
  printf 'iOS captures come from the Resizable display. The recipe pins a 240-point reading\n'
  printf 'column on iOS, so text width does not reflow; these show container and chrome.\n'
else
  # Compile once; the helper reports the window server's truth, which is the only readback that
  # survives AppKit overriding the width. Build outside the output directory, which is a tracked
  # reference folder when captures are written to Tests/References/RecipeLab.
  GEOM_DIR="$(mktemp -d)"
  GEOM_BIN="$GEOM_DIR/capture-window-geometry"
  trap 'rm -rf "$GEOM_DIR"' EXIT
  swiftc -O "$ROOT/scripts/support/capture-window-geometry.swift" -o "$GEOM_BIN"

  rejected=0
  # Anchor the window at a fixed origin so every capture of a preset starts from the same place and
  # is never partly off-screen. The resize itself is verified against the window server afterwards.
  place_and_size() { # place_and_size <width> <height>
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

  send_keys() { # send_keys <keycode> <repeat>
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
      want_w="${size%x*}"; want_h="${size#*x}"
      place_and_size "$want_w" "$want_h"
      geom="$("$GEOM_BIN" FlatMark || true)"
      if [ -z "$geom" ]; then
        # The window can still be settling after launch; give the resize one more chance.
        place_and_size "$want_w" "$want_h"
        geom="$("$GEOM_BIN" FlatMark || true)"
      fi
      if [ -z "$geom" ]; then
        record macos "$capture" none "$size" unknown unknown unknown unknown "-" "window not found"
        rejected=$((rejected + 1))
        continue
      fi
      IFS=$'\t' read -r wid pw ph scale cgw cgh <<< "$geom"
      # Read back the applied width. An overridden width is not exact responsive-layout evidence.
      if [ "$pw" = "$want_w" ] && [ "$ph" = "$want_h" ]; then
        note=exact
      else
        note="rejected: window became ${pw}x${ph}"
        rejected=$((rejected + 1))
      fi
      # Capture Home, two pages down, and End to include tasks, markers, and HTML-policy content.
      for scroll in top middle end; do
        case "$scroll" in
          top) send_keys 115 1 ;;     # Home
          middle) send_keys 121 2 ;;  # Page Down twice
          end) send_keys 119 1 ;;     # End
        esac
        out="$(unique_path "macos-$capture-${pw}x${ph}-$scroll" "")"
        if ! screencapture -x -o -l"$wid" "$out" 2>/dev/null || [ ! -s "$out" ]; then
          rm -f "$out"
          record macos "$capture" "$scroll" "$size" "${pw}x${ph}" unknown "$scale" window-server \
            "-" "window capture failed"
          rejected=$((rejected + 1))
          continue
        fi
        px_dim="$(pixels_of "$out")"
        printf '  %s %s %s: window is %sx%s points\n' "$capture" "$size" "$scroll" "$pw" "$ph" >&2
        record macos "$capture" "$scroll" "$size" "${pw}x${ph}" "$px_dim" "$scale" window-server \
          "$(basename "$out")" "$note"
      done
    done
    pkill -x FlatMarkDemo 2>/dev/null || true
  done
  printf 'macOS window width drives the recipe layout; each preset was swept per width.\n'
  if [ "$rejected" -gt 0 ]; then
    # Do not exit 0 with a manifest that contains widths the window never had.
    printf '%s of %s macOS captures did not reach the requested size.\n' \
      "$rejected" "$(( $(wc -l < "$MANIFEST") - 1 ))" >&2
    printf 'Check that nothing else is stealing focus and that the display can hold the requested\n' >&2
    printf 'height. If widths snap to a huge value, FlatMark is measuring a zero-width proposal as\n' >&2
    printf 'unbounded again: see sizeThatFits in Sources/FlatMark/Rendering/FlatMarkAppKitParagraphText.swift.\n' >&2
    printf 'See AI-docs/DEVICE_HUB.md.\n' >&2
    exit 1
  fi
fi

if [ "$PLATFORM" = macos ]; then
  printf 'macOS captured top, middle, and end. This script does not scroll iOS; its captures are\n'
  printf 'initial viewports only. For scrolling in Device Hub, see AI-docs/DEVICE_HUB.md.\n'
fi
echo "Manifest: $MANIFEST"
column -t -s "$(printf '\t')" "$MANIFEST"
