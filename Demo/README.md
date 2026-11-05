# FlatMark demo

Open `FlatMarkDemo.xcodeproj` and select **FlatMarkDemo-iOS** (simulator or device)
or **FlatMarkDemo-macOS** (My Mac). Device builds require your signing team.
The checked-in project is ready to use; XcodeGen is not required to run it.
`project.yml` is the source of truth for project configuration. After editing it
or adding/removing demo or shared fixture files, regenerate the project with
`cd Demo && xcodegen generate` and commit the generated project and schemes.
Do not make configuration changes only in the generated Xcode project.

Both app targets reference the root package locally (`..`) and link its `FlatMark`
product. They compile the Swift files in `Support/FlatMarkFixtures` directly and
bundle its `focaccia.jpeg` and `leaf.png`; no fixture sources are copied or imported as a package
module. Package tests continue using the internal `FlatMarkFixtures` target.

The recipe includes all six heading levels, nested list continuations, multi-line
quotes, and linked and unlinked images. In Settings, turn off **Load bundled images**
to inspect placeholders without changing the Markdown. The fixture never fetches
remote images. Automated static snapshots use this same document and its sections;
see [snapshot coverage](../Tests/README.md#shared-demo-snapshot-coverage).

The initial preset is `daylight`. Add `--capture <preset>` under Scheme > Edit
Scheme > Run > Arguments, or launch from the repository root:

```sh
scripts/run-fixture-host.sh ios --capture generous
scripts/run-fixture-host.sh macos --capture hostMarkers
```

Presets: `daylight`, `midnight`, `generous`, `rightToLeft`, `hostMarkers`,
`readOnly`, `omission`. Unknown or missing values fall back to daylight.
The existing bundle identifiers are retained for capture tooling. The launcher
builds a normal app bundle into `.build/demo`; it no longer assembles one by hand.

The fixture's font-size override is not a system Dynamic Type control. It does not
enlarge semantic native macOS text, which uses AppKit's preferred font sizes.
With enlarged text off, the iOS recipe inherits system Dynamic Type instead of pinning `.large`.
The enlarged preset still overrides it with `.accessibility2`.
To qualify mounted iOS typography updates, turn enlarged text off and change the system text size
while the app remains mounted, including an accessibility category. A `generous` capture
or an environment-only test does not establish that behavior.

To capture all presets, choose a platform and output directory:

```sh
bash scripts/capture-recipe-lab.sh ios output-directory
bash scripts/capture-recipe-lab.sh macos output-directory
```

Both platforms sweep several widths on the running app rather than pinning one viewport, and write a
`<platform>-widths.tsv` manifest naming the size each capture actually reached. macOS also captures
`top`, `middle`, and `end` scroll positions; the script does not scroll iOS, so its captures are initial
viewports. MobileBuildMCP can scroll iOS apps displayed in Device Hub; see the Device Hub guide linked below. iOS drives geometry with `devicectl` resizable app sessions; macOS drives the window size
through System Events, and a sweep that cannot reach a requested width exits non-zero. See
[Recipe Lab captures](../Tests/References/RecipeLab/README.md) and
[AI-docs/DEVICE_HUB.md](../AI-docs/DEVICE_HUB.md).
