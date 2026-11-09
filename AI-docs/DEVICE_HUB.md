# Device Hub

Use Xcode 27+ `devicectl` to change a running device's size, appearance, orientation, or accessibility
settings. Do not substitute fixed layout constants or launch arguments for device state.
[Apple's Device Hub guide](https://developer.apple.com/documentation/xcode/device-hub) describes the app.

## Scope and targeting

These procedures were exercised with Xcode 27.0 (27A266a), `devicectl` 651.31, and an iPhone 18 Pro
simulator. This is not evidence for physical devices, iPad, or other simulator models. Command help was
rechecked with that toolchain; check your installed CLI before relying on newer capabilities.

- Discover devices with `xcrun devicectl list devices`; it includes physical and simulated devices.
  `xcrun simctl list devices` lists simulators only. Set `UDID` to the intended device's identifier;
  use it explicitly on every device command rather than relying on a name or default.
- Use `simctl` for simulator lifecycle, and `devicectl` for running-device state and resizable sessions.
  Device Hub need not be open. Boot simulators independently if they must survive closing Device Hub.
- Read the installed MobileBuildMCP skill before using that tool. Discover schemes, devices, and UI
  references rather than copying saved identifiers. See [BUILD_AND_TEST.md](BUILD_AND_TEST.md).
- Record settings before changing them, confirm changes by readback or observation, and restore them
  afterward. Do not erase a simulator or modify an unrelated device as a troubleshooting shortcut.

## Boot and launch

```sh
UDID='<discovered simulator UDID>'
BUNDLE=dev.flatmark.FlatMarkFixtureHost
xcrun simctl boot "$UDID"                 # only if shut down
xcrun simctl bootstatus "$UDID" -b
xcrun devicectl device process launch --device "$UDID" \
  --terminate-existing "$BUNDLE" -- --capture daylight
```

`--terminate-existing` replaces a running instance. Put tool flags before the bundle identifier and app
arguments after `--`. Confirm preset behavior in the app; a successful launch does not prove arguments
had the intended effect. Presets belong to [Demo/README.md](../Demo/README.md).

Before resizing, confirm the app is foregrounded with
`xcrun devicectl device appResize observe --device "$UDID"` (interrupt after observation).

Previously observed errors are clues, not unique diagnoses:

| Error | Check first |
| --- | --- |
| `CoreDeviceError 1001`, capability unsupported | Is the simulator booted and ready? |
| `CoreDeviceError 24001`, resize session initialization failed | Is an app foregrounded? |
| `CoreDeviceError 21031`, appearance change failed | Enable Larger Accessibility Sizes before requesting an accessibility text size. |

## Resize and capture

Prefer [scripts/capture-recipe-lab.sh](../scripts/capture-recipe-lab.sh) for repeatable sweeps. For manual
inspection, start a session in one terminal:

```sh
xcrun devicectl device appResize start --device "$UDID" --preferred-size 390x844
```

`start` blocks until interrupted. Wait for the active session, read its minimum and maximum geometry,
and copy the discovered `Resizable` display's unique ID. It changes each session. In another terminal,
set the same `UDID` and run:

```sh
xcrun devicectl device info displays --device "$UDID"
RESIZABLE_ID='<current Resizable display unique ID>'
xcrun devicectl device appResize set --device "$UDID" --preferred-size 700x1000
xcrun devicectl device capture screenshot --device "$UDID" \
  --display-unique-id "$RESIZABLE_ID" --destination shot.png
sips -g pixelWidth -g pixelHeight shot.png
```

Interrupt `start` when finished; ending the session returns the app to the primary display.

**Requested size is not rendered size.** The system or app can clamp requests, including requests above
the reported maximum. `device info appResize` previously echoed the request with `actualSize: null`;
that is not confirmation. Measure screenshot pixels and divide by a verified display scale. The sweep
script calibrates scale from the geometry reported as applied at session start; inspect its manifest
rather than assuming a hardware scale.

**Capture the correct display.** Omitting `--display-unique-id` during a resize session captures the
primary display, not necessarily the resized app. Identical captures across widths can hide this error.
Inspect the content as well as the measured dimensions to rule out letterboxing.

Outside a resizable session:

```sh
xcrun devicectl device capture screenshot --device "$UDID" --destination shot.png
xcrun devicectl device capture screen-record --device "$UDID" --duration 4 --destination clip.mp4
```

Use `--destination` with `.png` for screenshots and `.mp4` for recordings.

## Settings

Examples below target the selected device. Read current values first, then verify and restore them.

```sh
xcrun devicectl device info appearance --device "$UDID"
xcrun devicectl device settings appearance --device "$UDID" --mode dark
xcrun devicectl device settings appearance --device "$UDID" --text-size xxxl
# Enable this separately before choosing an accessibility size.
xcrun devicectl device settings appearance --device "$UDID" --larger-accessibility-sizes on
xcrun devicectl device settings appearance --device "$UDID" --text-size accessibility-extra-extra-extra-large
xcrun devicectl device info appearance --device "$UDID"
xcrun devicectl device orientation set --device "$UDID" portrait
xcrun devicectl device orientation get --device "$UDID"
```

Discover additional flags with `device settings appearance --help`, including contrast, reduced motion,
and reduced transparency. Input and readback vocabularies can differ: `--look-and-feel` accepts `clear`
or `tinted`, not the reported `Liquid Glass` label. Read both orientation fields; a post-boot value can
be `unknown`.

Other command groups include `device settings voiceover`, `device simulate statusBar`, and
`device simulate location`. Consult their help for arguments and restoration commands. Enabling
VoiceOver does not verify the app's accessibility behavior.

For machine-readable results, use `--json-output -` and check `info.outcome` as well as `result`.
`--omit-deprecated-fields-in-json` removes superseded fields. Do not parse human stdout as a stable API.

```sh
xcrun devicectl device info appearance --device "$UDID" --json-output - \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["info"]["outcome"] == "success", d; print(d["result"])'
```

## Capture sweeps and scrolling

Read [scripts/capture-recipe-lab.sh](../scripts/capture-recipe-lab.sh) before adding capture tooling. Its
`<platform>-widths.tsv` records requested and measured geometry, scale provenance, and capture status.
Treat `clamped`, `rejected`, unknown geometry, and over-cap widths as findings, not passes.

The macOS path uses [capture-window-geometry.swift](../scripts/support/capture-window-geometry.swift)
to measure window-server geometry. It moves windows on-screen, verifies resize results, and exits
nonzero for rejected widths. It captures top, middle, and end using keyboard scrolling. The iOS path
captures only the initial viewport. Pixel equality or inequality alone is not a layout assertion.

Neither `devicectl` nor `simctl io` provides scroll injection. Use MobileBuildMCP with a current UI
snapshot and the selected simulator:

```sh
mobilebuildmcp simulator list
mobilebuildmcp ui-automation snapshot-ui --simulator-id "$UDID"
# Replace e7 with the scroll reference from this snapshot.
mobilebuildmcp ui-automation swipe --simulator-id "$UDID" \
  --within-element-ref e7 --direction up --distance 0.7
mobilebuildmcp ui-automation snapshot-ui --simulator-id "$UDID"
mobilebuildmcp ui-automation screenshot --simulator-id "$UDID"
```

A swipe up reveals later content. Refresh references after scrolling and bound retries. Inspect actual
movement: command success is not proof, and snapshot-settling timeouts have occurred despite movement.
Scrolling during an active `appResize` session, targeting its `Resizable` display, and physical-device
scrolling remain unverified.

## Evidence and reporting

Report the platform, toolchain, actions, measured geometry, display captured, changed settings, and
whether restoration succeeded. Do not call an initial-viewport capture a full-document check.
Screenshots require visual inspection and cannot establish live VoiceOver, selection, or keyboard
behavior. Historical observations do not verify changed code. Follow
[BUILD_AND_TEST.md](BUILD_AND_TEST.md) for verification and reporting limits.
