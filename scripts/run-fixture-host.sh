#!/usr/bin/env bash

# Builds FlatMarkFixtureHost, wraps the executable into a minimal .app, and launches it. The host
# presents the same fixture files the automated suite exercises, with no host-app code involved.
#
# Usage: scripts/run-fixture-host.sh [platform]   (platform: ios | macos, default ios)
#   ios   builds for the iOS Simulator and installs/launches on the booted iPhone simulator.
#   macos builds for macOS, bundles, and opens the app; requires a booted desktop (no simulator).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUNDLE_ID="dev.flatmark.FlatMarkFixtureHost"

PLATFORM="${1:-ios}"
if [ "$#" -gt 0 ]; then shift; fi
# Remaining arguments are forwarded unchanged, e.g. --capture generous.
case "$PLATFORM" in
  ios) ;;
  macos) BUNDLE_ID="dev.flatmark.FlatMarkFixtureHost.macos" ;;
  *) echo "Unknown platform '$PLATFORM'. Use 'ios' (default) or 'macos'." >&2; exit 1 ;;
esac

if [ "$PLATFORM" = ios ] && ! xcrun simctl list devices booted | grep -q iPhone; then
  echo "No iPhone simulator is booted. Boot one (Xcode > Window > Devices and Simulators," \
    "or: xcrun simctl boot 'iPhone 16 Pro') and rerun. For the desktop, pass 'macos'." >&2
  exit 1
fi

DERIVED="$(mktemp -d)"
trap 'rm -rf "$DERIVED"' EXIT

if [ "$PLATFORM" = ios ]; then
  echo "Building FlatMarkFixtureHost for the iOS Simulator…"
  cd "$PACKAGE_DIR"
  xcodebuild -quiet \
    -scheme FlatMarkFixtureHost \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED" \
    -disableAutomaticPackageResolution \
    -skipPackageUpdates \
    build
  BIN="$DERIVED/Build/Products/Debug-iphonesimulator/FlatMarkFixtureHost"
else
  echo "Building FlatMarkFixtureHost for macOS…"
  cd "$PACKAGE_DIR"
  swift build --skip-update --target FlatMarkFixtureHost
  BIN="$(swift build --skip-update --show-bin-path)/FlatMarkFixtureHost"
fi

[ -x "$BIN" ] || { echo "Expected binary not found at $BIN" >&2; exit 1; }

APP="$DERIVED/FlatMarkFixtureHost.app"
if [ "$PLATFORM" = macos ]; then
  # `open` launches asynchronously; keep the bundle at a stable path until the app exits.
  APP="/tmp/FlatMarkFixtureHost-macos.app"
  rm -rf "$APP"
fi
mkdir -p "$APP"
cp "$BIN" "$APP/FlatMarkFixtureHost"
# Bundle.module resolves resources relative to the packaged app, not the original executable.
# Keep the SwiftPM resource bundle when relocating the host (on both platforms).
RESOURCE_BUNDLE="$(dirname "$BIN")/FlatMark_FlatMarkFixtures.bundle"
[ -d "$RESOURCE_BUNDLE" ] || { echo "Expected resource bundle not found at $RESOURCE_BUNDLE" >&2; exit 1; }
cp -R "$RESOURCE_BUNDLE" "$APP/"
if [ "$PLATFORM" = ios ]; then
  EXTRA_PLIST=$'\t<key>LSRequiresIPhoneOS</key>\n\t<true/>\n\t<key>UILaunchScreen</key>\n\t<dict/>'
else
  EXTRA_PLIST=$'\t<key>CFBundleIconFile</key>\n\t<string></string>'
fi
cat > "$APP/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>FlatMarkFixtureHost</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>FlatMarkFixtureHost</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
$EXTRA_PLIST
</dict>
</plist>
EOF
codesign --force --sign - "$APP/FlatMarkFixtureHost"

if [ "$PLATFORM" = ios ]; then
  echo "Installing and launching on the booted simulator…"
  xcrun simctl install booted "$APP"
  xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch booted "$BUNDLE_ID" "$@"
  echo "Running. Screenshot with: xcrun simctl io booted screenshot /tmp/fixture-host.png"
  echo "Terminate with: xcrun simctl terminate booted $BUNDLE_ID"
else
  echo "Launching on macOS…"
  open -n "$APP" --args "$@"
  echo "Running in a window. Quit with: pkill -f FlatMarkFixtureHost-macos.app"
fi
