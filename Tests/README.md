# Testing FlatMark

[Package usage](../README.md) · [Markdown support](../Documentation/MarkdownSupport.md) ·
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
pixel comparison. `Demo/FlatMarkDemo.xcodeproj` owns both snapshot targets and their four shared
schemes; the normal schemes set `FLATMARK_SNAPSHOT_RECORD=never` and the `-Record` schemes set `all`.
Edit project settings and schemes directly in Xcode. Snapshot suites and shared fixtures use synchronized
folders; no project generation is required. See the [demo guide](../Demo/README.md) for file membership.

Both targets compile the snapshot suites and shared fixtures. The macOS target is hostless and
initializes AppKit itself.

### Verify and record

From the repository root, discover destinations and use the checked-in shared schemes:

```sh
xcodebuild -showdestinations -project Demo/FlatMarkDemo.xcodeproj -scheme FlatMarkSnapshots-iOS
xcodebuild test -project Demo/FlatMarkDemo.xcodeproj -scheme FlatMarkSnapshots-macOS \
  -destination 'platform=macOS'
xcodebuild test -project Demo/FlatMarkDemo.xcodeproj -scheme FlatMarkSnapshots-iOS \
  -destination 'platform=iOS Simulator,id=<discovered UDID>'

# Record only a deliberate change; recording assertions fail by design.
xcodebuild test -project Demo/FlatMarkDemo.xcodeproj -scheme FlatMarkSnapshots-macOS-Record \
  -destination 'platform=macOS' '-only-testing:FlatMarkSnapshots-macOS/<Suite>'
xcodebuild test -project Demo/FlatMarkDemo.xcodeproj -scheme FlatMarkSnapshots-iOS-Record \
  -destination 'platform=iOS Simulator,id=<discovered UDID>' '-only-testing:FlatMarkSnapshots-iOS/<Suite>'
```

Alternatively, use the optional [SweetPad CLI](https://sweetpad.hyzyla.dev/docs/cli/getting-started/):

```sh
sweetpad devices                       # discover destinations

sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS --on booted

# Record a deliberate change. These runs report assertion failures by design.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS-Record --on mac \
  --only-testing FlatMarkSnapshots-macOS/<Suite>

# Re-run one case, for example after restoring a missing reference.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac \
  --only-testing 'FlatMarkSnapshots-macOS/<Suite>/<test>()'
```

Rules:

- Record only an intended rendering change, review every changed image at readable scale, then run
  the normal scheme twice and confirm reference hashes are unchanged.
- Byte-identical captures may share a golden, but each capture must check that golden independently.
  Omission/control documents, fresh mounts, empty interactive/read-only tasks, and iOS image-phase
  controls share references this way. macOS image-phase controls retain separate references.
- Never record to make a failure pass. A missing reference fails verify mode, is never written, and its
  failure names the case, its environment, and the full path of the reference it expected.
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
- Enlarged references are iOS-only and use `.accessibility5` Dynamic Type. FlatMark does not
  support enlarged text on macOS.
- Capture mounts a native hosting view, yields three layout passes, then captures once. An optional
  `prepareMountedView` hook settles layout and positions scroll viewports. Native capture failure
  throws.
- macOS pins `NSWindow.colorSpace` to sRGB before drawing, then flattens the hosting bitmap over
  the appearance background in an explicit 16-bit sRGB `CGContext`. It does not use an implicit
  display-profile `NSImage` context. A synthetic raster test checks exact source colors and identical
  captures on connected displays. This explicit color space keeps the capture independent of the
  display profile; it does not remove OS or toolchain differences.
  The macOS lane still needs a 2x hosting display; changing OS, toolchain, or display requires
  deliberate baseline review.
- The exact-pixel lane is environment-sensitive. Sub-perceptual failures can report zero differing
  pixels under `magick compare -fuzz 0.5% -metric AE`. Treat those as unverified, not as
  regressions, and do not re-record to silence them.

### Coverage

Static presentation snapshots use the shared recipe in
`Support/FlatMarkFixtures/FlatMarkRecipeSample.swift`, the same document the demo renders. Recipe Lab
builds from the same sections. The Recipe suite also compares custom task markers in interactive,
disabled, and read-only states using the shared task fragment, including nested and wrapped labels.
Default-marker disabled/read-only cases use only that fragment. No-loader cases compose standalone,
mixed-inline, and hard-break image fragments at narrow and wide widths, including iOS `.accessibility5`.
Full-recipe light/dark cases still traverse to the actual content bottom.
Focused iOS cases cover all six heading levels and loaded standalone, mixed-inline, and hard-break
image flow at `.accessibility5`. The enlarged long-table case captures overlapping top and bottom
viewports and checks final-row reachability. Header-only tables share one capture per platform: a
two-column table at the document start and a one-column table between paragraphs. The internal empty
table keeps separate coverage. A focused suite-local Arabic/Latin sample covers RTL appearance with
Latin links, numbers, nested checked/unchecked tasks, and a loaded image at a 240pt column on both
platforms, using the Arabic locale. This does not qualify pronunciation, focus order, or activation.
Do not add a second Markdown sampler or a second fixture system.

Focused fixtures stay where the demo cannot express the contract: held image loading, throwing
failures, exact raster sizes, request lifecycle, policy/image transitions, table scroll offsets,
internal empty tables, deliberately empty tasks, ordered rows, empty table cells, and consecutive
hard breaks.

`FlatMarkInlineFlowSnapshotTests` reviews that contract: two consecutive hard breaks in mixed inline
flow keep one blank row of body metrics, checked in the reviewed reference and in the laid-out rows
of the mounted paragraph.

## Observation boundaries

| Evidence | Establishes | Limit |
| --- | --- | --- |
| Projection and policy assertions | Surviving structure under literal and omission policies | Not native drawing |
| `MountedView.visibleText` / `visibleAttributedText` | Native selection exports: wording, bold, italic, strikethrough, links | Not glyph visibility, clipping, selection gestures, or live accessibility; requalify after OS/toolchain changes |
| Isolated AppKit event-loop hosts | Local link/task activation with a controlled opener | No browser, global input, or Accessibility permission; iOS delegate calls are not gestures |
| `LoaderSpy` | Callbacks retained until consumed by matching expectations | Missing callbacks fail expectations, not a polling bound |
| Aspect-fit and flow-placement cases | View ink geometry, including collapse and off-column failures | Not reviewed appearance |
| Explicit font-size overrides | Layout at changed effective text sizes for plain `Text`, and for FlatMark text on iOS | FlatMark's native macOS text ignores the override; macOS enlarged text is unsupported |

Native descendant order is not source order in a lazy stack; retained offscreen regions can appear
out of order or be absent. Long-document initializer parity therefore scrolls both hosts and compares
intersecting native regions in geometric order, including title and edited-tail checks. This exports
whole intersecting regions, not only visible glyphs, and does not establish continuous selection.

On Xcode 26, selectable SwiftUI text uses `NSTextField` backing. The mounted reader activates
its AppKit field editor and exports RTF from that editor, including list markers. The
[verification status](#verification-status) records qualified environments and remaining gaps.

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
| HTML | **Show HTML / Hide HTML** = literal / omit |
| Appearance | **Larger recipe text** (iOS only; AppKit ignores Dynamic Type), **Right-to-left recipe layout** |
| Tasks | **Use custom checkmarks** and **Allow ticking tasks** independently control drawing and editing |
| Snapshot reuse | **Use retained document**, **Re-render without editing**, **Add a tasting note** |

Refresh counters count host requests, not renderer evaluations or parser calls. Source edits replace
the snapshot; unchanged refreshes retain it. Both initializers must agree on wording, attributes,
links, and task behavior.

## Manual checklist

Run on both platforms; record OS, build, actions, observations, and unavailable checks.

- **Policy changes:** literal → omit → literal without source
  edits. Surviving tasks keep their addresses, unaffected image loads do not restart, blocks emptied
  by omission leave no slot or quote rule, and supported structure remains.
- **Unsupported content:** literal HTML stays inert; omission preserves supported neighbors,
  formatting, and navigation. HTML attributes must not navigate or fetch.
- **Independent actions:** activate an adjacent Markdown link and a task separately; only the
  matching counter changes.
- **Task markers:** compare default/custom, checked/unchecked, nested, interactive/read-only,
  enlarged (iOS), and RTL. One activation changes only its own source marker; read-only tasks offer no
  toggle.
- **Mentions:** `@ja*ne*` bolds only `@ja`; whole-token emphasis/strikethrough remains; code and link
  labels are excluded; text nodes are scanned independently.
- **Layout:** headings, tables, nested blocks, multiline text, images, and custom task markers at narrow and
  wide widths, enlarged text (iOS), and RTL; check clipping, overflow, and table-cell reachability.
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
dropped-expectation behavior.

Recorded results qualify only their stated environments:

| Check | Recorded environment and result | Limits |
| --- | --- | --- |
| Mention and omission live-update wording | macOS 27.0.1; Xcode 26.0 / Swift 6.2 and Xcode 27.0 / Swift 6.4; passed | Native exports, not pixels or macOS 15 qualification |
| iOS paragraph geometry | iOS 18.5 and iOS 27.0 simulators on macOS 27.0.1; Xcode 27.0 (27A266a); 17 tests passed | Native layout, not visual or interaction qualification; no iOS 17 coverage |
| Package suite, including sRGB snapshots | Recorded pass on macOS 27.0.1 / Swift 6.4 with `FLATMARK_SNAPSHOT_RECORD=never swift test`; one test-helper known issue | Does not qualify iOS, minimum toolchains, or a later release candidate |
| Snapshot repeatability | Same macOS environment; two fresh processes passed 31 tests in eight suites without changing reference hashes | Exact-pixel results remain OS-, toolchain-, and scale-sensitive |
| Display-profile isolation | Full snapshot selection passed at 2x on Built-in Retina Display against references recorded on LG ULTRAFINE | Synthetic regression also checks source colors and full PNG equality across connected displays; other scales are not qualified |
| Xcode 26 snapshots | Nine Recipe failures recorded, including a code-line vertical placement difference | Not requalified against the current sRGB references; not a release waiver |
| Xcode 26.0 (17A324) iOS execution | No eligible simulator destination; iOS 26.0 platform reported as not installed | No test execution established |

The iOS retained-size check keeps one paragraph visible in a scroll host. Separate tests check
neighbor overlap without assuming offscreen lazy content stays mounted.

Still open:

- Current-fixture visual and interaction passes on both platforms, including lower scroll content.
- Live VoiceOver announcements, focus order, and actions on both platforms
  ([#10](https://github.com/NoemiRozpara/FlatMark/issues/10)).
- Actual selection gestures and full adjacent link/custom-marker interaction on both platforms
  ([#11](https://github.com/NoemiRozpara/FlatMark/issues/11)).
- Running-app confirmation that nested list rows stay inside the offered column and RTL task rows
  indent inward.
- macOS quote-truncation and narrow-table-clipping reports: recover or reduce a reproducer for each,
  then check it in the running app. Different fixture wording does not establish a fix.
- Minimum iOS 17 / macOS 15 and Xcode 26 / Swift 6.2 execution; recorded runs used newer toolchains.

Native exports, semantic trees, and successful compilation are not substitutes for these running-app
observations.
