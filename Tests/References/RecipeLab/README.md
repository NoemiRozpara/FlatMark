# Recipe Lab captures

Recipe Lab renders a shared focaccia recipe with mentions, tasks, links, a local illustration,
unsupported-content policies, and retained-document controls. See the
[test guide](../../README.md) for setup and manual checks.

**No screenshots are currently included in this directory.** Earlier captures predate the compact
recipe and do not verify the current fixture. Regenerated captures are review artifacts, not
automated pixel baselines.

## Capture

From the repository root, with a booted iPhone simulator or an active desktop session:

```sh
bash scripts/capture-recipe-lab.sh macos Tests/References/RecipeLab
bash scripts/capture-recipe-lab.sh ios Tests/References/RecipeLab
```

Use the [package requirements](../../../README.md#requirements). The script launches a
fresh process per preset, waits for the local image, and captures the initial viewport. Lower content
requires separate scrolling and directed checks. Environment files record the OS/toolchain and
simulator. Captures contain platform chrome and clocks; do not treat them as deterministic pixels.

Desktop capture requires Screen Recording/System Events access and room for an 850 × 1040 point
window at (20, 40). Keep other windows clear and do not run competing fixture sessions. The script
closes each macOS fixture between presets.

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

Generated filenames follow `ios-<preset>.png` and `macos-<preset>.png`.

## Verification limits

Historical hosts built and ran on macOS 27 and an iPhone 18 Pro simulator running iOS 27.
Package tests passed. Runtime inspection observed task updates, policy-preset changes, and the iOS
reading-column width in an earlier, larger fixture. Those results do not verify the current recipe.

Keep the following checks open:

- Capture and visually review every preset for the current content. The previous capture pass was
  not visually reviewed; generating artifacts alone does not verify them.
- Exercise settings and inline replacement buttons with real input. The previous automation attempt
  reported taps but did not change their state; this established neither working nor broken behavior.
- Inspect lower scroll content, tables, code, mixed-content wrapping, and selection gestures.
- Reproduce earlier macOS quote truncation and narrow-table clipping. Shorter replacement wording
  is not evidence of a renderer fix; horizontal scrolling and complete cell reachability remain unverified.
- Perform live VoiceOver checks on both platforms: task labels/state/nesting, focus order, toggle
  actions, read-only semantics, and independent links/replacements. Custom marker drawings must not
  become extra focus stops.
- Verify system-level enlarged text on macOS separately from the fixture's explicit font-size preset.

Record the platform, build, preset, actions, and actual outcomes. Native text exports and semantic
trees do not establish visual layout or live accessibility behavior.
