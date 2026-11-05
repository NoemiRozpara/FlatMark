# Recipe Lab captures

Recipe Lab renders a shared focaccia recipe with mentions, tasks, links, a local illustration,
unsupported-content policies, and retained-document controls. See the
[test guide](../../README.md) for setup and manual checks.

**Captures were regenerated on 2026-11-05** on macOS 27.0.1 (26A434) with Xcode 27.0 (27A266a),
against an iPhone 18 Pro simulator running iOS 27: 24 macOS and 24 iOS PNGs, plus
`macos-widths.tsv`, `ios-widths.tsv`, and two environment files. Every macOS row reached its
requested size; iOS rows at 320 points clamped to 375, which the manifest records. These are review
artifacts, not automated pixel baselines.

**They do not distinguish every preset.** Hashing the 48 files found 6 groups of byte-identical
captures, all of them presets whose content sits below the initial viewport:

| Preset | Indistinguishable from `daylight` at |
| --- | --- |
| `hostMarkers`, `readOnly`, `literal` | every iOS and every macOS width |
| `omission` | every iOS width; macOS 480x900 and 1200x900 |
| `generous`, `rightToLeft` | iOS 375x700 only |

`midnight` differs everywhere, as expected. Treat the four always-identical presets as unverified by
these captures: the initial viewport never reaches the tasks, markers, or HTML-policy content those
presets change. Scrolling is required, not optional, for them.

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

**macOS width is drivable, but only with the demo's root bound.** An unbounded root `ScrollView`
proposes an unbounded ideal width, AppKit recomputes the window from it, and no external width change
is applied at all: an accessibility resize snapped the width to roughly 10,000,000 points while
height resized normally. `Demo/FlatMarkDemo/FlatMarkDemoApp.swift` fixes this with a fixed
`maxWidth` on the root plus `.windowResizability(.contentMinSize)`. Keep both: without the bound no
width applies, and without `.contentMinSize` the window stays pinned to the content's ideal size.

The fixed maximum also caps how wide the layout grows. A window wider than `maximumWindowWidth` keeps
growing while the recipe stops widening, so the window size would overstate what the layout was
offered; the script flags those captures. Raise the sweep and `maximumWindowWidth` together.

Width is applied through System Events, which is still required for macOS, and the window is moved to
a fixed origin before each resize because macOS clamps a resize against the area the window already
occupies. The size that actually applied is read back from the window server.

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
| `literal` | Show HTML |
| `omission` | Hide HTML |

Generated filenames follow `ios-<preset>-<width>x<height>.png` and
`macos-<preset>-<width>x<height>.png`, where the size is the measured window or scene geometry in
points. A capture whose measured size was not honoured is named after what it really shows and
flagged in the manifest.

## Verification limits

Historical hosts built and ran on macOS 27 and an iPhone 18 Pro simulator running iOS 27.
Package tests passed. Runtime inspection observed task updates, policy-preset changes, and the iOS
reading-column width in an earlier, larger fixture. Those results do not verify the current recipe.

Keep the following checks open:

- Review every macOS width in the current sweep for wrapping, clipping, and table reachability. The
  sweep reaches the requested size, but no capture has been visually reviewed yet.

- Capture and visually review every preset for the current content. The previous capture pass was
  not visually reviewed; generating artifacts alone does not verify them. The four presets in the
  table above additionally need scrolled captures, because their initial viewport is pixel-identical
  to `daylight`.
- Exercise settings and inline replacement buttons with real input. The previous automation attempt
  reported taps but did not change their state; this established neither working nor broken behavior.
- Inspect lower scroll content, tables, code, mixed-content wrapping, and selection gestures.
  For `hostMarkers`, `readOnly`, `literal`, and `omission` this is the only check that reaches their
  distinguishing content.
- Reproduce earlier macOS quote truncation and narrow-table clipping. Shorter replacement wording
  is not evidence of a renderer fix; horizontal scrolling and complete cell reachability remain unverified.
- Perform live VoiceOver checks on both platforms: task labels/state/nesting, focus order, toggle
  actions, read-only semantics, and independent links/replacements. Custom marker drawings must not
  become extra focus stops.
- Verify system-level enlarged text on macOS separately from the fixture's explicit font-size preset.

Record the platform, build, preset, actions, and actual outcomes. Native text exports and semantic
trees do not establish visual layout or live accessibility behavior.
