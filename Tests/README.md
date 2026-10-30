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

### macOS color-space qualification (ticket 10b)

The macOS capture helper converts the flattened native bitmap to named
`NSColorSpace.sRGB` (embedded profile `sRGB IEC61966-2.1`) before returning an
`NSImage` with an explicit bitmap representation. sRGB is standard and independent
of a particular monitor. The old references embedded the disconnected display's
`LG ULTRAFINE` profile; captures on the replacement display embedded `Display P3`.
The conversion changes encoding, not comparison: exact SnapshotTesting comparison
and `assertFlatMarkSnapshot` are unchanged. No tolerance was added.

Only the macOS branch changed. The three layout passes, mounted-view hook, native
capture failure, background flattening, and point size remain intact. Conversion
failure also throws `FlatMarkSnapshotCaptureError.unavailable`.

Qualified on Xcode 27 / Swift 6.4, macOS 27.0.1 with a 2x hosting display. Logs,
reference hashes, review contact sheets, and result bundles are retained locally
under `/tmp/flatmark-10b/`, not in the repository.

```sh
# Authorized full macOS re-record. Exit 3: 62 expected recording assertions,
# producing all 72 references across the ten suites.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS-Record --on mac --non-interactive --result-bundle /tmp/flatmark-10b/mac-record.xcresult

# Consecutive non-recording runs. Each exited 0: 62 tests passed.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac --non-interactive --result-bundle /tmp/flatmark-10b/mac-verify1.xcresult
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac --non-interactive --result-bundle /tmp/flatmark-10b/mac-verify2.xcresult

# Profile inspection: 72 entries, all sRGB IEC61966-2.1.
for f in $(find Tests/References/Snapshots -path '*/macOS/*' -name '*.png'); do sips -g profile "$f"; done | grep 'profile:' | sort | uniq -c

# iOS guard: exit 0, no differences across all 72 iOS PNGs.
find Tests/References/Snapshots -path '*/iOS/*' -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-10b/ios-after.txt
diff /tmp/flatmark-10b/ios-baseline.txt /tmp/flatmark-10b/ios-after.txt

# Mutation probe: exit 3, two genuine snapshot mismatches with reference/actual
# paths and xcresult comparison attachments. No reference was recorded.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac --only-testing FlatMarkSnapshots-macOS/FlatMarkLinkedImageSnapshotTests --non-interactive --result-bundle /tmp/flatmark-10b/mac-mutation.xcresult

# After restoring the mutation and reviewing the images: exit 0, 62 passed.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac --non-interactive --result-bundle /tmp/flatmark-10b/mac-final.xcresult

# Exit 0: 231 tests in 30 suites, one known issue, no snapshot failures.
swift test

# Build only; both exited 0. The iOS destination is this run's simulator.
sweetpad build --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkDemo-macOS --on mac --non-interactive
sweetpad build --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkDemo-iOS --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --non-interactive

git diff --check
```

The mutation temporarily wrapped the mounted macOS fixture in
`view.overlay(Text("MUTATION PROBE"))` in the capture helper. It was restored before
package tests, builds, and the final normal-scheme run. SHA-256 hashes of all 72
macOS references stayed unchanged through verification and mutation.

Visual review covered all 72 re-recorded images in per-suite contact sheets:
EmptyStructures, ImagePhases, InlineFlow, LinkedImage, NativePlaceholderFlow,
NestedContainers, OmissionSpacing, Tables, TaskMarkers, and UnsupportedPolicies.
Checked text and placeholders, blue links, purple custom replacements and task
markers, colored rasters, table rules and both scroll positions, outside margins,
and clipping. No new missing content or layout changes were found. A supplementary
foreground-mask comparison against the committed images found identical masks in
71 images; `customDisabled` differed by eight threshold-edge pixels after color
conversion. This inspection aid is not part of snapshot comparison.

The known NestedContainers list overflow outside the offered column remains;
this re-record does not fix or approve it as correct behavior. TaskMarkers still
has no RTL reference on either platform. No iOS recording ran. Cross-display
execution, minimum-OS behavior, forced native/conversion failure, live gestures,
and accessibility were not verified by this qualification.

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

### Image-phase qualification (ticket 06)

`FlatMarkImagePhaseSnapshotTests.swift` adds ten public-view cases per platform,
with 17 references each under `References/Snapshots/ImagePhases/{macOS,iOS}`.
The seven symbol cases each have a same-run hand-authored SwiftUI `control`.
Controls are independent plain SwiftUI contract fixtures; image captures exercise
the public renderer, `FlatMarkView`, and its real loading path.
No production or shared capture support changed. All loaders are local; the
`.invalid` Markdown URL is an identifier, not a network request.

Qualification used macOS 27.0.1 (26A434), Swift 6.4, and the iPhone 18 Pro
simulator on iOS 27.0. Captures offer a 200pt column inside 600×500pt bounds,
with 100pt insets, 2× scale, en_US, left-to-right, and body text. Body overrides
are 13pt on macOS and 17pt on iOS. This is not minimum-OS qualification.

Readiness has two gates. Loader bookkeeping must report completion for loaded
and failed cases. Then document size and mounted native descendant frames must
remain identical for five consecutive comparisons. The loop allows 100 attempts,
20ms apart. It records the fixture, environment, attempts, consecutive-stable
count, and all observed geometry on timeout. A failed gate prevents the
renderer-image assertion/recording. Controls are asserted before mounting the
renderer (suite lines 86–91); the readiness guard precedes the renderer-image
assertion (lines 125–129). A later timeout cannot undo a control recording.
Placeholder needs no loader. Held loading waits for request
start but deliberately keeps the operation outstanding. Geometry does not identify
phases, and completion does not prove drawing. Exact comparison against reviewed,
phase-specific references is the protection against premature captures.

The held loader polls its lock-protected release flag with cancellation-aware sleep.
A synchronous loader-exit `defer` marks completion without an intervening suspension.
Capture teardown cancels its task. Both the normal and throwing capture exits
also call `release()`; a readiness failure takes the throwing exit. Controls run
before any loader is mounted. Thus no early assertion, timeout, or capture error
can strand suspended work. This cleanup is not a new cancellation-behavior test.

#### Visual review

Every one of the 34 PNGs was opened with `read`. Rows below name both the `image`
and `control` PNG where present; each control was cross-checked against its image
in that platform's recording run. All content has clear capture-edge margins.
No URL text is shown. Loaded rasters replace the alt label rather than printing it.

| Case / PNGs on each platform | macOS review | iOS review | Coverage |
| --- | --- | --- | --- |
| `placeholder.image`, `.control` | Photo symbol, complete “Striped local diagram”; agrees with control | Same symbol and complete label; agrees with control | AC-10, no loader |
| `emptyAltPlaceholder.image`, `.control` | Photo plus “Image”; agrees with control | Photo plus “Image”; agrees with control | Generic fallback |
| `heldLoading.image`, `.control` | Clock plus descriptive label; agrees with control | Clock plus descriptive label; agrees with control | AC-10, outstanding request |
| `throwingFailure.image`, `.control` | Warning triangle, complete descriptive label; agrees with control | Warning triangle, complete descriptive label; agrees with control | AC-10, real thrown error |
| `emptyAltFailure.image`, `.control` | Warning triangle plus “Image”; agrees with control | Warning triangle plus “Image”; agrees with control | Failure generic fallback |
| `smallIntrinsicRaster.image` | Four-color 120×60pt raster, 2:1, below 200pt column width | Same intrinsic size and aspect | Intrinsic-size output |
| `oversizedRaster.image` | Complete four-color 200×100pt raster from 1000×500 source | Same fitted size and aspect | Narrow-proposal fit; outside margins expose overflow, not clipping into a fit |
| `mixedLoadedText.image` | 120×60pt raster below “Before the diagram”; trailing sentence below raster on one line | Same raster; trailing text wraps across two lines below it | Loaded responsive flow, no hidden overflow |
| `darkPlaceholder.image`, `.control` | Light photo symbol and complete label visible on black; agrees with control | White photo symbol and label visible on black; agrees with control | Dark symbol visibility |
| `darkFailure.image`, `.control` | Light triangle and complete label visible on black; agrees with control | White triangle and label visible on black; agrees with control | Dark failure visibility |

#### Runs and probes

Logs, mismatch attachments in xcresults, and hash manifests are retained locally
under `/tmp/flatmark-ticket06/`. Files prefixed `revised-` are this qualification;
earlier experiments and `unaccepted/` are not baselines. Explicit recording
failed the ten tests on each platform only because recording assertions are
expected. There were no readiness failures in those recording runs. A first
compile attempt failed because the shared mounted callback is nonthrowing; the
suite now records the diagnostic there and throws after capture instead.

Separate verify runs passed all ten tests on both platforms. After restoring all
probes, both platforms passed ten again. SHA-256 checks kept all 34 new and all
50 existing references byte-identical. Existing suite guards passed on both
platforms: LinkedImage 2, InlineFlow 5, OmissionSpacing 3, NestedContainer 5,
Tables 7. No reference was re-recorded for a probe.

The held-loader probe deliberately held all loaded/failure requests and bypassed
the completion gate to force comparison of a stable premature frame. On each
platform, all six loaded/failure image references mismatched, while the other
four cases and all controls passed. The probe released held work on exit. With
the hold removed and completion restored, all ten cases passed separately.
Evidence: `revised-{macOS,iOS}-held-probe.{log,xcresult}` and
`revised-{macOS,iOS}-released-probe.{log,xcresult}`. This proves that a stable
loading frame cannot pass the loaded/failure reference; it does not claim that
geometry recognized a phase.

A second, controlled delayed-success probe used the existing
`smallIntrinsicRaster.image` reference, in verify mode only. This was a temporary
change, not a new permanent case or reference. Immediately after `delivery.start()`
and the completion `defer`, its loader executed
`try await Task.sleep(for: .seconds(1))`, then returned the unchanged raster.
The condition was `phase == .loaded && !oversized && !mixed`; no other fixture
was delayed. One second is ten times the five 20ms stable-comparison intervals.
With both completion and quiescence gates unchanged and enabled, all ten tests
passed on each platform. The delayed small-raster test took 1.231s on macOS and
1.236s on iOS and matched its accepted loaded reference.

For the contrasting run, the same fixture and one-second delay stayed in place.
Only that fixture's completion predicate changed from `completed` to `started`;
the five-comparison quiescence gate remained enabled. On both platforms, exactly
`smallIntrinsicRaster.image` failed its loaded reference; the other nine tests
passed. Both commands exited 3 for the expected mismatch, not a readiness timeout.
Thus the same delayed fixture passes with completion readiness and fails without
it: request start plus stable geometry is not sufficient. Normal and throwing
exits still called `delivery.release()`, and capture teardown still cancelled its
task; the sleep was cancellation-aware. No cleanup path was bypassed.

The temporary delay, predicate change, and diagnostic print were removed.
`cmp` confirmed the suite matched its pre-probe copy at
`/tmp/flatmark-ticket06/correction-accepted.swift` byte-for-byte. No reference was
recorded or changed. Final `shasum -a 256 -c` checks passed for all 34 accepted
and all 50 existing references. Exact commands from the repository root:

```sh
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac --non-interactive --result-bundle /tmp/flatmark-ticket06/correction-macOS-delay-gated.xcresult --only-testing FlatMarkSnapshots-macOS/FlatMarkImagePhaseSnapshotTests
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --non-interactive --result-bundle /tmp/flatmark-ticket06/correction-iOS-delay-gated.xcresult --only-testing FlatMarkSnapshots-iOS/FlatMarkImagePhaseSnapshotTests
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac --non-interactive --result-bundle /tmp/flatmark-ticket06/correction-macOS-delay-start-only.xcresult --only-testing FlatMarkSnapshots-macOS/FlatMarkImagePhaseSnapshotTests
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --non-interactive --result-bundle /tmp/flatmark-ticket06/correction-iOS-delay-start-only.xcresult --only-testing FlatMarkSnapshots-iOS/FlatMarkImagePhaseSnapshotTests
```

Logs use the same stems with `.log` instead of `.xcresult`.

Verify-only mutations had identical results on both platforms:

| Mutation | Mismatched references | Unchanged references |
| --- | --- | --- |
| Change raster blue channel and small-raster aspect to 120×90 | Three loaded images: small, oversized, mixed | All 14 symbol/control references |
| Change descriptive alt to “Changed description” | Images and controls for placeholder, loading, failure, dark placeholder, dark failure (10) | Empty-alt images/controls and three loaded images (7) |
| Make the throwing loader succeed | Three failure images | Failure controls and every other reference (14) |

`swift test --filter FlatMarkImageLoadingTests` passed 17 tests in one suite.
`swift test` passed 201 tests in 26 suites with the existing intentional
LoaderSpyTests known issue. `swift test --list-tests` listed all 17 loading tests
and all ten new snapshot tests. Existing loading, numeric fitting, accessibility
phase-label, URL-policy, and loader-configuration tests remain unchanged.

Commands (one capture process at a time, from the repository root):

```sh
(cd Demo && xcodegen generate)
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS-Record --on mac --non-interactive --result-bundle /tmp/flatmark-ticket06/revised-mac-record2.xcresult --only-testing FlatMarkSnapshots-macOS/FlatMarkImagePhaseSnapshotTests
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS-Record --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --non-interactive --result-bundle /tmp/flatmark-ticket06/revised-ios-record.xcresult --only-testing FlatMarkSnapshots-iOS/FlatMarkImagePhaseSnapshotTests
# platform=macOS: dest=mac; platform=iOS:
# dest=674C04A9-8792-4995-A6A9-66F80E5F96AA
# suite=LinkedImage, InlineFlow, OmissionSpacing, NestedContainer, Table, ImagePhase
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --non-interactive --result-bundle /tmp/flatmark-ticket06/revised-$platform-verify-$suite.xcresult --only-testing FlatMarkSnapshots-$platform/FlatMark${suite}SnapshotTests
# Same command with suite=ImagePhase and result stem revised-$platform-$phase:
# phase=held-probe, released-probe, mutation-raster, mutation-alt,
# mutation-success, final-verify, gated-final-verify
shasum -a 256 -c /tmp/flatmark-ticket06/existing-before.sha256
shasum -a 256 -c /tmp/flatmark-ticket06/accepted.sha256
swift test --filter FlatMarkImageLoadingTests
swift test
swift test --list-tests
git status --short
git diff --check
```

These captures qualify fixture appearance and exact repeatability only. They do
not prove cancellation behavior, accessibility labelling, URL policy, live
VoiceOver, interaction, system Dynamic Type, or general running-app behavior.
Those claims stay with the existing test families and manual checks.

### Task-marker qualification (ticket 07)

`FlatMarkTaskMarkerSnapshotTests` owns nine public-view cases and eighteen PNGs
in `TaskMarkers/{macOS,iOS}`. Swift Testing serializes mounted cases. Shared
support performs exact comparison with no pixel tolerances. No production,
fixture, interaction, or source-preservation test changed.

Qualified with Xcode 27.0 (27A266a), Swift 6.4, macOS 27.0.1 (26A434) on the
2x display, and iPhone 18 Pro on iOS 27.0. Body captures offer a 280pt column
inside 700×650pt bounds with 150pt insets. Enlarged captures are 700×1500pt.
All use 2x, light, en_US, LTR, and intrinsic vertical document sizing.
iOS enlarged uses real `.accessibility3`; macOS uses a 28pt absolute font
override, not system Dynamic Type. Explicit `.body` marker fonts remain small
on macOS while the label enlarges; marker baselines still meet the first line.

The shared `FlatMarkFixtureTaskMark` is not reachable from these targets:
`Demo/project.yml` compiles only the Snapshots folder into each snapshot target.
The demo compiles fixture sources directly; it does not export a fixture module.
The local passive custom drawing uses purple filled checkmark circles / empty
circle outlines, instead of the default green checked squares / gray square
outlines. It adds no actions, gestures, or accessibility semantics.

#### Baseline review

The implementation worker opened **each of the eighteen PNGs with `read`**.
Each row names two individual PNGs, one in each platform directory. The filename
suffix records the environment above; every capture has clear image-edge margins.
All four states (checked/unchecked parent and checked/unchecked nested) remain
visible. The long unchecked nested label wraps below its first line without
moving its marker down. Nesting shifts the children inward in these LTR cases.

| PNG test stem | macOS review | iOS review |
| --- | --- | --- |
| `defaultInteractive` | Green filled checked squares and gray empty squares; first-line alignment, three-line child, indentation, margins intact. Accepted. | Same states/alignment; three-line child and indentation intact. Accepted. |
| `defaultReadOnly` | All squares retained; same appearance as interactive; baseline/wrap/margins intact. Accepted. | Same checks and appearance as interactive. Accepted. |
| `defaultDisabled` | All squares retained, visibly paler; text unchanged; baseline/wrap/indent/margins intact. Accepted. | All squares retained and paler; baseline/wrap/indent/margins intact. Accepted. |
| `customInteractive` | Purple filled checked circles and empty outlines; baseline/wrap/indent/margins intact. Accepted. | Same distinct circles and states; baseline/wrap/indent/margins intact. Accepted. |
| `customReadOnly` | All circles retained; same appearance as interactive; baseline/wrap/indent/margins intact. Accepted. | Same checks and appearance as interactive. Accepted. |
| `customDisabled` | All circles retained but paler purple; baseline/wrap/indent/margins intact. Accepted. | All circles retained but paler purple; baseline/wrap/indent/margins intact. Accepted. |
| `customRetainedDocument` | Intended purple drawings, identical to source-initializer custom capture; baseline/wrap/indent/margins intact. Accepted. | Same initializer equivalence and visible checks. Accepted. |
| `enlargedDefault` | Small body squares beside larger labels; markers stay on first baseline, complete five-line child and inward indentation; clear margins. Accepted. | Squares scale with Dynamic Type; parent/child labels wrap, complete eight-line long child, first-line markers and indentation retained. Accepted. |
| `enlargedCustom` | Small body purple circles beside larger labels; correct states, complete five-line child, first-line markers, inward indent and clear margins. Accepted. | Purple circles scale; correct states, complete eight-line long child, first-line markers, inward indent and clear margins. Accepted. |

Disabled appearance is an observation of the native plain-button environment,
not a new styling contract or proof of edit prevention. Read-only does not need
a distinct style. No special disabled styling was invented in the custom drawing.
`cmp` found source and retained custom PNGs byte-identical on each platform.
Default/custom interactive PNGs have equal 1400×1300 dimensions but different
bytes (first difference at byte 2941 on macOS, 604 on iOS). Visual review confirms
square/green-gray versus circle/purple; the difference is not merely metadata.

#### RTL diagnostic — blocked directional indentation

No RTL defect was blessed as a reference. A temporary `rtlInvestigation()` test
captured the exact suite Markdown, read-only default markers, with a red 1pt
border around the offered 280pt frame. It compared LTR/RTL environments with
1200×800pt bounds, 400pt inset, body text, light, en_US, requested 2x scale.
It exported directly after `flatMarkSnapshotImage`, without recording assertions.
Both normal schemes passed ten tests (nine accepted cases plus diagnostic).
The temporary test was removed; its source remains locally in
`/tmp/flatmark-ticket07/rtl-investigation.swift`.

All four diagnostic PNGs were opened with `read` and retained in
`AI-docs/prds/ui-snapshot-testing/evidence/` as
`defect-task-list-{leftToRight,rightToLeft}-{macOS,iOS}.png`.
**These are diagnostic evidence, not baselines.** macOS direct export is
1200×800 pixels (1x); iOS is 2400×1600 (2x). They establish geometry only.
All wording and all four square states are intact, first-line markers are visible,
and no ink touches the capture edges. This compact fixture does not reproduce
ticket 04's out-of-column continuation drawing. It exposes a different problem:
LTR child markers move right (inward), but RTL child markers also move right
(outward, toward the red right boundary), instead of left/inward. This happens
on both platforms. RTL directional indentation remains blocked and needs a
**separate bounded production fix** before accepting RTL task references.

#### Runs, regression guard, and mutation probes

All capture commands ran serially from the repository root. Logs, xcresults,
source copies, and SHA-256 manifests remain local under `/tmp/flatmark-ticket07/`.
Explicit recordings selected nine tests per platform and failed only with nine
expected recording assertions; no capture failures. Separate normal `verify`
and restored `final` runs each passed nine tests on each platform.

Before any recording, `existing-before.sha256` recorded all 84 existing PNGs.
The six existing suite guards passed on each platform: LinkedImage 2, InlineFlow 5,
OmissionSpacing 3, NestedContainer 5, Table 7, ImagePhase 10 tests.
`shasum -a 256 -c` kept all 84 byte-identical. All eighteen task PNG hashes stayed
unchanged through verification, diagnostics, mutations, restoration, and full tests.

VERIFY-only probes had the same results on both platforms:

| Probe | Temporary change | Mismatched references | Passed references |
| --- | --- | --- | --- |
| `state` | Flip checked parent from `[x]` to `[ ]` | All nine | None |
| `custom` | Replace purple circles with orange diamonds | customInteractive, customReadOnly, customDisabled, customRetainedDocument, enlargedCustom | defaultInteractive, defaultReadOnly, defaultDisabled, enlargedDefault |
| `indent` | Add two Markdown spaces before checked nested task, making it a grandchild | All nine (all include nesting) | None |

Each probe exited 3 for genuine comparison mismatches, not recording assertions.
Each previous change was removed before the next probe. `cmp` confirmed final
suite source matched `/tmp/flatmark-ticket07/accepted.swift` byte-for-byte.
No probe used a recording scheme.

Exact command patterns (each phase ran separately, with review or fixture edits
between phases; `platform=macOS` uses `dest=mac`, `platform=iOS` uses
`dest=674C04A9-8792-4995-A6A9-66F80E5F96AA`):

```sh
(cd Demo && xcodegen generate)
sweetpad devices
sw_vers
swift --version
xcodebuild -version
find Tests/References/Snapshots -name '*.png' -exec shasum -a 256 {} \; | sort > /tmp/flatmark-ticket07/existing-before.sha256
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS-Record --on mac --only-testing FlatMarkSnapshots-macOS/FlatMarkTaskMarkerSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket07/mac-record.xcresult
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS-Record --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --only-testing FlatMarkSnapshots-iOS/FlatMarkTaskMarkerSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket07/ios-record.xcresult
# phase=verify, rtl, state, custom, indent, final; both platforms, one at a time:
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkTaskMarkerSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket07/$platform-$phase.xcresult
# suite=LinkedImage, InlineFlow, OmissionSpacing, NestedContainer, Table, ImagePhase:
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMark${suite}SnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket07/$platform-guard-$suite.xcresult
find Tests/References/Snapshots/TaskMarkers -name '*.png' -exec shasum -a 256 {} \; | sort > /tmp/flatmark-ticket07/accepted.sha256
shasum -a 256 -c /tmp/flatmark-ticket07/existing-before.sha256
shasum -a 256 -c /tmp/flatmark-ticket07/accepted.sha256
swift test --list-tests
swift test --filter FlatMarkTaskMarkerTests
swift test --filter FlatMarkTaskMarkerToggle
swift test --filter FlatMarkListRowViewTests
swift test --filter FlatMarkCustomUnsupportedContentTests
swift test --filter FlatMarkOmissionLiveUpdateTests
swift test
git status --short
git diff --check
```

The listed package filters passed respectively 2 tests (6 argument cases),
11 tests in 4 suites, 4 tests, 20 tests in 2 suites, and 2 tests.
Full `swift test` passed 210 tests in 27 suites, with the existing intentional
LoaderSpyTests known issue and no unexpected failures. Existing marker/editing
and source-byte coverage remains unedited. Demo project regeneration included
the new suite; no target configuration or dependencies changed.

**Shared running-demo marker observation: NOT PERFORMED on either platform.**
Both demo schemes built and launched with the `hostMarkers` preset through
SweetPad. The simulator screenshot showed the top Recipe Lab controls and
recipe introduction, not tasks. The desktop screenshot showed the macOS demo
at the same introduction, partly behind the simulator. The bounded attempt did
not navigate to task content or operate marker variant controls. Thus launch
and initial-viewport observation succeeded, but marker observation remains
unverified rather than inferred from mounted captures. Local screenshots and
launch logs are under `/tmp/flatmark-ticket07/`.

```sh
sweetpad run --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkDemo-macOS --on mac --arg --capture --arg hostMarkers --detach --non-interactive
sweetpad run --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkDemo-iOS --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --arg --capture --arg hostMarkers --detach --non-interactive
xcrun simctl io 674C04A9-8792-4995-A6A9-66F80E5F96AA screenshot /tmp/flatmark-ticket07/ios-demo.png
screencapture -x /tmp/flatmark-ticket07/mac-demo.png
```
Snapshots do not establish hit-target size, keyboard activation, VoiceOver focus
order, edit prevention, minimum-OS behavior, or general running-app behavior.

### Unsupported-policy qualification (ticket 08)

`FlatMarkUnsupportedPolicySnapshotTests` owns eight cases and eight references per
platform in `UnsupportedPolicies/{macOS,iOS}`. Public views exercise literal,
custom, and omit policies; empty custom output; and ambient enabled/disabled
host controls. A set-based assertion requires the empty host to receive exact
opening, closing, and whole-block payloads. Re-evaluation counts are not asserted.
Existing payload, independent-action, enabled-environment, and no-HTML-fetch
coverage remains unchanged.

Qualified with Xcode 27 RC / Swift 6.4, macOS 27.0.1 on the 2x display, and
booted iPhone 18 Pro on iOS 27.0 (674C04A9-8792-4995-A6A9-66F80E5F96AA).
Captures use a 400pt column, 80pt inset, 640×550pt bounds, 2x, light, en_US,
LTR, body text (13pt macOS / 17pt iOS overrides), and intrinsic vertical sizing.
No production code or capture behavior changed. Project regeneration registers
the suite in both snapshot targets; the only shared-support edit adds its approved
namespace enum case.

#### Visual review

The implementation worker opened every recorded PNG with `read` at readable
scale. The table names both platform PNGs by test stem; every file has suffix
`.document-400col-80inset-640x550-2x-light-en_US-ltr-body.png`.

| Stem (macOS and iOS) | Observed checks |
| --- | --- |
| `literal` | Inert inline and whole-block HTML source visible; bold, italic neighbor, blue link, before/after wording intact. |
| `custom` | Indigo OPEN precedes middle/label, orange CLOSE follows each; one BLOCK drawing replaces the whole block. White monospaced host styling remains distinct from blue link text. Bold and italic neighbors survive. |
| `omit` | Tags and whole block absent; supported bold/italic and blue link wording retained. |
| `emptyLiteral` | `a<u></u>b`, HTML-only paragraph, and whole-block source all visible. |
| `emptyCustom` | Contiguous `ab`, no fallback, synthetic wording, or minimum host box; empty HTML-only paragraph retains a parent gap before the after paragraph. |
| `emptyOmit` | Contiguous `ab`; the HTML-only paragraph is recursively removed, so the after paragraph is closer than in empty custom. |
| `enabledHost` | Two white-on-indigo ENABLED controls occupy separate inline positions amid bold supported text. |
| `disabledHost` | Both controls read DISABLED with gray presentation; surrounding supported wording remains. |

All sixteen PNGs have clear outside margins and complete wording. No clipping
or known rendering defect was accepted. The initial fixture did not include the
HTML-only paragraph; it was added before final recording to distinguish retained
parent spacing from recursive omission. A whole-block EmptyView alone collapses
in these hosts; the contract does not require it to leave a gap.

#### Commands and outcomes

Runs were serial, from the repository root. Logs, source copy, manifests, and
xcresults remain under `/tmp/flatmark-ticket08/`. These command patterns describe
all phases (each phase ran separately, with review/edits between phases):

```sh
(cd Demo && xcodegen generate)
# platform=macOS: dest=mac; platform=iOS: dest=booted
# Explicit initial recording used mac-record / ios-record result stems.
# Final recording after the HTML-only paragraph was added:
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform-Record --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkUnsupportedPolicySnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket08/$platform-record-final.xcresult
# phase=verify, fallback, positions; normal schemes only:
find Tests/References/Snapshots -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-ticket08/$platform-$phase-before.sha256
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkUnsupportedPolicySnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket08/$platform-$phase.xcresult
find Tests/References/Snapshots -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-ticket08/$platform-$phase-after.sha256
diff -u /tmp/flatmark-ticket08/$platform-$phase-{before,after}.sha256
# final: same manifest guard, no --only-testing (all eight namespaces):
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --non-interactive --result-bundle /tmp/flatmark-ticket08/$platform-final.xcresult
shasum -a 256 -c /tmp/flatmark-ticket08/existing.sha256
cmp /tmp/flatmark-ticket08/accepted.swift Tests/FlatMarkTests/Snapshots/FlatMarkUnsupportedPolicySnapshotTests.swift
swift test
git diff --check
```

Both initial and final recordings reported eight expected recording assertions
per platform, with no capture failures. Separate `verify` runs passed eight each.
VERIFY-only fallback probes replaced EmptyView with `Text("FALLBACK WORDING")`:
only `emptyCustom` mismatched on each platform (seven passed). Restoring EmptyView
and exchanging OPEN/CLOSE labels caused only `custom` to mismatch (seven passed).
Both probes exited 3 for real image mismatches, not recording assertions. Source
restoration matched the saved copy byte-for-byte. Final full normal schemes passed
49 tests per platform: eight new and 41 across the seven existing namespaces.

Before/after manifests for every verify/probe/final run matched exactly. All 102
existing reference hashes and sixteen new reference hashes stayed unchanged.
Normal schemes never wrote references. Missing-reference behavior relies on the
unchanged ticket 01 support contract; this ticket did not repeat that probe.
Full `swift test` passed 218 tests in 28 suites with one existing intentional
LoaderSpyTests known issue and no unexpected failures. `git diff --check` passed.

These are mounted appearance and repeatability checks, not running-demo or
callback observations. No new iOS action activation, live VoiceOver, keyboard,
selection, minimum-OS, or general running-app behavior was verified. Exact
payload and independent activation claims remain with existing behavioral tests;
full package testing runs their macOS lane, not iOS interaction.

### Empty-structure qualification (ticket 09)

`FlatMarkEmptyStructureSnapshotTests` owns five public-view cases and five PNGs
per platform in `EmptyStructures/{macOS,iOS}`. All use local Markdown with `.omit`,
serialized Swift Testing, and exact comparison. No production or existing test
changed. The only shared-support change adds the approved namespace case;
XcodeGen registers the new file in both targets.

Qualified in the established Xcode 27 RC / Swift 6.4 lane: macOS 27.0.1 on the
2x display and booted iPhone 18 Pro on iOS 27.0. Captures offer a 340pt column,
100pt inset, 560×450pt bounds (560×950pt enlarged), 2x, light, en_US, LTR, and
intrinsic vertical sizing. iOS enlarged uses `.accessibility3`; macOS uses a
28pt font override, not system Dynamic Type.

The implementation worker opened every one of the ten recorded PNGs with `read`.
Each row below names both platform references by test stem:

| Stem | Visual review on macOS and iOS |
| --- | --- |
| `emptyTaskInteractive` | Empty gray square visibly retained above green checked neighbor; no synthetic label or HTML ink. |
| `emptyTaskReadOnly` | Same visible empty square and checked neighbor without a callback. |
| `authoredOrderedRows` | `7.` remains in its empty first row; `8.` precedes `keep` in the next row. |
| `omittedTableCells` | A/B columns retained; `keep` stays right, `left` stays left; fully empty third body row remains above last/end; outer boundary and horizontal row rules complete. No internal vertical rules are promised. |
| `enlargedEmptyTask` | Empty square retained; checked neighboring wording wraps into three lines on macOS and five on iOS; all wording and both markers intact. |

All references have clear outside margins. These compact LTR fixtures do not
include the known overflowing list continuations or RTL indentation defects.
No new clipping or rendering defect was accepted.

Commands ran serially from the repository root. Logs, xcresults, accepted source
copy, and manifests remain local under `/tmp/flatmark-ticket09/`:

```sh
(cd Demo && xcodegen generate)
find Tests/References/Snapshots -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-ticket09/existing.sha256
# platform=macOS: dest=mac; platform=iOS: dest=booted
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform-Record --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkEmptyStructureSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket09/$platform-record.xcresult
# Run each phase separately, with the probe edit/restoration between phases.
# phase=verify, probe: filter shown below. phase=final: omit --only-testing.
find Tests/References/Snapshots -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-ticket09/$platform-$phase-before.sha256
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkEmptyStructureSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket09/$platform-$phase.xcresult
find Tests/References/Snapshots -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-ticket09/$platform-$phase-after.sha256
diff -u /tmp/flatmark-ticket09/$platform-$phase-{before,after}.sha256
shasum -a 256 -c /tmp/flatmark-ticket09/existing.sha256
cmp /tmp/flatmark-ticket09/accepted.swift Tests/FlatMarkTests/Snapshots/FlatMarkEmptyStructureSnapshotTests.swift
swift test
git diff --check
```

An initial macOS compile attempt (`mac-record`) caught initializer argument order;
no references were written by that attempt. Corrected explicit recordings
(`macOS-record`, `iOS-record`) each reported five expected recording assertions,
with no capture failures. Separate `verify` runs passed five tests per platform.
The VERIFY-only probe changed the ordered source to `9.` / `10.`. Each platform
reported one genuine ordered-row mismatch and four passes, not recording failures.
Restoration matched the saved source byte-for-byte. Full normal `final` runs
passed 54 tests per platform: five new and 49 across the eight existing namespaces.
Every verify/probe/final before/after manifest matched. All 118 existing PNGs and
ten new PNGs stayed byte-identical; verify mode wrote no references.
Missing-reference behavior relies on the unchanged ticket 01 contract, not a
repeated probe here.

Full `swift test` passed 223 tests in 29 suites with one existing intentional
LoaderSpyTests known issue and no unexpected failures. Existing byte-exact task
updates, omitted-label activation, and list/table projection assertions remain
intact. `git diff --check` passed.

All ticket 09 appearance criteria pass for these reviewed fixtures. These are
mounted appearance and repeatability checks, not live callback, running-demo,
VoiceOver, keyboard, selection, minimum-OS, or general overflow qualification.
No new iOS activation or macOS system Dynamic Type observation was performed.

### Native-placeholder qualification (ticket 10)

`FlatMarkNativePlaceholderFlowSnapshotTests` adds eight public-view cases and
sixteen PNGs in `NativePlaceholderFlow/{macOS,iOS}`. Each fixture runs at 160pt
and 320pt columns, with standard and enlarged text: four wrapping cases and four
hard-break cases. Swift Testing serializes the suite. The unlinked relative image
and absent loader/custom policy keep `renderingMode` in `inlineText`: no linked
image or custom-flow branch applies, and no loaded phase can arise. Inspection
traced `inlineText` through `labeledImageText` (photo symbol plus alt label).
The two existing native fitted-size proxy tests remain unchanged.

Qualified with Xcode 27 RC / Swift 6.4, macOS 27.0.1 on the 2x display, and
booted iPhone 18 Pro on iOS 27.0. All captures are fixed 520×1500pt, 80pt inset,
2x, light, en_US, LTR, with intrinsic vertical document sizing. macOS standard
uses a 13pt absolute font override; enlarged uses 28pt, not system Dynamic Type.
iOS standard uses a 17pt override at `.large`; enlarged removes the absolute
font override and uses real `.accessibility3` Dynamic Type.

The implementation worker opened every recorded PNG with `read` at readable
scale. These stems identify all eight files in **each** platform directory:

| Stems | Review on both platforms |
| --- | --- |
| `narrowStandardWrapping`, `wideStandardWrapping` | Photo symbol, complete Diagram label, introduction, and final “after it.” visible; narrower column wraps more. |
| `narrowEnlargedWrapping`, `wideEnlargedWrapping` | Visibly larger glyphs and more rows; all wording and symbol intact. Native wrapping can separate symbol and label across rows. |
| `narrowStandardHardBreaks`, `wideStandardHardBreaks` | Short “A” line above photo symbol and D label; “A diagram explanation continues to its final words.” starts below; all wording intact. |
| `narrowEnlargedHardBreaks`, `wideEnlargedHardBreaks` | Same three-part break structure at larger effective text; symbol and D stay together; complete trailing sentence. |

All sixteen references have clear outside margins, nonempty drawn wording and
symbols, and no clipping. No defect baseline was accepted. All PNGs have identical
1040×3000 pixel dimensions; SHA-256 comparison found eight distinct hashes per
platform. Thus narrow/wide and standard/enlarged differences are not explained
by different canvas sizes. Exact comparison to these reviewed nonempty references
rejects collapsed output; this suite does not compare two potentially empty views.

Commands ran serially from the repository root. Logs, xcresults, source copy, and
before/after manifests remain locally under `/tmp/flatmark-ticket10/`:

```sh
(cd Demo && xcodegen generate)
find Tests/References/Snapshots -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-ticket10/existing.sha256
# platform=macOS: dest=mac; platform=iOS: dest=booted
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform-Record --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkNativePlaceholderFlowSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket10/$platform-record.xcresult
# phase=verify, break-probe, label-probe; each phase ran separately after edits/review:
find Tests/References/Snapshots -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-ticket10/$platform-$phase-before.sha256
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkNativePlaceholderFlowSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket10/$platform-$phase.xcresult
find Tests/References/Snapshots -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-ticket10/$platform-$phase-after.sha256
diff -u /tmp/flatmark-ticket10/$platform-$phase-{before,after}.sha256
# final uses the same manifest guard, without --only-testing:
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --non-interactive --result-bundle /tmp/flatmark-ticket10/$platform-final.xcresult
shasum -a 256 -c /tmp/flatmark-ticket10/existing.sha256
cmp /tmp/flatmark-ticket10/accepted.swift Tests/FlatMarkTests/Snapshots/FlatMarkNativePlaceholderFlowSnapshotTests.swift
swift test
git diff --check
```

Explicit recordings each selected eight tests and reported eight expected recording
assertions, with no native capture failures. Separate normal verify runs passed
eight per platform. VERIFY-only `break-probe` replaced the first hard break with
a space: macOS wide enlarged mismatched (seven passed); all four iOS hard-break
cases mismatched (four passed). At the other macOS settings natural wrapping
masked the removed break. After restoring that break, `label-probe` changed both
fixtures' alt label to Changed label: eight genuine mismatches per platform.
Both probes exited 3, not recording assertions. Restored source matched the saved
copy byte-for-byte. Full normal final runs passed 62 tests per platform: eight
new and 54 across all nine existing namespaces. Every before/after verification
manifest matched; all 128 existing and sixteen new reference hashes stayed
unchanged. No probe used recording or updated references.

Full `swift test` passed 231 tests in 30 suites, with one existing intentional
LoaderSpyTests known issue and no unexpected failures. `git diff --check` passed.
Round 1 did not qualify independent sensitivity to both authored hard breaks. The round-2 evidence below supersedes its hard-break probe and acceptance conclusion. These mounted images
do not establish selection gestures, semantic selectability, VoiceOver, keyboard,
minimum-OS behavior, running-demo behavior, or macOS system Dynamic Type.
Existing link, alt-policy, whitespace, and semantic tests remain intact.

#### Round 2: independent hard-break qualification

The repaired hard-break fixture is:

```markdown
A\
![D](image.png)\
A diagram explanation continues to its final words.
```

Short boundary wording leaves room for content to join when either break is removed.
The wrapping fixture, native no-loader `inlineText` path, and fixed 520×1500pt
capture remain unchanged. Only the eight `HardBreaks` references were re-recorded.
The worker opened each changed PNG with `read`: the first A, photo symbol, D,
second A, and complete final sentence are visible, with both authored boundaries
and ample outside margins. No clipping or defect baseline was accepted.

Evidence and the executable command wrapper are in
`/tmp/flatmark-ticket10/round2/` (`run.sh`, `accepted.swift`, platform-phase logs,
unique xcresults, and full before/after SHA-256 manifests). Commands used the
same lanes above. Recording selected each `HardBreaks()` method explicitly;
verify and probes selected the whole suite; final runs were unfiltered.
An initial recording filter without `()` selected zero tests and changed nothing;
it is not verification evidence. Corrected explicit recordings each selected four
tests and produced four expected recording assertions (exit 3), not comparison
failures.

Each probe replaced only one authored break with a space. The other break remained
intact. All entries below are genuine non-recording reference mismatches (exit 3):

| Reference stem | macOS before removal | macOS after removal | iOS before removal | iOS after removal |
| --- | --- | --- | --- | --- |
| `narrowStandardHardBreaks` | mismatch | mismatch | mismatch | mismatch |
| `wideStandardHardBreaks` | mismatch | mismatch | mismatch | mismatch |
| `narrowEnlargedHardBreaks` | mismatch | mismatch | mismatch | mismatch |
| `wideEnlargedHardBreaks` | mismatch | mismatch | mismatch | mismatch |

These are the corresponding `document-…png` references in
`Tests/References/Snapshots/NativePlaceholderFlow/<platform>/`. Each of the four
probe runs had four genuine mismatches and four wrapping passes. No probe recorded
or changed references. Restored source matches `round2/accepted.swift` byte-for-byte.
Separate restored non-recording verify runs passed eight tests on each platform.
Subsequent full unfiltered lanes passed 62 tests each. All before/after manifests
for probes, verifies, and final runs matched exactly. The original 128 references
remain byte-identical, as do the eight wrapping references from round 1. The final
sixteen hashes are retained in `round2/final-native.sha256`; each platform still
has eight distinct references on the same 1040×3000 pixel canvas.

Full round-2 `swift test` passed 231 tests in 30 suites with one existing intentional
LoaderSpyTests known issue and no unexpected failures. Its reference manifests
also matched. `git diff --check` passed.

**Acceptance:** PASS for independent drawn sensitivity to each authored break at
all four captured settings on both platforms, complete visible placeholder content,
and the reviewed fixed-canvas appearance at those settings. This is not a claim
that all possible appearance or interaction criteria pass. Selection gestures,
semantic selectability, VoiceOver, keyboard, minimum-OS behavior, running-demo
behavior, and macOS system Dynamic Type remain unverified by these captures.

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
