# FlatMark demo

Open `FlatMarkDemo.xcodeproj` and select **FlatMarkDemo-iOS** (simulator or device) or
**FlatMarkDemo-macOS** (My Mac). Device builds require your signing team.

The checked-in Xcode project and shared schemes are the source of truth. Edit target settings and
schemes directly in Xcode and commit those changes. No project generation is required.

The demo sources, shared fixtures, and snapshot suites use synchronized folders. Files added or removed
in those directories are discovered automatically. The macOS snapshot target includes only two helpers
from `Tests/FlatMarkTests/Rendering` through explicit file references; update those references in Xcode
if the helpers move or change.

Both apps link the local `FlatMark` product, compile `Support/FlatMarkFixtures` directly, and bundle
`focaccia.jpeg` and `leaf.png`. Package tests use the internal `FlatMarkFixtures` target instead.

## Recipe

The fixture includes all six heading levels, nested list continuations, multi-line quotes, and linked
and unlinked images. Turn off **Load bundled images** in Settings to inspect placeholders without
changing the Markdown. The fixture never fetches remote images. Automated static snapshots use this same
document and its sections; see [snapshot coverage](../Tests/README.md#snapshot-baselines).

## Capture presets

The initial preset is `light`. Add `--capture <preset>` under Scheme > Edit Scheme > Run > Arguments,
or launch from the repository root:

```sh
scripts/run-fixture-host.sh ios --capture generous
scripts/run-fixture-host.sh macos --capture hostMarkers
```

Presets: `light`, `dark`, `rightToLeft`, `hostMarkers`, `readOnly`, `omission`, and `generous`
on iOS. Unknown or missing values fall back to `light`, which is also what `generous` resolves to on
macOS. The launcher builds a normal app bundle into `.build/demo`; the existing bundle identifiers are
retained for capture tooling.

**Larger recipe text** is an iOS-only control. It applies the `.accessibility2` Dynamic Type category to
the recipe, so it is not a system Dynamic Type control. With enlarged text off, the iOS recipe inherits
system Dynamic Type rather than pinning `.large`; to qualify iOS typography updates, turn enlarged text
off and change the system text size, including an accessibility category, while the app stays mounted. A
`generous` capture or an environment-only test does not establish that behavior. macOS has no equivalent
control: `FlatMarkAppKitParagraphText` applies each role's preferred AppKit font to recipe runs, so
neither Dynamic Type nor an ambient SwiftUI `.font` enlarges them.

## Sweeping widths

```sh
bash scripts/capture-recipe-lab.sh ios output-directory
bash scripts/capture-recipe-lab.sh macos output-directory
```

This is a manual smoke and screenshot tool, not geometry qualification. See
[Recipe Lab captures](../Tests/References/RecipeLab/README.md) for script behavior, overrides,
permissions, filenames, and limits. iOS captures only initial viewports; use
[Device Hub scrolling](../Documentation/Contributing/DeviceHub.md#capture-sweeps-and-scrolling) to inspect lower content.
