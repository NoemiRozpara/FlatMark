# Testing FlatMark

[Package usage](../README.md) · [Construction benchmarks](../Benchmarks/README.md) ·
[Capture references](References/RecipeLab/README.md)

## Automated tests

Run from the package repository root with a toolchain meeting the [requirements](../README.md#requirements):

```sh
swift test
```

Model-level tests cover projection, source-preserving task updates, and unsupported-content policy.
macOS-mounted tests exercise selectable native content, host replacements, tasks, image loading,
and navigation. They do not replace visual, gesture, or live accessibility checks.

### Observation boundaries

- **Structure:** `visibleDocument(_:policy:)` records surviving literal/omitted blocks and nesting.
  `customHosts(in:)` records replacement positions, not what host views draw. Helpers live in
  `FlatMarkRenderObservation.swift`.
- **Native content:** `MountedView.visibleText` / `visibleAttributedText` export native selection
  through public `NSServicesMenuRequestor` APIs into a temporary pasteboard. Assertions cover
  wording and exported bold, italic, strikethrough, and link attributes. The general pasteboard
  is not used. A region with no wording at all reads as blank, for example an emptied row,
  item, or cell. A region that takes space and still cannot export fails instead of returning
  empty content. `visibleText(showing:)` waits for wording to appear. `visibleText(matching:)`
  waits for the exact wording a reader gets, so a mounted view that keeps its earlier answer
  after a state change fails. `FlatMarkOmissionSample.swift` pairs one Markdown source with the
  wording each built-in policy is expected to display, so the mounted and projection checks read
  one document.
- **Interaction:** isolated AppKit event-loop hosts activate links and task markers and inspect
  callbacks. Navigation hosts use hidden windows, local events, and a controlled opener: no global
  input, Accessibility permission, browser, or external handler is required. Reports and timeouts
  prevent treating process exit alone as successful activation.
- **Loader callbacks:** `LoaderSpy` retains every recorded loader callback until an expectation of
  that kind consumes it, so a test may arm before or after the operation that triggers the loader.
  One callback satisfies exactly one expectation, and a wait that ends at its deadline leaves the
  callback missing to be reported by the unmet confirmation rather than by a polling bound. Checks
  of that waiting contract live in `LoaderSpyTests` and are not evidence about the renderer.
- **Drawn image geometry:** the aspect-fitting check mounts a painted solid-color raster, waits for
  its own pixels to appear in the mounted view's drawing, and measures their bounding box in points
  inside a capture deliberately larger than any correct result. Missing or collapsed output, a wrong
  aspect ratio, and a measurement clipped into looking correct therefore all fail; an `NSImage(size:)`
  that only reports a size cannot pass. This is a bounded pixel readback of one fixture, not a
  screenshot review: it establishes that the loaded image drew at the fitted size, not its appearance,
  on-screen clipping, or placement.
- **Effective text size:** mounted layout cases vary an explicit font-size override, because macOS body
  text does not scale from `dynamicTypeSize` alone (the Recipe Lab fixture does the same). A control
  case asserts the override really changes rendered size, and every case requires positive geometry and
  strictly larger output once enlarged, so two variants that rendered identically cannot pass. A font
  override is not system Dynamic Type, VoiceOver, or readability verification.
- **Drawn flow placement:** the linked-image flow case mounts the shared inline flow in a capture wider
  than its column and measures where the view's own ink landed, so a flow that drew nothing, drew one
  unbroken line, or drew past the column fails. The case also asserts the fixture really is in that
  flow, since an image whose link did not resolve falls back to native text unnoticed.

Native-content inspection requires selectable views and is qualified on the current toolchain only;
see the floor lane for minimum-version coverage. SwiftUI descendant capabilities/order are not a stable
inspection contract; requalify after OS/toolchain changes. Accessibility text is a separate representation and is not a substitute for
visible-content inspection.

These tests do **not** prove glyph visibility, layout gaps, exact on-screen fonts, minimum
hit-target size, selection gestures, external URL-opening success, or iOS interaction. A nonzero
mounted size proves neither readability nor correct geometry. Only the linked-image flow above has an
automated hosting-independent width guard; table, quote, and cell overflow remain manual checks.

## Recipe Lab

The backend-free host renders one focaccia recipe shared with the mounted suite. It includes tasks,
mentions, links, a local illustration, tables, code, nested content, and unsupported HTML.
Source: [FlatMarkCustomFixture.swift](../Support/FlatMarkFixtures/FlatMarkCustomFixture.swift) and
[FlatMarkRecipeSample.swift](../Support/FlatMarkFixtures/FlatMarkRecipeSample.swift).

Open [the demo Xcode project](../Demo/FlatMarkDemo.xcodeproj) and choose its iOS or macOS
scheme (see [demo setup](../Demo/README.md)). It references these shared sources directly.
Alternatively, with an iPhone simulator booted for iOS, run:

```sh
scripts/run-fixture-host.sh ios
scripts/run-fixture-host.sh macos
```

The default `daylight` preset uses custom replacements and standard text. Pass
`--capture generous` after the platform for enlarged text. iOS uses a 240-point reading column;
macOS follows window width. No login or backend data is needed. See the
[capture guide](References/RecipeLab/README.md) for all presets.

### Controls to exercise

| Area | Checks |
| --- | --- |
| HTML | **Show HTML / Replace tags / Hide HTML** correspond to literal/custom/omit |
| Replacements | Edit the label; toggle **Make replacements tappable** and **Replace with nothing** |
| Appearance | **Detect mentions**, **Larger recipe text**, **Right-to-left recipe layout** |
| Tasks | **Use custom checkmarks** and **Allow ticking tasks** independently control drawing/editing |
| Snapshot reuse | **Use retained document**, **Re-render without editing**, **Add a tasting note** |

Refresh counters count host requests, not renderer evaluations or parser calls. Source edits and
mention-detection changes replace the snapshot; unchanged refreshes retain it. Both initializers
should agree on wording, attributes, links, and task behavior.

## Manual checklist

Run on both iOS and macOS; record OS, build, actions, observed results, and unavailable checks.

- **Policy changes:** exercise literal → custom → omit → literal → omit → custom → literal without
  source edits. Unsupported content should refresh, surviving tasks keep their addresses, and
  unaffected image loads should not restart. Empty paragraphs/headings/quotes removed by omission
  should leave no layout slot or quote rule. Supported list/table structure remains.
- **Custom content:** opening/closing tags create separate replacements. Empty custom views add no
  fallback or synthetic spaces, but parent spacing may remain. Supported neighboring text retains
  formatting and navigation.
- **Independent actions:** activate a host replacement, adjacent Markdown link, and task separately.
  Only the matching feedback/counter should change. HTML attributes must not cause navigation or
  fetching; supported Markdown images remain subject to the loader policy.
- **Task markers:** compare default/custom, checked/unchecked, nested, interactive/read-only, enlarged
  text, and RTL. One activation changes only its source marker. Read-only tasks offer no toggle
  action; marker drawings are not extra accessibility elements.
- **Mentions:** `@ja*ne*` bolds only `@ja`; whole-token emphasis/strikethrough remains. Code and link
  labels are excluded. Text nodes are scanned independently: `*email*@example.com` can bold
  `@example.com`, while plain `email@example.com` remains unchanged.
- **Layout:** inspect headings, tables, nested blocks, multiline text, images, and custom views at
  narrow/wide widths and enlarged text. Check RTL, clipping, overflow, and table-cell reachability.
- **Selection:** try selecting within and across native regions; record fragmentation rather than
  assuming continuous selection across mixed views.
- **Accessibility and keyboard:** use live VoiceOver to check labels, checked state, nesting, focus
  order, and independent actions. Check read-only semantics, disabled interactive tasks, and keyboard
  activation where supported. Confirm state is distinguishable without color alone.

Empty-label tasks, ordered rows, and table cells are covered by the focused omission tests rather
than the readable recipe. Preserve their markers, numbering, structure, and source-update behavior.

## Verification status

Earlier iOS simulator and macOS runs observed policy changes, source-preserving task updates,
independent custom/link actions, marker appearance, and selected layout cases. Mounted tests cover
initializer parity and mention attributes. These observations predate the current compact recipe
and do not verify its current UI.

Screenshot artifacts are not included; earlier captures predate the compact recipe. New captures
need visual review. See the [reference guide](References/RecipeLab/README.md) for limitations.
Outstanding work:

- Current-fixture visual and interaction passes on both platforms, including lower scroll content.
- Live VoiceOver announcements, focus order, and actions on both platforms.
- Actual selection gestures, complete adjacent link/custom-marker interaction, and enlarged system
  text on macOS; a fixture font-size override is not system accessibility verification.
- Rechecking previously observed macOS quote truncation and narrow-table clipping with the original
  failing content. Changing fixture wording does not establish a renderer fix.

Automated native exports, semantic trees, and successful compilation are not substitutes for these
running-app observations.
