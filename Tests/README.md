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

### Snapshot baselines

SnapshotTesting 1.19.6 compares exact images. Support stays in
`Tests/FlatMarkTests/Snapshots`; it is not part of the library product.

Use the [SweetPad CLI](https://sweetpad.hyzyla.dev/docs/cli/getting-started/)
from the repository root. Neither `swift test` nor Xcode MCP is needed for these
snapshot commands. Swift Testing remains the test framework.

```sh
# Discover destinations. Replace booted with a simulator name or UDID if needed.
sweetpad devices

# Verify committed references.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS --on booted

# Record deliberately. These commands report assertion failures by design.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS-Record --on mac
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS-Record --on booted
```

The normal schemes explicitly set `FLATMARK_SNAPSHOT_RECORD=never`; the `-Record`
schemes set it to `all`. No shell environment setup is needed. After reviewing
recorded images, run the normal schemes again. SweetPad prints the retained
xcresult path; use `--result-bundle <unique-path>` to keep multiple runs separately.
Use `--non-interactive` for automation. These shared schemes also work in the
SweetPad VS Code Testing panel.

The iOS target uses the existing demo as its test host. The macOS target runs
without an app test host so AppKit snapshot setup owns application initialization.
`Demo/project.yml` owns both targets and all four schemes. After editing it,
regenerate with `cd Demo && xcodegen generate`.
SnapshotTesting reports reference/actual/diff paths on mismatches; runner logs
and xcresult bundles retain failure diagnostics. Missing references report the
expected path and fail. Do not record a mismatch just to make it pass.

References live in `Tests/References/Snapshots/<suite>/<platform>/`.
Each suite owns one namespace (`LinkedImage` initially); later suites add their
own enum case in `FlatMarkSnapshotSuite` with shared-support owner approval.
File names include the test, case, column, inset, capture size, scale, appearance,
locale, direction, and text setting. `FlatMarkSnapshotEnvironment.standard` uses
320×300pt, a 240pt column, 20pt inset, 2x, light appearance, `en_US`, LTR, standard
Dynamic Type, and a 13pt macOS / 17pt iOS font. The background is white.
The macOS lane requires a 2x hosting display. Use the same OS/toolchain/display
settings when verifying; changing them requires deliberate baseline review.

Later suites call `flatMarkSnapshotImage(of:environment:)`, then
`assertFlatMarkSnapshot(_:suite:named:environment:)`. Capture mounts native
hosting views and performs three yield/layout passes, with no polling, sleeps,
pixel classification, or fixture-specific drawing checks. UIKit also waits for
screen updates when drawing. This bounded preparation supports synchronous
fixtures, including these no-loader placeholders. Async fixtures must resolve
their state before capture; this helper does not infer readiness from pixels or
loader callbacks. Native capture failure throws. Empty or incomplete content is
caught by image comparison and baseline review, not a second custom validator.
An optional `prepareMountedView` hook runs after mounting and immediately before
native bitmap capture. Table tests use it to position the horizontal viewport;
callers that omit it get no extra await or layout pass.
Serialize mounted snapshot cases (`@Suite(.serialized)`) and do not run multiple
recording processes against the same namespace.

Review every recorded image before a separate verify run. Check text, placeholder,
link treatment, margins, and clipping. Keep only intended PNGs. Confirm verification
leaves reference hashes unchanged. These images do not verify activation, gestures,
or VoiceOver.

Initial qualification: Xcode 27 RC, Swift 6.4, macOS 27.0.1; iPhone 18 Pro simulator
on iOS 27.0. Both linked/unlinked images were recorded and visually inspected on
both platforms: surrounding text is visible, linked placeholders are blue, unlinked
placeholders use the text color, and content has clear margins. Separate verify
runs passed two tests per platform. Deliberately changed text failed comparison;
removing a reference failed without recreating it on both platforms. Minimum-OS
compatibility and forced native capture failure remain unverified.

SweetPad CLI qualification in the same environment: both normal schemes passed
(two tests each). Both `-Record` schemes reached explicit recording assertions and
wrote byte-identical references. Separate normal-scheme reruns passed afterward.

### Inline-flow qualification (ticket 02)

`FlatMarkInlineFlowSnapshotTests` owns ten references: narrow, wide, enlarged, RTL,
and consecutive-break captures on each platform. All use public `FlatMarkView` and
local fixture Markdown. Absolute image/link URLs resolve a linked placeholder;
no image loader or external navigation is used.

Qualified with Xcode 27.0 (27A266a), Swift 6.4, macOS 27.0.1 on a 2x display,
and the iPhone 18 Pro simulator on iOS 27.0. iOS enlarged text uses
`.accessibility3`; macOS uses a 28pt effective font override, not system Dynamic Type.

Commands below ran from the repository root through SweetPad. Results and logs
were retained locally under `/tmp/flatmark-ticket02/` (not repository artifacts).

```sh
# Explicit recording: each run selected five tests and reported five expected
# recording assertions, with no native capture failures.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS-Record --on mac --only-testing FlatMarkSnapshots-macOS/FlatMarkInlineFlowSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket02/mac-record.xcresult
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS-Record --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --only-testing FlatMarkSnapshots-iOS/FlatMarkInlineFlowSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket02/ios-record.xcresult

# Separate non-recording runs: seven passed per platform (five inline-flow,
# two existing linked-image tests).
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac --non-interactive --result-bundle /tmp/flatmark-ticket02/mac-verify.xcresult
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --non-interactive --result-bundle /tmp/flatmark-ticket02/ios-verify.xcresult
```

Discover your own simulator with `sweetpad devices`; the identifier above records
the actual run, not a required destination.

Visual review covered all ten references. Narrow and wide captures wrap differently;
the indigo 44×30pt replacement changes row baselines; supported bold/link text and
separated hard breaks remain visible. Enlarged and RTL captures retain their content
and clear outside margins. No visible overflow or clipping was found.

**Known renderer defect retained at the user's request:** consecutive hard breaks in
mixed flow do not preserve a blank row. The dedicated fixture contains both the
linked image and custom replacement, so it enters `FlatMarkInlineFlowLayout`.
`consecutiveBreaksRetainCurrentRendering` records that current output, not a claim
that its break semantics are correct. A later renderer fix must deliberately update
these two references. The older text-only images under
`AI-docs/prds/ui-snapshot-testing/evidence/` do not establish mixed-flow behavior.

Mutation check: temporarily replaced `beforeText` with
`MUTATION CHECK changes wrapping before the diagram inside the narrow reading column`.
Ran each normal scheme with the same suite-only filter used above and result bundles
`mac-mutation.xcresult` / `ios-mutation.xcresult`. Each run reported four genuine
snapshot mismatches and one passing consecutive-break case. Restored the fixture,
then reran both full normal schemes with result bundles `mac-final.xcresult` /
`ios-final.xcresult`: seven passed per platform. SHA-256 hashes of all ten inline-flow
references were identical before verification and after the mutation/restoration runs.
Existing numeric drawn-width and non-breaking-space tests were not changed or retired;
those rendering tests were not rerun in this focused snapshot check.

These are mounted-rendering snapshot checks, not running-demo interaction,
VoiceOver, selection-gesture, or minimum-OS qualification.

### Omission-spacing qualification (ticket 03)

`FlatMarkOmissionSpacingSnapshotTests` owns twelve PNGs in `OmissionSpacing`:
three cases, each with an omitted document and a hand-authored supported-only
control, on both platforms. All use public `FlatMarkView` with `.omit` and local
Markdown. Exact comparison uses the shared support without tolerances.

Qualified with Xcode 27.0 (27A266a), Swift 6.4, macOS 27.0.1 on a 2x display,
and iPhone 18 Pro on iOS 27.0. Enlarged text uses real `.accessibility3` on iOS
and a 28pt font override on macOS, not macOS system Dynamic Type.

These exact commands ran from the repository root. Each loop ran serially.
Logs and xcresults remain local under `/tmp/flatmark-ticket03/`.

```sh
(cd Demo && xcodegen generate)

# Initial recordings: three tests / six expected recording assertions per platform.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS-Record --on mac --only-testing FlatMarkSnapshots-macOS/FlatMarkOmissionSpacingSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket03/mac-record.xcresult
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS-Record --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --only-testing FlatMarkSnapshots-iOS/FlatMarkOmissionSpacingSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket03/ios-record.xcresult

# Reviewed fixture correction, then separate verification, probe, and restoration.
# Run this loop once per phase, with the fixture state described below.
for phase in intrinsic-record verify mutation final; do
  for platform in macOS iOS; do
    if [ "$platform" = macOS ]; then
      dest=mac
    else
      dest=674C04A9-8792-4995-A6A9-66F80E5F96AA
    fi
    scheme=FlatMarkSnapshots-$platform
    if [ "$phase" = intrinsic-record ]; then scheme=$scheme-Record; fi
    sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme "$scheme" --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkOmissionSpacingSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket03/$platform-$phase.xcresult
  done
  # Pause between phases for visual review, hash capture, or fixture edits.
done

# Before verify, and again after final (substitute after.sha256):
find Tests/References/Snapshots/OmissionSpacing -name '*.png' -exec shasum -a 256 {} \; | sort > /tmp/flatmark-ticket03/before.sha256
diff -u /tmp/flatmark-ticket03/before.sha256 /tmp/flatmark-ticket03/after.sha256
swift test
git status --short
git diff --check
```

The initial flexible quote filled the offered height and clipped the iOS after
paragraph. Those captures were rejected and retained locally in
`initial-unaccepted/`. The fixture now requests intrinsic vertical size with
`.fixedSize(horizontal: false, vertical: true)`; the capture remains fixed at
320×300pt or 320×1100pt, never fitted to the result. This does not qualify the
renderer under a vertically constrained host.

The implementation worker visually reviewed every final PNG with the image reader:

| PNG stem (both omitted and control, on each platform) | Review and verdict |
| --- | --- |
| `emptiedBlocksLeaveNoSlotsOrRules` | Both paragraphs intact; ordinary neighbor gap; no HTML-only paragraph/heading slot or single/nested quote rule; clear margins. Accepted all four PNGs. |
| `supportedListKeepsItsQuote` | Bullet and supported wording remain inside one visible quote rule; no removed child slot or nested rule; after paragraph fully visible. Accepted all four PNGs. |
| `enlargedNarrowNeighborsKeepTheirSpacing` | Both neighbors wrap with complete wording; ordinary paragraph spacing; no removed slots/rules; ample bottom/right margins and no clipping. Accepted all four PNGs. |

Each omitted/control pair has the same intended appearance. The final recordings
reported six expected recording assertions per platform with no native capture
failures. Separate `verify` runs passed three tests per platform.

For `mutation`, the first HTML-only paragraph and single quote changed from
`<u></u>` to `<u> </u>`. The supported spaces retain a blank block slot and an
otherwise empty quote rule. Both normal schemes reported two genuine image
mismatches (standard and enlarged omitted captures) and one passing retained-list
case; controls did not mismatch. The macOS actual image was also inspected: the
extra gap and orphan rule were visible. Restored both strings before `final`:
three tests passed per platform. All twelve reference SHA-256 hashes stayed
unchanged across verify, mutation, and restoration.

`swift test` passed 179 tests in 23 suites with zero unexpected failures and one
intentional known issue in LoaderSpyTests (`reports an expectation dropped by a
later arm`). Existing rendering/identity/whitespace/source-update tests remain
unchanged. `git diff --check` passed. The unrelated untracked work ledger remains.

These snapshots qualify the listed omission fixtures only. They do not establish
live policy transitions, VoiceOver, gestures, selection, constrained-host quote
sizing, minimum-OS support, or running-demo behavior. Discover a local simulator
with `sweetpad devices`; the identifier above records this run only.

### Nested-container qualification (ticket 04)

`FlatMarkNestedContainerSnapshotTests` owns ten PNGs in `NestedContainers`:
narrow/wide nested quotes, narrow/wide mixed lists, and an enlarged list on each
platform. Public `FlatMarkView` renders local Markdown and a synchronous indigo
44×30pt inline replacement. No loader or navigation is involved.

Qualified with Xcode 27.0 / Swift 6.4, macOS 27.0.1 on a 2x display, and iPhone
18 Pro on iOS 27.0. Enlarged text uses `.accessibility3` on iOS and a 28pt font
override on macOS, not macOS system Dynamic Type. All captures have a fixed size
larger than their content. Intrinsic vertical sizing keeps flexible quote rules
from consuming the offered capture height; constrained-host sizing is excluded.

Exact commands ran from the repository root, serially. Logs, rejected initial
captures, hashes, and xcresults remain local under `/tmp/flatmark-ticket04/`.

```sh
(cd Demo && xcodegen generate)

# Initial recording used the smaller-margin fixture and an RTL list variant.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS-Record --on mac --only-testing FlatMarkSnapshots-macOS/FlatMarkNestedContainerSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket04/mac-record.xcresult
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS-Record --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --only-testing FlatMarkSnapshots-iOS/FlatMarkNestedContainerSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket04/ios-record.xcresult

# Run each phase separately; pause for review, hashing, or mutation between phases.
for phase in margin-record verify mutation final; do
  for platform in macOS iOS; do
    dest=mac
    [ "$platform" = iOS ] && dest=674C04A9-8792-4995-A6A9-66F80E5F96AA
    scheme=FlatMarkSnapshots-$platform
    [ "$phase" = margin-record ] && scheme=$scheme-Record
    sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme "$scheme" --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkNestedContainerSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket04/$platform-$phase.xcresult
  done
done

# Before verify, then again after final (substitute after.sha256):
find Tests/References/Snapshots/NestedContainers -name '*.png' -exec shasum -a 256 {} \; | sort > /tmp/flatmark-ticket04/before.sha256
diff -u /tmp/flatmark-ticket04/before.sha256 /tmp/flatmark-ticket04/after.sha256
swift test
git status --short
git diff --check
```

Initial macOS review rejected a narrow list background reaching the capture edge
and an RTL capture losing text at the left edge. Those images are not accepted
references. The final fixture provides 100pt insets and wider capture bounds,
and selects the permitted enlarged variant instead of RTL. The bounded RTL
investigation below demonstrates list overflow; it is not an accepted baseline.
Constrained-host overflow remains unqualified. Rejected initial images remain in
`initial-unaccepted/` outside the repository. The final references preserve
FlatMark's flattened list layout.

The implementation worker opened every final PNG with the image reader:

| PNG test stem | macOS review | iOS review |
| --- | --- | --- |
| `narrowNestedQuote` | All numbered lines, inner/outer endings, replacement and after paragraph visible; rules end with content; clear margins. Accepted. | Same checks; more wrapping, no lost lines or clipping. Accepted. |
| `wideNestedQuote` | Wider wrapping; all quote wording and both rules complete; clear margins. Accepted. | Wider wrapping; complete numbered lines and endings; rules not stretched; clear margins. Accepted. |
| `narrowListContinuations` | Three nesting levels visible; paragraph, quote and code follow final child and align with parent content; next parent and after text intact; clear margins. Accepted. | Same order/alignment; all wrapped wording and code visible; clear margins. Accepted. |
| `wideListContinuations` | Less wrapping; continuation origins align with parent content; quote rule and code complete; clear margins. Accepted. | Same order/alignment; both code lines and after paragraph visible; clear margins. Accepted. |
| `enlargedListContinuations` | Larger text wraps; nested indentation visible; continuations align with parent, not child; rule ends with quote; clear margins. Accepted. | Real enlarged Dynamic Type; deeper rows and wrapped code intact; continuation order/alignment retained; clear margins. Accepted. |

Both final recording runs selected five tests and reported five expected recording
assertions, with no native capture failures. Separate `verify` runs passed five
tests per platform. Mutation removed `Line four must remain visible too.` and its
hard break from the quote. Both normal schemes reported two genuine image
mismatches and three passing list tests. Restored the line before `final`; five
tests passed per platform. All ten reference SHA-256 hashes stayed unchanged
through verification, mutation, and restoration.

#### Bounded RTL investigation and list mutation probes

The generous-bounds captures demonstrate **renderer list overflow**, not merely
capture placement. A red 1pt border marks the offered 240pt document frame.
Both RTL captures show the paragraph and quote text, and the code-block
background, outside its left edge. All wording reappears intact with 400pt outside padding and no ink
touches an image edge. Enlarging the capture recovers ink; it does not make that
ink fit the offered column. The before/after paragraphs stay inside the border.
The LTR controls also overflow, to the right, but lose no wording with these
bounds. Thus a clean inline-flow capture does not establish list correctness.
This establishes an out-of-column drawing defect, not its precise internal
alignment-guide cause. No hosting-view intrinsic-width measurement was taken.

Durable evidence, visually inspected on both platforms, is in
`AI-docs/prds/ui-snapshot-testing/evidence/`:

- `defect-rtl-list-rtl-macOS.png` and `defect-rtl-list-rtl-iOS.png`:
  complete RTL mixed list with visible left overflow.
- `defect-rtl-list-ltr-macOS.png` and `defect-rtl-list-ltr-iOS.png`:
  identical LTR controls with visible right overflow.

Blocked criterion: RTL list content and continuations must fit the offered
reading column without clipping. A **separate bounded production fix is
required**. No production code changed, no RTL baseline was added, and none of
these diagnostic images is an accepted reference. Nesting-depth scaling and
isolated continuation-type causes remain unmeasured.

Exact diagnostic Markdown (three spaces for parent continuations, five before
the grandchild marker):

````markdown
Before the mixed list.

1. Parent opening wraps with enough wording to expose the content alignment.
   - Child bullet wraps across the narrow reading column.
     1. Grandchild numbered row.
   - Final child bullet.

   Parent continuation follows all child rows and wraps onto another line.

   > Parent quote follows the continuation paragraph and keeps its own rule.

   ```swift
   let ready = true
   render(ready)
   ```

2. Next parent row ends the list.

After the mixed list.
````

A temporary `rtlInvestigation()` test captured this exact source in both
`.leftToRight` and `.rightToLeft`. It used `FlatMarkView(markdown: Self.list)`
with `.fixedSize(horizontal: false, vertical: true)`, then
`.frame(width: 240, alignment: .leading).border(.red, width: 1)`.
It called `flatMarkSnapshotImage` directly, not snapshot recording/comparison,
and exported PNG data. Shared capture support was unchanged. Environment:
1240×2100pt capture, 240pt column, 400pt inset, requested pixel scale 2,
light, `en_US`, body (`.large`, 13pt macOS / 17pt iOS font override).
The native macOS diagnostic export is 1240×2100 pixels (1x); the iOS export
is 2480×4200 pixels (2x). These diagnostics establish geometry, not new
scale-qualified baselines. The temporary test was removed after export.

Two separate VERIFY-only list probes then ran:

| Phase | Temporary change | Observed result on each platform |
| --- | --- | --- |
| `list-order` | Move the parent paragraph continuation before `- Final child bullet.`, with blank lines around the paragraph. | `narrowListContinuations`, `wideListContinuations`, and `enlargedListContinuations` mismatched; both quote tests passed. |
| `list-indent` | Restore order, then add two spaces to the parent paragraph continuation (three to five Markdown spaces), nesting it under the final child. | The same three list references mismatched; both quote tests passed. |
| `corrections-final` | Restore the original fixture byte-for-byte. | Five tests passed on each platform. |

Exact commands for the correction runs (each phase ran separately, one capture
process at a time; no Record scheme was used):

```sh
shasum -a 256 Tests/References/Snapshots/NestedContainers/*/*.png > /tmp/flatmark-ticket04/corrections-before.sha256
for phase in rtl-investigation list-order list-indent corrections-final; do
  for platform in macOS iOS; do
    dest=mac
    [ "$platform" = iOS ] && dest=674C04A9-8792-4995-A6A9-66F80E5F96AA
    sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkNestedContainerSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket04/$platform-$phase.xcresult
  done
 done
shasum -a 256 Tests/References/Snapshots/NestedContainers/*/*.png > /tmp/flatmark-ticket04/corrections-after.sha256
diff -u /tmp/flatmark-ticket04/corrections-before.sha256 /tmp/flatmark-ticket04/corrections-after.sha256
```

`rtl-investigation` passed six tests per platform (the five accepted tests plus
the temporary diagnostic). Each mutation reported two passes and three genuine
image mismatches. Restoration passed five per platform. SHA-256 comparison
returned no differences: all ten accepted PNGs remained byte-identical. The
fixture file also matched its pre-investigation copy after restoration.

Historical source was **not recovered with enough evidence to identify the exact
failing fixture**. Searches covered `git log --all` (quote/truncation messages and
wording changes), `Tests/README.md`, Recipe Lab guide history and fixture history,
`AI-docs/prds/ui-snapshot-testing/evidence/`, and `Tests/References/RecipeLab/`.
History mentions truncation of “kneading” and later rewritten wording, but does
not tie an exact original source and host configuration to the failure. The
current evidence directory contains consecutive-break images, not that quote.
These tests use a new long multiline regression fixture. They do not establish
that the historical macOS defect is fixed.

`swift test` passed 184 tests in 24 suites with one intentional known issue in
LoaderSpyTests and no unexpected failures. Existing projector and rendering tests
remain unchanged. `git diff --check` passed; the unrelated untracked work ledger
remains. These mounted snapshots do not qualify running-demo interaction (not
exercised), live VoiceOver, gestures, selection, minimum OS versions, RTL lists,
or vertically constrained quote hosts.

### Table qualification (ticket 05)

`FlatMarkTableSnapshotTests` owns fourteen references in `Tables`: wide long cells,
narrow leading/trailing viewports, enlarged long cells, a public header-only GFM
table, an empty internal table between paragraphs, and a visible public table
between the same paragraphs, on each platform. The empty fixture inserts a
`FlatMarkRenderTable(header: [], rows: [])` into a projected document. It is an
internal fixture, not a claim that public Markdown parses into an empty table.
Existing eligibility, parser span, blank-cell, and uneven-cell tests remain unchanged.

Qualified with Swift 6.4, Xcode 27.0, macOS 27.0.1 on the 2x display, and iPhone
18 Pro on iOS 27.0. iOS enlarged text uses `.accessibility3`; macOS uses a 28pt
font override, not system Dynamic Type. Fixed captures provide 100pt outside
insets and intrinsic vertical document sizing. The initial 1400pt enlarged iOS
capture was too short and was rejected. The final enlarged capture is 1900pt
high on both platforms; every final cell bottom and the bottom rule are visible.
No production defect was established or accepted as a reference.

The suite-local native scroll-view lookup selects the horizontal overflowing
scroll view. Leading is exactly 0pt. Trailing is exactly 400pt on each platform:
four fixed 160pt columns give 640pt of content, minus the 240pt viewport.
The hook computes the target offset from mounted document/content width minus
viewport width, sets it without animation, lays out/displays, then yields once.
After that final yield it reads the achieved native offset back
(`contentView.bounds.origin.x` on macOS, `contentOffset.x` on iOS) and requires an
exact match with 0/400pt, together with the 640pt content and 240pt viewport
geometry. A missing scroll view or a mismatch fails and reports the case, the
intended and achieved offset, and both widths. That read-back proves the native
position at the sampled instant, not completed drawing; pixel review establishes
which content drew. The default capture path has no added awaits or layout passes.

Commands ran serially from the repository root. Logs, rejected initial output,
hashes, and xcresults remain local under `/tmp/flatmark-ticket05/`.

```sh
(cd Demo && xcodegen generate)

# Each phase ran separately, with review or fixture edits between phases.
# Initial mac-record failed compilation; mac-record2 and ios-record recorded
# seven expected assertions each. final-record corrected capture height only.
for phase in final-record verify-Table short-cell fill-blank empty-mutation restored offset-final; do
  for platform in macOS iOS; do
    dest=mac
    [ "$platform" = iOS ] && dest=674C04A9-8792-4995-A6A9-66F80E5F96AA
    scheme=FlatMarkSnapshots-$platform
    [ "$phase" = final-record ] && scheme=$scheme-Record
    sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme "$scheme" --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkTableSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket05/$platform-$phase.xcresult
  done
 done

# Regression guard: all four existing suites, separate filtered verify runs.
for platform in macOS iOS; do
  dest=mac
  [ "$platform" = iOS ] && dest=674C04A9-8792-4995-A6A9-66F80E5F96AA
  for suite in LinkedImage InlineFlow OmissionSpacing NestedContainer; do
    sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMark${suite}SnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket05/$platform-verify-$suite.xcresult
  done
 done

shasum -a 256 -c /tmp/flatmark-ticket05/existing-before.sha256
find Tests/References/Snapshots/Tables -name '*.png' -exec shasum -a 256 {} \; | sort > /tmp/flatmark-ticket05/tables-after.sha256
diff -u /tmp/flatmark-ticket05/tables-before.sha256 /tmp/flatmark-ticket05/tables-after.sha256
swift test
git status --short
git diff --check
```

Every final reference was opened with the image reader. The following rows each
cover two PNGs (one per platform), named by their test stem:

| PNG test stem | macOS review | iOS review |
| --- | --- | --- |
| `wideLongCells` | Four headers, both long endings, blank cells, formatting, and complete outer/row rules visible; clear margins. Accepted. | Same checks with more wrapping; no hidden bottom glyphs. Accepted. |
| `narrowLeading` | Complete first column and left/top/bottom boundaries; partial second column at viewport edge, as expected. Outside margins clear. Accepted. | Same checks; FIRST END visible above the row boundary. Accepted. |
| `narrowTrailing` | Complete last column, LAST END, last body cell, right/top/bottom boundaries; partial third column at viewport edge. Accepted. | Same checks; no missing final glyphs or bottom rule. Accepted. |
| `enlargedLongCells` | Two complete visible columns, FIRST END and formatted second-row content intact; full bottom rule and margins. Accepted. | Larger Dynamic Type wraps and hyphenates; FIRST END and code ending intact; bottom rule and generous bottom margin visible. Accepted. |
| `headerOnly` | Both headers and all four outer boundaries visible; clear margins. Accepted. | Both headers and complete boundary visible; clear margins. Accepted. |
| `emptyInternalTableBetweenNeighbors` | Both paragraphs intact with ordinary neighbor spacing; no table ink or extra slot. Accepted. | Same checks; no unexpected gap or rule. Accepted. |
| `visiblePublicTableBetweenNeighbors` | Same paragraphs surround a visible one-cell header table; boundary complete. Accepted. | Same checks; both neighbor gaps and complete boundary visible. Accepted. |

Final explicit recording reported seven expected recording assertions per
platform, with no native capture/readiness failure. Separate `verify-Table` runs
passed seven tests each. Existing LinkedImage (2), InlineFlow (5), OmissionSpacing
(3), and NestedContainer (5) verify tests all passed on each platform. All 36
existing reference hashes stayed byte-identical. All fourteen new reference
hashes stayed unchanged through verify, mutations, restoration, and final runs.

VERIFY-only mutation probes produced these results on **each** platform:

| Probe | Mismatched references | Passed references |
| --- | --- | --- |
| Shorten both long end-column body cells to FIRST END / LAST END, reducing row height | wide, narrow leading, narrow trailing, enlarged | header-only, empty internal, visible control |
| Restore long cells; fill the authored first-column blank with FILLED BLANK | wide, narrow leading, enlarged | narrow trailing, header-only, empty internal, visible control |
| Restore blank; replace empty internal table with a one-cell MUTATED TABLE header | empty internal | all six other references |

Each mutation was removed before the next probe. The full fixture was restored
byte-for-byte before `restored`; seven tests passed per platform. `offset-final`
then added the explicit 0/400pt expectations and again passed seven per platform.
No mutation used recording. `swift test` passed 191 tests in 25 suites, with one
intentional LoaderSpyTests known issue and no unexpected failures.

**Running-app scroll check: NOT PERFORMED on either platform.** Both existing
demo schemes built and launched through `sweetpad run --detach --non-interactive`
with the same project/destinations. iOS runtime UI inspection exposed only the
outer document scroll area, Settings, and Markdown source. A Settings tap reported
success but the next UI inspection still showed the same targets; no table
horizontal scroll gesture or trailing-cell observation was obtained within the
bounded attempt. No macOS gesture-driven observation was obtained; the available
UI automation lane was simulator-based. Launch success and deterministic
snapshot offsets do not verify actual gesture reachability. That ticket criterion
remains unverified. Minimum-OS behavior, VoiceOver, selection, and vertically
constrained hosts are also outside this qualification.

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
