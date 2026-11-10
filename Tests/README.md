# Testing FlatMark

[Package usage](../README.md) · [Markdown support](../SUPPORT.md) ·
[Construction benchmarks](../Benchmarks/README.md) · [Capture references](References/RecipeLab/README.md)

Three lanes answer different questions. Do not substitute one for another:

| Lane | Establishes | Cannot establish |
| --- | --- | --- |
| Package tests (`swift test`) | projection, policy, source-preserving task edits, image loading, navigation callbacks, mounted native exports on macOS | visible pixels, gestures, live VoiceOver |
| Snapshot targets (`FlatMarkSnapshots-*`) | reviewed appearance of mounted views at recorded environments | activation, selection, VoiceOver |
| Running demo (Recipe Lab) | actual behavior at the size and settings you drove | anything you did not observe |

## Layout

- `Tests/FlatMarkTests/Rendering` — package tests, macOS-mounted checks, observation helpers, `LoaderSpy`.
- `Tests/FlatMarkTests/Snapshots` — snapshot suites and capture support; not part of the library product.
- `Tests/FlatMarkNavigationTestHost` — isolated macOS interaction host.
- `Tests/References/Snapshots/<suite>/<platform>/` — reviewed image baselines.
- `Tests/References/RecipeLab` — manual capture artifacts, not automated baselines.
- `Support/FlatMarkFixtures` — shared fixtures, compiled directly by the demo and both snapshot targets.

## Package tests

Run from the repository root with a toolchain meeting the
[requirements](../README.md#requirements):

```sh
swift test
swift test --filter <test-name>
swift test --list-tests
```

Prefer Swift Testing. Confirm the intended tests actually ran; a selection that matches nothing is
not verification. Tests that mount native content are serialized and share display resources, so do
not run capture processes concurrently.

## Snapshot baselines

Snapshots use [SnapshotTesting](https://github.com/pointfreeco/swift-snapshot-testing) with exact
pixel comparison. `Demo/project.yml` owns both snapshot targets and all four schemes; the normal
schemes set `FLATMARK_SNAPSHOT_RECORD=never` and the `-Record` schemes set `all`. After editing
`project.yml` or adding/removing test or fixture files, regenerate:

```sh
cd Demo && xcodegen generate
```

Both targets compile the snapshot suites and shared fixtures. The macOS target is hostless and
initializes AppKit itself.

### Verify and record

From the repository root, using the [SweetPad CLI](https://sweetpad.hyzyla.dev/docs/cli/getting-started/):

```sh
sweetpad devices                       # discover destinations

sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS --on booted

# Record a deliberate change. These runs report assertion failures by design.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS-Record --on mac \
  --only-testing FlatMarkSnapshots-macOS/<Suite>
```

Rules:

- Record only an intended rendering change, review every changed image at readable scale, then run
  the normal scheme twice and confirm reference hashes are unchanged.
- Never record to make a failure pass. A missing reference fails the run and is never written in
  verify mode; the message names the case and expected filename, not the full path.
- Recording assertions are expected failures, not verification passes.
- One recording process per namespace at a time (`@Suite(.serialized)` for mounted cases).
- Keep fixtures synchronous. Async fixtures must resolve their own state before capture; the helper
  does not infer readiness from pixels or loader callbacks.

### Environments

References live in `Tests/References/Snapshots/<suite>/<platform>/`; one namespace per suite
(`InlineFlow`, `OmissionSpacing`, `Tables`, `ImagePhases`, `PolicyTransitions`, `EmptyStructures`,
`Recipe`). Filenames encode the environment: test, case, column, inset, capture size, scale,
appearance, locale, direction, and text setting.

- `FlatMarkSnapshotEnvironment.standard`: 320×300pt capture, 240pt column, 20pt inset, 2x, light,
  `en_US`, LTR, standard Dynamic Type, 13pt macOS / 17pt iOS body, white background.
- Enlarged: iOS uses real `.accessibility3` Dynamic Type; macOS uses a 28pt override, which is not
  macOS system Dynamic Type.
- Capture mounts a native hosting view, yields three layout passes, then captures once. An optional
  `prepareMountedView` hook positions a horizontal viewport (table tests). Native capture failure
  throws.
- macOS pins `NSWindow.colorSpace` to sRGB before drawing and encodes to sRGB. The intermediate
  `NSImage` flattening still uses a display-profile context; this is not an end-to-end sRGB pipeline.
  See the [color investigation](../AI-docs/handoffs/macos-snapshot-color.md). The macOS lane needs a
  2x hosting display; changing OS, toolchain, or display requires deliberate baseline review.
- The exact-pixel lane is environment-sensitive. Sub-perceptual failures can report zero differing
  pixels under `magick compare -fuzz 0.5% -metric AE`. Treat those as unverified, not as
  regressions, and do not re-record to silence them.

### Coverage

Static presentation snapshots use the shared recipe in
`Support/FlatMarkFixtures/FlatMarkRecipeSample.swift`, the same document the demo renders. Recipe Lab
builds from the same sections. Do not add a second Markdown sampler or a second fixture system.

Focused fixtures stay where the demo cannot express the contract: held image loading, throwing
failures, exact raster sizes, request lifecycle, policy/image transitions, table scroll offsets,
internal empty tables, deliberately empty tasks, ordered rows, empty table cells, and the
consecutive-hard-break regression.

`consecutiveBreaksRetainCurrentRendering` records current mixed-flow output. It is not a claim that
those break semantics are correct; a renderer fix must update those references deliberately.

## Observation boundaries

| Evidence | Establishes | Limit |
| --- | --- | --- |
| `visibleDocument(_:policy:)`, `customHosts(in:)` | Surviving structure and replacement positions | Not host drawing |
| `MountedView.visibleText` / `visibleAttributedText` | Native selection exports: wording, bold, italic, strikethrough, links | Not glyph visibility, clipping, selection gestures, or live accessibility; requalify after OS/toolchain changes |
| Isolated AppKit event-loop hosts | Local link/task activation with a controlled opener | No browser, global input, or Accessibility permission; iOS delegate calls are not gestures |
| `LoaderSpy` | Callbacks retained until consumed by matching expectations | Missing callbacks fail expectations, not a polling bound |
| Aspect-fit and flow-placement cases | View ink geometry, including collapse and off-column failures | Not reviewed appearance |
| Explicit font-size overrides | Layout at changed effective text sizes | Not system Dynamic Type on macOS |

Native descendant order is not source order in a lazy stack; retained offscreen regions can appear
out of order or be absent. Long-document initializer parity therefore scrolls both hosts and compares
intersecting native regions in geometric order, including title and edited-tail checks. This exports
whole intersecting regions, not only visible glyphs, and does not establish continuous selection.

A region that occupies space but exports no text fails native-content inspection. Nonzero mounted size
alone proves neither readability nor geometry. Only linked-image flow has an automated
hosting-independent width guard; table, quote, and cell overflow remain manual checks. Hit-target size,
selection gestures, external opening success, iOS interaction, and live VoiceOver remain unverified by
these helpers.

## Recipe Lab

The backend-free host renders the [shared focaccia recipe](../Support/FlatMarkFixtures): tasks,
mentions, links, images, tables, code, nested content, and HTML. Run:

```sh
scripts/run-fixture-host.sh ios
scripts/run-fixture-host.sh macos
```

iOS uses a 240-point reading column; macOS follows window width. See
[demo setup](../Demo/README.md) for presets and [Recipe Lab captures](References/RecipeLab/README.md)
for driving sizes and scrolling.

| Control area | Checks |
| --- | --- |
| HTML | **Show HTML / Replace tags / Hide HTML** = literal / custom / omit |
| Replacements | Edit the label; toggle **Make replacements tappable** and **Replace with nothing** |
| Appearance | **Larger recipe text**, **Right-to-left recipe layout** |
| Tasks | **Use custom checkmarks** and **Allow ticking tasks** independently control drawing and editing |
| Snapshot reuse | **Use retained document**, **Re-render without editing**, **Add a tasting note** |

Refresh counters count host requests, not renderer evaluations or parser calls. Source edits replace
the snapshot; unchanged refreshes retain it. Both initializers must agree on wording, attributes,
links, and task behavior.

## Manual checklist

Run on both platforms; record OS, build, actions, observations, and unavailable checks.

- **Policy changes:** literal → custom → omit → literal → omit → custom → literal without source
  edits. Surviving tasks keep their addresses, unaffected image loads do not restart, blocks emptied
  by omission leave no slot or quote rule, and supported structure remains.
- **Custom content:** opening and closing tags produce separate replacements; empty output adds no
  fallback or synthetic space, though parent spacing may remain; supported neighbors keep formatting
  and navigation.
- **Independent actions:** activate a host replacement, an adjacent Markdown link, and a task
  separately; only the matching counter changes. HTML attributes must not navigate or fetch.
- **Task markers:** compare default/custom, checked/unchecked, nested, interactive/read-only,
  enlarged, and RTL. One activation changes only its own source marker; read-only tasks offer no
  toggle.
- **Mentions:** `@ja*ne*` bolds only `@ja`; whole-token emphasis/strikethrough remains; code and link
  labels are excluded; text nodes are scanned independently.
- **Layout:** headings, tables, nested blocks, multiline text, images, and custom views at narrow and
  wide widths, enlarged text, and RTL; check clipping, overflow, and table-cell reachability.
- **Selection:** select within and across native regions; record fragmentation rather than assuming
  continuous selection.
- **Accessibility and keyboard:** live VoiceOver for labels, checked state, nesting, focus order, and
  independent actions; read-only and disabled semantics; keyboard activation; state distinguishable
  without color.

Empty-label tasks, ordered rows, and empty table cells live in the focused tests rather than the
readable recipe; keep their markers, numbering, structure, and source-update behavior.

## Verification status

Covered by automation: projection, policy behavior, source-preserving task edits, image loading and
cancellation semantics, navigation callback routing on macOS, initializer parity, and reviewed static
appearance at the recorded environments.

Known-issue markers are not passing renderer qualifications: `LoaderSpyTests` documents its own
dropped-expectation behavior; the iOS paragraph suite records a terminal empty line extending beyond
the paragraph's allocated height. The latter remains a sizing qualification gap.

The lazy-renderer qualification run on macOS 27.0.1 / Swift 6.4 reports 189 tests and 29 issues,
including one known issue. The remaining 28 issues are exact snapshot failures; all emitted failure
pairs compare with zero differing pixels at 0.5% fuzz. They remain unverified, not passing snapshots.
The matched eager control reports the same failures. See the
[lazy-rendering follow-up](../Benchmarks/lazy-stack-comparison.md#follow-up-native-export-order-and-navigation-click-target).

Still open:

- Current-fixture visual and interaction passes on both platforms, including lower scroll content.
- Live VoiceOver announcements, focus order, and actions on both platforms.
- Actual selection gestures, full adjacent link/custom-marker interaction, and system enlarged text on
  macOS.
- Running-app confirmation that nested list rows stay inside the offered column and that RTL task
  rows indent inward; earlier captures recorded the opposite, and the later list-indentation change
  has not been re-observed on a running app.
- Reproducing the earlier macOS quote truncation and narrow-table clipping with the original failing
  content. Changing fixture wording proves nothing about a renderer fix.
- Minimum iOS 17 / macOS 14 and Xcode 26 / Swift 6.2 execution; recorded runs used newer toolchains.

Native exports, semantic trees, and successful compilation are not substitutes for these running-app
observations.
