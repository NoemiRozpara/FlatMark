# Device Hub

Device Hub is the Xcode 27 app that replaces `Simulator.app`. It manages both simulated and physical devices. [Apple's Device Hub guide](https://developer.apple.com/documentation/xcode/device-hub) owns the product description. This document owns what an agent must know to drive devices from the command line, and the traps that cause silent wrong answers.

Use it when a task needs a running app observed under a specific size, appearance, accessibility setting, orientation, or location. Do not substitute fixed pixel constants for driving the device. See [Resize the running app](#resize-the-running-app).

## Verified environment

All commands and results below were run on Xcode 27.0 RC (build 27A266a), `devicectl` version 651.31, JSON output version 5, against the iPhone 18 Pro simulator running `dev.flatmark.FlatMarkFixtureHost`. Device Hub was closed for the final confirmation pass. Items marked **unverified** were not exercised.

## The control surface

| Task | Use |
| --- | --- |
| Everything Device Hub does to a running device | `xcrun devicectl` |
| Simulator lifecycle: boot, shutdown, erase, install without a device session | `xcrun simctl` |
| Build, test, project structure | `xcodebuild`, or Xcode MCP. See [MCP options](#mcp-options). |

`devicectl device list` and `xcrun simctl list` differ. `devicectl list devices` returns physical and simulated devices in one table with a `Reality` column. `simctl` only knows simulators. Use `devicectl` when a device may be either.

Prefer `devicectl` over `simctl` for interaction. Prefer `simctl` for lifecycle. Both accept a device UDID; `devicectl` also accepts a device name with `-d`.

## Device Hub is not required

`devicectl` drives a simulator with Device Hub closed. Verified headless, with Device Hub not running: screenshot, screen recording, orientation, `info displays`, status bar simulation, appearance, and a full resizable session with capture. Treat Device Hub as a GUI for a human, not a dependency.

One interaction to know: if Device Hub booted the simulator, quitting Device Hub shuts that simulator down. Booting with `xcrun simctl boot` avoids the coupling. Relaunching Device Hub never boots a simulator for you.

## Preconditions

Check these in order before treating a failure as a bug in the device or in FlatMark.

1. The simulator is booted. A shut-down device rejects every capability command:

   ```sh
   xcrun simctl list devices | grep "<name or UDID>"   # Booted / Shutdown
   xcrun devicectl list devices                         # State column
   ```

   Boot with `xcrun simctl boot <UDID>` and wait for it to settle. A cold boot needs roughly ten seconds before capability calls succeed.

2. For resizing only, an app is already in the foreground. `appResize start` with nothing running fails. Confirm with `appResize observe`, which prints `Foreground app: <bundle id>` or `No foreground app`. Launch with `--activate` (the default) so the app is foregrounded, not merely running. See [Launch and install](#launch-and-install).

| Error | Real cause | Fix |
| --- | --- | --- |
| `CoreDeviceError 1001` — "The capability X is not supported by this device" | Simulator is shut down. It does **not** mean the device lacks the feature. | Boot the simulator, wait, retry. |
| `CoreDeviceError 24001` — "Failed to initialize resizable app session" | No foreground app, so there is nothing to move onto the resizable display. | Launch the app, wait for foreground, then `appResize start`. |
| `CoreDeviceError 21031` on `settings appearance` | An accessibility text size was set without Larger Accessibility Sizes. | Set `--larger-accessibility-sizes on` first, in its own call. |

## Resize the running app

This is how you test a width. Do not hardcode a window size, and do not add launch arguments that pin a layout.

Resizable app sessions were introduced in Xcode 27. `devicectl device appResize` starts a session on a discovered display named `Resizable`, then you change its geometry while the app stays running and mounted.

The order matters. Launch, wait for foreground, then start the session:

```sh
UDID=<simulator UDID>
BUNDLE=dev.flatmark.FlatMarkFixtureHost

devicectl device process launch --device "$UDID" --terminate-existing "$BUNDLE" >/dev/null
sleep 6                                     # let it reach the foreground

devicectl device appResize start --device "$UDID" --preferred-size 390x844 >res.log 2>&1 &
SESSION=$!
sleep 12                                    # wait for the session to become active
# The Resizable display's uniqueId changes every session. Read it, never hardcode it.
RESIZABLE_ID=$(grep -oE "Resizable \([A-F0-9-]+\)" res.log | grep -oE "[A-F0-9-]{36}")
devicectl device appResize set --device "$UDID" --preferred-size 700x1000
sleep 3
devicectl device capture screenshot --device "$UDID" \
  --display-unique-id "$RESIZABLE_ID" --destination shot.png
kill $SESSION                               # ends the session; the app returns to the primary display
```

`start` blocks until interrupted. Run it in the background, or in a second terminal, and drive `set` from elsewhere. `set` requires an active session and fails without one. Killing the session returns the app to the primary display; verified, it captured at the device's native `1206x2622` afterwards.

The FlatMark demo is resizable. Measured during one session, with the app mounted and re-rendering at each size:

| Requested | Rendered (points) | Note |
| --- | --- | --- |
| 320x700 | 375x700 | width clamped up |
| 360x780 | 375x780 | width clamped up |
| 390x844 | 390x844 | exact |
| 430x932 | 430x932 | exact |
| 500x900 | 500x900 | exact |
| 640x960 | 640x960 | exact |
| 700x1000 | 700x1000 | exact |
| 800x1000 | 750x1000 | width clamped down |
| 900x700 | 900x675 | height clamped down |
| 1100x900 | 1100x825 | height clamped down |

Two rules follow.

**`--preferred-size` is a request, not a result.** The system or the app clamps it. `devicectl device info appResize` echoes the value you last requested; on this build its `actualSize` came back `null`. Do not treat that echo as confirmation. Measure what rendered, by reading the captured screenshot's pixel dimensions:

```sh
sips -g pixelWidth -g pixelHeight shot.png
```

Divide by the display scale to recover points. On the iPhone 18 Pro capture, `3300x2475` pixels is `1100x825` points.

**The content really re-layouts.** The captured text bounding box scaled with each requested width (981 px at the narrowest, 3156 px at 1100 pt). A resized capture is a valid responsive-layout check; a letterboxed screenshot is not.

`start` prints the geometry it applied, including the limits. Read them, then keep sweeps inside them:

```text
Started resizable app session.
  Display: Resizable (48B6C6E9-7C46-4538-8B47-9FDBC13C1F5F)
  Requested size: 390.0x844.0
  Actual size: 390.0x844.0
  Minimum possible size: 0.0x0.0
  Maximum possible size: 1280.0x1280.0
```

A request above the maximum is accepted silently and clamped on apply. `observe` streams resizability transitions, which is how you check whether the foreground app supports resizing at all: it prints `Foreground app: <bundle id>` when resizable and `No foreground app` otherwise.

## Capture

```sh
# simulator or physical device, same command
devicectl device capture screenshot --device "$UDID" --destination shot.png
devicectl device capture screen-record --device "$UDID" --duration 4 --destination clip.mp4
```

Flags are `--destination`, not `--output-path`. Screenshot requires a `.png` path; recording requires `.mp4`.

During a resizable session you must name the display, or you capture the wrong thing:

```sh
devicectl device info displays --device "$UDID" --json-output -    # find the Resizable uniqueId
devicectl device capture screenshot --device "$UDID" \
  --display-unique-id "$RESIZABLE_ID" --destination shot.png
```

Omitting it captures the primary `LCD` display, which keeps reporting fixed hardware dimensions no matter what geometry you set. Verified: with the app resized, the primary capture stayed `1206x2622` while the `Resizable` capture tracked every size change. A sweep that forgets `--display-unique-id` produces identical images for every width and looks like a pass.

The `Resizable` display `uniqueId` changes between sessions. Read it from the `start` output or from `info displays` each time; never reuse a saved value.

## Settings and simulation

`devicectl device info <name>` reads back. `devicectl device settings <name>` writes. Confirming a change means calling the matching `info` command or capturing, not trusting a zero exit code.

| Feature | Command |
| --- | --- |
| Light / dark | `device settings appearance --mode dark`, then `device info appearance` |
| Dynamic Type | `device settings appearance --text-size xxxl` |
| Accessibility text sizes | `device settings appearance --larger-accessibility-sizes on` first, then `--text-size accessibility-xxxl` |
| Increase contrast | `device settings appearance --increase-contrast on` |
| Reduce motion / transparency | `device settings appearance --reduce-motion on` / `--reduce-transparency on` |
| Show borders | `device settings appearance --show-borders on` |
| Liquid Glass opacity | `device settings appearance --liquid-glass-opacity 0.0…1.0` |
| VoiceOver | `device settings voiceover --enable` / `--disable`, then `device info voiceover` |
| Orientation | `device orientation set portrait`, `device orientation get` |
| Status bar | `device simulate statusBar preset screenshot`, or `override`, then `show` to read back |
| Location | `device simulate location coordinate` / `scenario` / `route` / `list` / `clear` |
| Face ID / Touch ID | `device simulate biometrics --success` or `--failure` |
| Audio | `device settings audio`, read with `device info audio` |
| StandBy | `device settings standby`, read with `device info standby` |
| Pasteboard | `device pasteboard copy` / `paste` / `info` / `transfer` / `sync-with-host` |
| Darwin notifications | `device notification post` / `observe` |
| Memory pressure | `device process sendMemoryWarning` |
| App lifecycle | `device process launch` / `terminate` / `suspend` / `resume` / `awaitTermination` / `openURL` |
| Install | `device install app` / `device uninstall app` |
| Files | `device copy to` / `from`, `device info files` |

Gotchas, all observed on this build:

- Accessibility text sizes are rejected unless Larger Accessibility Sizes is already on. Setting `--text-size accessibility-extra-extra-extra-large` alone fails with `CoreDeviceError error 21031`. Send `--larger-accessibility-sizes on` in its own call first.
- `device info appearance` reports `lookAndFeel: "Liquid Glass"`, but `--look-and-feel` only accepts `clear` or `tinted`. Readback vocabulary and input vocabulary differ. Do not feed a readback value straight back as a flag.
- `device simulate statusBar override --time 9:41` reads back as `09:41`. Assert on the normalized form.
- `device orientation get` can report `portrait` for the flat orientation and `unknown` for the non-flat one right after a boot. Read both fields rather than parsing one line.
- Restore what you changed. A later run inheriting dark mode or an accessibility text size is a real reporting bug.

## Launch and install

```sh
devicectl device process launch --device "$UDID" \
  --terminate-existing \
  dev.flatmark.FlatMarkFixtureHost -- --capture daylight
```

This works for simulators and physical devices, which `simctl launch` does not. `--terminate-existing` replaces a mounted instance instead of merely foregrounding it. Put launch arguments after the bundle identifier and after a `--`; the first `--` ends `devicectl`'s own options.

Two traps in this signature:

- The flag is `--terminate-existing`. `--terminate-running-process` does not exist. Passing it does not error: anything after the bundle identifier is forwarded to the app as an argument, so a mistyped flag is silently handed to your process instead of being rejected.
- Arguments placed before the bundle identifier are rejected with `Unknown option`. Keep them after it.

Verify the arguments actually landed by capturing two presets and comparing them. Launching `--capture midnight` and `--capture daylight` produced captures differing in 2,189,200 pixels, which confirms the app received the argument. A launch that reports `Launched application with ... bundle identifier.` proves nothing about its arguments.

`--capture` presets are defined in [Demo/README.md](../Demo/README.md); this document does not restate them.

## JSON output

Pass `--json-output -` to write versioned JSON to stdout. Human stdout is not stable; parse the JSON.

```sh
devicectl device info appearance --device "$UDID" --json-output - \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['result'])"
```

The stable envelope is `info.outcome` plus `result`. Check `outcome` for `success`; a zero exit code alone is weak evidence. Add `--omit-deprecated-fields-in-json` to drop the superseded `hardwareProperties` / `deviceProperties` / `connectionProperties` groups in favour of `properties.*`.

## Scripts in this repository

`scripts/capture-recipe-lab.sh` sweeps widths on the running app and writes a `<platform>-widths.tsv` manifest of requested versus measured geometry. It is the reference for driving a device from a script; read it before writing new capture tooling.

Two things it does that matter:

- iOS starts a resizable session per preset, captures the `Resizable` display by `--display-unique-id`, and names each file after the measured size. A clamped request is labelled `clamped`, never `exact`.
- The capture scale is calibrated at run time from the geometry `appResize start` reported applying, so no device scale is hardcoded. `scripts/support/capture-window-geometry.swift` does the same job for macOS windows using the window server's own numbers.

**If macOS widths ever snap to a huge value again, look in the library, not the harness.** An earlier pass at this chased a window that opened roughly 10,000,000 points wide: an accessibility resize moved the height but the width snapped back, confirmed by both System Events and `CGWindowListCopyWindowInfo`, and capturing it failed with `could not create image from rect`. Seeding the window-frame autosave value, clearing the app's preferences, and restarting `cfprefsd` changed nothing, because the cause was never the window frame.

The real cause was `sizeThatFits` in `Sources/FlatMark/Rendering/FlatMarkAppKitParagraphText.swift`. It treated a zero width proposal as "unspecified" and laid out at `.greatestFiniteMagnitude`, so the content reported an enormous ideal width and AppKit sized the window to it. Treating zero as a request for minimum width fixed it, and no width bound in the demo was needed. Check that condition first if widths stop being settable.

The harness does not pin, bound, or seed any window size. It moves the window to a fixed origin before each resize so captures are reproducible and never partly off-screen, then verifies the applied size against the window server and exits non-zero on any width the window did not reach. Previously it hid the whole problem behind a hardcoded `{850, 1040}`.

macOS scrolls with keyboard Home, Page Down, and End, which is what finally separates presets like `hostMarkers` and `omission` from `daylight`. iOS has no scroll control: neither `devicectl` nor `simctl io` injects input, so iOS captures stay at the initial viewport. Pixel equality is weak evidence on macOS; repeating one capture three times at the same geometry and scroll position produced two distinct hashes. See [AI-docs/BUILD_AND_TEST.md](BUILD_AND_TEST.md) for how capture results may be reported.

## MCP options

`devicectl` remains the most capable device-control path. No MCP server found exposes resizable app sessions.

| Option | Device control | Notes |
| --- | --- | --- |
| `xcrun devicectl` (no MCP) | Full, including `appResize` | Verified above. The only path that resizes. |
| Xcode's own MCP: `xcrun mcpbridge`, `xcrun mcp-server` | Build, test, previews, docs, Issue Navigator | Both present on this install. Headless mode needs a one-time `sudo xcrun mcp-server enable`. Check `xcrun mcp-server status`. |
| `pi-xcode-mcp` (Pi package) | None directly; wraps Xcode MCP for `xcode_render_preview`, `xcode_build`, `xcode_test` | Registers `xcrun mcpbridge` through Pi's MCP client. `pi install npm:pi-xcode-mcp`, then `/mcp`. |
| XcodeBuildMCP / MobileBuildMCP | Simulators, UI automation, screenshots, physical devices, LLDB | v2.7.0 added Xcode 27 Device Hub support. No orientation tool and no resize tool; upstream issue #494 tracks the missing orientation command. |
| Axiom `device-control-ref` skill | Documentation, not control | Installable reference covering `devicectl` / `simctl` / Device Hub. Read it rather than re-deriving these facts. |
| `apple-device-hub-mcp`, Device MCP, `mobile-device-mcp`, `xcforge` | Mirroring, tap, swipe, UI tree | Third-party. Not evaluated here. |

For FlatMark work, stay on `devicectl`. Reach for Xcode MCP when the question is about previews, build state, or diagnostics rather than a running device.

## visionOS, tvOS, watchOS, physical devices

Not exercised on this machine. Check before promising them:

- Whether `appResize` works against a physical iPhone, on iPad, or on a foldable simulator is **unverified**. Everything measured above is simulator-only, on iPhone 18 Pro.
- visionOS has its own interaction guide: [Interacting with your visionOS app in Device Hub](https://developer.apple.com/documentation/xcode/interacting-with-your-visionos-app-in-device-hub).
- Physical-device screen interaction stops when a higher-priority camera or microphone app launches. Quit those and click View Screen again. See [Interacting with your app in Device Hub](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub). **Unverified** on this machine.
- CarPlay simulation is built into Device Hub and needs a physical iPhone. **Unverified** on this machine.

## Reporting

When reporting device-driven verification, name the tool and the actual geometry, and separate what was measured from what was assumed:

- Say the rendered size you measured, not the size you requested.
- Say whether the capture came from the primary or the `Resizable` display.
- Say which settings you changed and confirm you restored them.
- Do not call an unscrolled capture a full-document check. `capture-recipe-lab.sh` says so itself.
- Never describe unobserved UI behavior as verified. See [AI-docs/BUILD_AND_TEST.md](BUILD_AND_TEST.md).

## Sources

- [Apple: Device Hub](https://developer.apple.com/documentation/xcode/device-hub)
- [Apple: Interacting with your app in Device Hub](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)
- [Apple: Configuring the environment of a simulated device](https://developer.apple.com/documentation/xcode/configuring-the-environment-of-a-simulated-device)
- [Apple: Capturing screenshots and videos from devices](https://developer.apple.com/documentation/xcode/capturing-screenshots-and-videos-from-devices)
- [Apple: Interacting with devices using the command line](https://developer.apple.com/documentation/xcode/interacting-with-devices-using-the-command-line)
- [Axiom: Device Control Reference](https://charleswiltgen.github.io/Axiom/reference/device-control-ref)
- Apple's docs publish a plain-text variant by appending `.md` to the URL. Fetch that instead of the JavaScript-rendered page.
