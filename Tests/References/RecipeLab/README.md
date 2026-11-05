# Recipe Lab captures

Recipe Lab renders a shared focaccia recipe with mentions, tasks, links, a local illustration,
unsupported-content policies, and retained-document controls. See the
[test guide](../../README.md) for setup and manual checks.

**Captures were regenerated on 2026-11-05** on macOS 27.0.1 (26A434) with Xcode 27.0 (27A266a),
against an iPhone 18 Pro simulator running iOS 27: 91 PNGs plus `macos-widths.tsv`,
`ios-widths.tsv`, and two environment files.

- macOS: 63 captures — 3 widths × 3 scroll positions (`top`, `middle`, `end`) × 7 presets. Scroll is
  driven with Home, Page Down twice, and End.
- iOS: 28 captures — 4 geometries × 7 presets, all initial viewport. The capture script does not
  scroll iOS, so the manifest records `top` for every iOS row.

Every macOS row reached its requested size. iOS clamped 320 to 375, and 430x1280 to 591x1280; the
manifest records what rendered. The 1280-tall geometry is the tallest a resizable session allows and
is what finally separates `omission` from `daylight` on iOS.

**Scrolling is what makes most presets visible.** Against `daylight`, per platform:

| Preset | macOS | iOS |
| --- | --- | --- |
| `midnight` | differs at every geometry | differs at every geometry |
| `rightToLeft` | differs at every geometry | differs except at 375x700 |
| `generous` | differs except at 480x900/top | differs except at 375x700 |
| `hostMarkers`, `omission` | differs once scrolled; identical at 480x900/top | identical at every geometry (`omission` excepted: differs at 430x1280) |
| `readOnly` | no reliable difference | identical at every geometry |

That last preset is not a capture failure:

- `readOnly` only sets `allowsTaskEditing`, which changes behaviour, not pixels. Verifying it needs
  interaction or accessibility evidence, not a screenshot.

Any single-frame pixel difference in these captures is weak evidence. Capturing the same preset at
the same geometry and scroll position three times in a row produced two distinct hashes, so treat
frame equality as inconclusive and confirm anything that matters by eye or with a directed test.

These are review artifacts, not automated pixel baselines.

## Capture

From the repository root, with a booted iPhone simulator or an active desktop session:

```sh
bash scripts/capture-recipe-lab.sh macos Tests/References/RecipeLab
bash scripts/capture-recipe-lab.sh ios Tests/References/RecipeLab
```

Use the [package requirements](../../../README.md#requirements). The script launches a fresh
process per preset and width, waits for the local image, and captures the initial viewport. Lower
content requires separate scrolling and directed checks. Environment files record the OS/toolchain
and simulator. Captures contain platform chrome and clocks; do not treat them as deterministic
pixels.

Each capture is paired with a `<platform>-widths.tsv` manifest recording the requested size, the
size actually measured, the pixel dimensions, the scale and its source, the filename, and whether
the request was honoured. Filenames carry the measured size, not the requested one, so a clamped
request cannot be read as a width that was actually tested. Treat a `rejected` or `clamped` note as
a finding rather than a pass.

iOS drives geometry with `devicectl` resizable app sessions and captures the `Resizable` display.
Device Hub does not need to be running. See [AI-docs/DEVICE_HUB.md](../../AI-docs/DEVICE_HUB.md).
Desktop capture needs Screen Recording and System Events access, and no longer pins a window size.

**macOS width is drivable because FlatMark measures zero-width proposals correctly.** The real fix
is in the library, not the harness: `sizeThatFits` in
`Sources/FlatMark/Rendering/FlatMarkAppKitParagraphText.swift` treats a zero proposal as a request for
minimum width. When it treated zero as "unspecified" it laid out at `.greatestFiniteMagnitude`, the
window opened roughly 10,000,000 points wide, and no external resize could be applied at all. If
widths ever snap to a huge value again, look there first.

Width is applied through System Events, which is still required for macOS. The window is moved to a
fixed origin before each resize so captures are reproducible and never partly off-screen, and the
size that actually applied is read back from the window server rather than assumed.

Presets and widths are overridable per run:

```sh
CAPTURES="daylight generous" IOS_WIDTHS="320x700 430x932" \
  bash scripts/capture-recipe-lab.sh ios Tests/References/RecipeLab
MACOS_WIDTHS="600x900 1200x900" \
  bash scripts/capture-recipe-lab.sh macos Tests/References/RecipeLab
```

To explore a single preset:

```sh
scripts/run-fixture-host.sh macos --capture hostMarkers
scripts/run-fixture-host.sh ios --capture generous
```

## Presets

Defaults: standard text, light appearance, LTR, interactive tasks, default markers, and custom
unsupported-content replacements. iOS uses a 240-point reading column; macOS follows window width.
The local rosemary illustration uses an SF Symbol whose appearance depends on the OS.

| Preset | Variation |
| --- | --- |
| `daylight` | Default |
| `midnight` | Dark appearance |
| `generous` | Enlarged text: iOS `accessibility2`, macOS 28-point body |
| `rightToLeft` | RTL with English content |
| `hostMarkers` | Custom task markers |
| `readOnly` | Static tasks |
| `omission` | Hide HTML |

Generated filenames follow `ios-<preset>-<width>x<height>.png` and
`macos-<preset>-<width>x<height>-<scroll>.png`, where the size is the measured window or scene
geometry in points. A capture whose measured size was not honoured is named after what it really
shows and flagged in the manifest.

## Verification limits

Historical hosts built and ran on macOS 27 and an iPhone 18 Pro simulator running iOS 27.
Package tests passed. Runtime inspection observed task updates, policy-preset changes, and the iOS
reading-column width in an earlier, larger fixture. Those results do not verify the current recipe.

Keep the following checks open:

- Review every macOS width and scroll position for wrapping, clipping, and table reachability. The
  sweep reaches the requested size, but no capture has been visually reviewed yet.

- Capture and visually review every preset for the current content. The previous capture pass was
  not visually reviewed; generating artifacts alone does not verify them.
- Capture lower iOS content in Device Hub. MobileBuildMCP scrolling with Device Hub visible is verified; see
  [the Device Hub guide](../../../AI-docs/DEVICE_HUB.md#scroll-an-ios-app-in-device-hub). Gesture routing
  during a resizable session remains unverified. The existing captures do not reach `hostMarkers`
  or `readOnly` content, and reach `omission` only at the tallest geometry.
- Decide what `readOnly` is for. It changes editability only, so no screenshot can verify it.
- Exercise settings and inline replacement buttons with real input. The previous automation attempt
  reported taps but did not change their state; this established neither working nor broken behavior.
- Inspect lower scroll content, tables, code, mixed-content wrapping, and selection gestures.
  macOS covers top, middle, and end; iOS still needs scrolled captures.
- Reproduce earlier macOS quote truncation and narrow-table clipping. Shorter replacement wording
  is not evidence of a renderer fix; horizontal scrolling and complete cell reachability remain unverified.
- Perform live VoiceOver checks on both platforms: task labels/state/nesting, focus order, toggle
  actions, read-only semantics, and independent links/replacements. Custom marker drawings must not
  become extra focus stops.
- Verify system-level enlarged text on macOS separately from the fixture's explicit font-size preset.

Record the platform, build, preset, actions, and actual outcomes. Native text exports and semantic
trees do not establish visual layout or live accessibility behavior.
