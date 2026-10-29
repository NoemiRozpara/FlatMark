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
bundle its `focaccia.jpeg`; no fixture sources are copied or imported as a package
module. Package tests continue using the internal `FlatMarkFixtures` target.

The initial preset is `daylight`. Add `--capture <preset>` under Scheme > Edit
Scheme > Run > Arguments, or launch from the repository root:

```sh
scripts/run-fixture-host.sh ios --capture generous
scripts/run-fixture-host.sh macos --capture hostMarkers
```

Presets: `daylight`, `midnight`, `generous`, `rightToLeft`, `hostMarkers`,
`readOnly`, `literal`, `omission`. Unknown or missing values fall back to daylight.
The existing bundle identifiers are retained for capture tooling. The launcher
builds a normal app bundle into `.build/demo`; it no longer assembles one by hand.

To capture all presets, choose a platform and output directory:

```sh
bash scripts/capture-recipe-lab.sh ios output-directory
bash scripts/capture-recipe-lab.sh macos output-directory
```
