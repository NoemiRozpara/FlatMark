# Recipe Lab captures

See the [test guide](../../README.md#recipe-lab) for Recipe Lab setup and its manual checklist.

Committed captures are review artifacts, not automated pixel baselines. They predate the current
recipe and have not been visually reviewed. Regenerate and review before relying on them. Current
automated references live in `../Snapshots/Recipe/`.

## Capture

From the repository root, with a booted iPhone simulator or an active desktop session:

```sh
bash scripts/capture-recipe-lab.sh macos Tests/References/RecipeLab
bash scripts/capture-recipe-lab.sh ios Tests/References/RecipeLab
```

Use a toolchain meeting the [package requirements](../../../README.md#requirements). The script
launches a fresh process per preset and width and waits for local images. It captures the initial iOS
viewport and three macOS scroll positions. Environment files record OS, toolchain, and simulator.
Platform chrome and clocks make captures nondeterministic.

Each capture is paired with a `<platform>-widths.tsv` manifest: requested size, measured size, pixel
dimensions, scale and its source, filename, and whether the request was honoured. Filenames carry the
measured size, so a clamped request cannot be read as a width that was tested. Treat a `clamped` or
`rejected` note as a finding, not a pass.

- iOS drives geometry with `devicectl` resizable app sessions and captures the `Resizable` display;
  Device Hub does not need to be running. The script does not scroll iOS, so iOS captures are initial
  viewports. [Device Hub scrolling](../../../AI-docs/DEVICE_HUB.md#scroll-an-ios-app-in-device-hub)
  covers that gap.
- macOS also scrolls with Home, Page Down, and End, reaching `top`, `middle`, and `end`. Width is
  applied through System Events; the window is moved to a fixed origin first, and the applied size is
  read back from the window server. Desktop capture needs Screen Recording and System Events access.
- If macOS widths ever snap to a huge value, start with the `sizeThatFits` note in the
  [Device Hub guide](../../../AI-docs/DEVICE_HUB.md), not the harness.

Presets and widths are overridable per run:

```sh
CAPTURES="daylight generous" IOS_WIDTHS="320x700 430x932" \
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
| `daylight` | Default |
| `midnight` | Dark appearance |
| `generous` | iOS only: `accessibility2` Dynamic Type; the name is unknown on macOS and falls back to `daylight` |
| `rightToLeft` | RTL with English content |
| `hostMarkers` | Custom task markers |
| `readOnly` | Static tasks |
| `omission` | Hide HTML |

Filenames follow `ios-<preset>-<width>x<height>.png` and
`macos-<preset>-<width>x<height>-<scroll>.png`, where the size is the measured geometry in points.

`readOnly` changes `allowsTaskEditing` only: it changes behavior, not pixels, so no screenshot can
verify it. Use interaction or accessibility evidence.

`generous` is iOS only, and the macOS default sweep omits it. Passing `CAPTURES="generous"` for macOS
reports that it was skipped and captures nothing under that name.

## Verification limits

Single-frame pixel differences are weak evidence here: repeating one capture at the same geometry and
scroll position produced two distinct hashes. Confirm anything that matters by eye or with a directed
test.

Keep these checks open:

- Review every preset and every macOS width and scroll position for wrapping, clipping, and table
  reachability. Generating artifacts is not verification.
- Capture scrolled iOS content, which today never reaches `hostMarkers` or `readOnly` content.
- Exercise settings and inline replacement buttons with real input; an automation attempt that
  reported taps without changing state proved neither.
- Verify system-level enlarged text on macOS separately: the fixture offers no macOS font-size control,
  because AppKit sets its own preferred font on every recipe text run.
- Perform live VoiceOver checks on both platforms: task labels, state, nesting, focus order, toggle
  actions, read-only semantics, and independent links and replacements. Custom markers must not become
  extra focus stops.

Record platform, build, preset, actions, and actual outcomes. Native text exports and semantic trees
do not establish visual layout or live accessibility behavior.
