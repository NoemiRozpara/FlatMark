# Recipe Lab captures

See the [test guide](../../README.md#recipe-lab) for Recipe Lab setup and its manual checklist.

This directory contains capture instructions, not current running-app verification evidence.
Generate and visually review fresh captures for a specific check before relying on them. Manual
captures are review artifacts, not automated pixel baselines. Current automated references live in
[`../Snapshots/Recipe/`](../Snapshots/Recipe/).

## Capture

From the repository root, with a booted iPhone simulator or an active desktop session:

```sh
bash scripts/capture-recipe-lab.sh macos Tests/References/RecipeLab
bash scripts/capture-recipe-lab.sh ios Tests/References/RecipeLab
```

Use a toolchain meeting the [package requirements](../../../README.md#requirements). The script
launches a fresh process per preset, then sweeps requested sizes and waits for local images. It captures the initial iOS
viewport and three macOS scroll positions. This is a manual smoke and screenshot tool, not geometry
qualification. Output contains PNGs only, without TSV or text sidecars. Platform chrome and clocks
make captures nondeterministic. Resize and capture failures remain failures; collected screenshots
remain available for inspection. On older Xcode without resizable-session support, iOS captures one
primary viewport per preset with a notice. Successful captures are normal smoke success.

- iOS drives geometry with `devicectl` resizable app sessions and captures the `Resizable` display;
  Device Hub does not need to be running. The script does not scroll iOS, so iOS captures are initial
  viewports. [Device Hub scrolling](../../../Documentation/Contributing/DeviceHub.md#capture-sweeps-and-scrolling)
  covers that gap.
- macOS also scrolls with Home, Page Down, and End, reaching `top`, `middle`, and `end`. Width is
  applied through System Events. Desktop capture needs Screen Recording and System Events access.
- Inspect screenshot content rather than treating a requested width as verified layout coverage.
  See [resize and capture troubleshooting](../../../Documentation/Contributing/DeviceHub.md#resize-and-capture).

Presets and widths are overridable per run:

```sh
CAPTURES="light generous" IOS_WIDTHS="320x700 430x932" \
  bash scripts/capture-recipe-lab.sh ios Tests/References/RecipeLab
MACOS_WIDTHS="600x900 1200x900" \
  bash scripts/capture-recipe-lab.sh macos Tests/References/RecipeLab
```

To explore one preset:

```sh
scripts/run-fixture-host.sh macos --capture hostMarkers
scripts/run-fixture-host.sh ios --capture generous
```

## Presets

Defaults: standard text, light appearance, LTR, interactive tasks, default markers, and literal
unsupported content. iOS uses a 240-point reading column; macOS follows window width.
The recipe's two rasters are bundled PNG/JPEG files that the fixture loader serves; a URL the loader
does not serve falls back to a `leaf.fill` SF Symbol, whose appearance depends on the OS.

| Preset | Variation |
| --- | --- |
| `light` | Default |
| `dark` | Dark appearance |
| `generous` | iOS only: `accessibility2` Dynamic Type; the name is unknown on macOS and falls back to `light` |
| `rightToLeft` | RTL with English content |
| `hostMarkers` | Custom task markers |
| `readOnly` | Static tasks |
| `omission` | Hide HTML |

Filenames follow `<platform>-<runtime>-<preset>-<pixel-width>x<pixel-height>[-<scroll>][-<collision>].png`.
Dimensions are actual screenshot pixels, not points. Runtime is the iOS simulator OS version for iOS
and the host OS version for macOS. macOS scroll suffixes are `top`, `middle`, and `end`; a collision
suffix prevents overwriting existing captures.

`readOnly` changes `allowsTaskEditing` only: it changes behavior, not pixels, so no screenshot can
verify it. Use interaction or accessibility evidence.

`generous` is iOS only, and the macOS default sweep omits it. Passing `CAPTURES="generous"` for macOS
reports that it was skipped and captures nothing under that name.

## Verification limits

Manual captures are not byte-stable, even at the same geometry and scroll position. Confirm wrapping,
clipping, and control appearance by eye or with a directed test.

Keep these checks open:

- Review every preset and every macOS width and scroll position for wrapping, clipping, and table
  reachability. Generating artifacts is not verification.
- Capture scrolled iOS content, including the lower task controls in `hostMarkers` and `readOnly`.
  The script captures only the initial iOS viewport.
- Exercise settings, Markdown links, and task controls with real input. Confirm that state changes;
  a successful input command alone does not verify interaction.
- Perform live VoiceOver checks on both platforms: task labels, state, nesting, focus order, toggle
  actions, read-only semantics, and independent links and tasks. Custom markers must not become
  extra focus stops.

Record platform, build, preset, actions, and actual outcomes. Native text exports and semantic trees
do not establish visual layout or live accessibility behavior.
