# FlatMark demo

Open `FlatMarkDemo.xcodeproj` and select **FlatMarkDemo-iOS** (simulator or device) or
**FlatMarkDemo-macOS** (My Mac). Device builds require your signing team. The checked-in project runs
as is; XcodeGen is not needed to open it.

`project.yml` is the source of truth for project configuration. After editing it, or adding or removing
demo or shared fixture files, regenerate and commit the result:

```sh
cd Demo && xcodegen generate
```

Do not make configuration changes only in the generated project.

Both apps link the local `FlatMark` product, compile `Support/FlatMarkFixtures` directly, and bundle
`focaccia.jpeg` and `leaf.png`. Package tests use the internal `FlatMarkFixtures` target instead.

## Recipe

The fixture includes all six heading levels, nested list continuations, multi-line quotes, and linked
and unlinked images. Turn off **Load bundled images** in Settings to inspect placeholders without
changing the Markdown. The fixture never fetches remote images. Automated static snapshots use this same
document and its sections; see [snapshot coverage](../Tests/README.md#snapshot-baselines).

## Capture presets

The initial preset is `daylight`. Add `--capture <preset>` under Scheme > Edit Scheme > Run > Arguments,
or launch from the repository root:

```sh
scripts/run-fixture-host.sh ios --capture generous
scripts/run-fixture-host.sh macos --capture hostMarkers
```

Presets: `daylight`, `midnight`, `generous`, `rightToLeft`, `hostMarkers`, `readOnly`, `omission`.
Unknown or missing values fall back to `daylight`. The launcher builds a normal app bundle into
`.build/demo`; the existing bundle identifiers are retained for capture tooling.

The fixture's font-size override is not a system Dynamic Type control, and it does not enlarge semantic
native macOS text, which uses AppKit's preferred sizes. With enlarged text off, the iOS recipe inherits
system Dynamic Type rather than pinning `.large`; the `generous` preset overrides it with
`.accessibility2`. To qualify iOS typography updates, turn enlarged text off and change the system text
size, including an accessibility category, while the app stays mounted. A `generous` capture or an
environment-only test does not establish that behavior.

## Sweeping widths

```sh
bash scripts/capture-recipe-lab.sh ios output-directory
bash scripts/capture-recipe-lab.sh macos output-directory
```

The script resizes the running app and records actual geometry in `<platform>-widths.tsv`; failure to
reach a requested width exits nonzero. iOS uses `devicectl` resizable sessions and captures only initial
viewports. macOS uses System Events and captures `top`, `middle`, and `end` scroll positions. See
[Recipe Lab captures](../Tests/References/RecipeLab/README.md) for overrides, permissions, and limits,
and [Device Hub scrolling](../AI-docs/DEVICE_HUB.md#scroll-an-ios-app-in-device-hub) for lower iOS content.
