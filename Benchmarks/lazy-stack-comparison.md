# Top-level lazy-stack comparison

## Decision

The lazy candidate substantially reduces initial mounting of long, many-block documents. Initial
checks appeared to identify macOS reflow and image-lifecycle regressions. **Follow-up debugging traced
those two isolated failures to the test host's automatic maximum sizing**, not the renderer. See
[the follow-up](#follow-up-test-host-sizing-and-group-experiment).

The renderer was restored after measurement, then reapplied at the user's request for a documentation
commit. The lazy candidate remains in the working tree. The full suite is still not green; do not
treat the two repaired checks as complete lazy-rendering qualification.

The measured candidate is retained as
[`top-level-lazy.patch`](Construction/Baselines/lazy-comparison/top-level-lazy.patch). It makes only
the document's top-level block stack lazy. Block quotes keep eager stacks; list entries and table
rows are unchanged. It retains policy filtering and projected block IDs. There is no public API,
parser, demo, loading-state, or dependency change.

Qualify the remaining snapshot, readiness and whole-document-export failures before treating the
candidate as regression-free. Adding a public layout mode or weakening existing behavior requires a
separate decision; neither was done here.

## Physical iPhone XR

Release builds, no debugger, iOS 18.7.11 (22H384), actual 414 × 896-point screen at 2× scale. Captures
are 828 × 1792 pixels. The host uses safe areas and 16-point SwiftUI padding, not the desktop's
390 × 844-point viewport. Each completed fixture has one warmup and three measured samples in one
process per variant. Times below are medians in milliseconds; do not compare across platforms.

| Fixture | Eager mount/layout | Lazy mount/layout | Eager capture upper bound | Lazy capture upper bound |
| --- | ---: | ---: | ---: | ---: |
| ordinary, 172 B | 46.736 | 52.020 | 1,134.424 | 1,125.506 |
| large-100, 17.2 KB | 2,284.428 | 85.456 | 6,265.093 | 3,676.737 |
| large-1000, 172 KB | No completed mount: Jetsam | 86.086 | Not available | 2,376.179 |
| nested, 1,416 B | First mount interrupted | First mount terminated | Not available | Not available |
| links-tables, 37.1 KB | 10,853.249 | 10,391.589 | 17,064.517 | 17,024.616 |

The many-block 17.2 KB fixture mounted about 27× faster in this run. The 172 KB lazy case completed
all four mounts and produced visible content; no eager speedup ratio exists because the eager case
failed. The table remains one expensive top-level block, so laziness does not make its 500 rows lazy.
The small fixture shows no initial-mount benefit.

### Incomplete and contaminated runs

- Eager `large-1000` completed construction in 1,155.866 ms, then stopped during its first mount.
  The matching Jetsam event identifies `FlatMarkRenderDevice`, PID 763, as the largest process and
  gives reason `per-process-limit`. This is a memory-limit termination, not a measured mount time.
- Eager `nested` remained in its first mount for more than two minutes. The run was stopped manually;
  its partial CSV has no mount duration, checksum or successful completion. It is not a timing sample.
- Lazy `nested` also never completed its first mount. The matching PID 1026 crash reports a scene-update
  watchdog termination (`0x8BADF00D`), background visibility and serious thermal state. The CSV recorded
  fair thermal state at startup. This is an incomplete, thermally/background-confounded case, not a
  controlled eager/lazy timing comparison or proof of the same failure mechanism as Jetsam.
- The first eager `large-100` capture driver was interrupted by a transfer readback error. Manual
  resumption inflated a capture sample to 77 seconds. That run is retained as
  `preview-large-100-interrupted-capture.csv` and excluded from the comparison table. A fresh process
  completed an uninterrupted repeat. Use the **last `run` section** of `ios-eager/preview-large-100.csv`.
- Device CSVs append across launches and app reinstalls preserve data. Lazy ordinary, large-100 and
  links-tables CSVs therefore also contain earlier eager sections. The comparison uses only each
  file's last run section. Both successful variants have matching per-fixture checksums.

## macOS

Same M3 Pro machine, Swift 6.4 and macOS 27.0.1 as
[the preceding eager baseline](render-mount-results.md). Same benchmark host, five sources, viewport,
Release configuration, one warmup and three measured samples. The eager data is that completed prior
run, not another nine-minute eager repetition. Lazy data is one later process. Milliseconds:

| Fixture | Eager mount/layout | Lazy mount/layout | Eager capture upper bound | Lazy capture upper bound |
| --- | ---: | ---: | ---: | ---: |
| ordinary | 13.611 | 9.567 | 108.699 | 109.290 |
| large-100 | 1,826.394 | 32.390 | 1,942.280 | 126.187 |
| large-1000 | 126,510.796 | 32.769 | 133,931.423 | 140.795 |
| nested | 664.810 | 67.270 | 806.251 | 532.986 |
| links-tables | 5,390.546 | 3,535.372 | 7,603.972 | 4,273.200 |

Both processes completed all 15 summary rows with checksum `13388676`. The lazy process had empty
stderr and nominal endpoint thermal state. Reduced initial cost is deferred work, not evidence of
lower total full-document work or smooth scrolling. The small sample set does not establish a
reliable p95 or performance threshold.

## Initial regression checks

Ran `swift test` with the exact original eager renderer and with the lazy candidate:

| Renderer | Tests | Reported issues, including one known issue |
| --- | ---: | ---: |
| Original eager control | 189 | 37 |
| Lazy candidate | 189 | 46 |

The eager control already fails snapshot comparisons and eight isolated HTML-navigation-host cases
in this environment. The full suite is not green for either variant. These existing failures were
not repaired or re-recorded in this experiment.

Two existing tests initially appeared to isolate candidate regressions without the full suite.
The follow-up below supersedes that attribution:

```sh
swift test --filter 'retainedParagraphReflowsNarrowWideNarrowWithoutOverlappingItsNeighbor|reverseCompletionsStayInSourceOrderAndResizeWithoutReloading'
```

- **Initial native paragraph reflow observation:** after widening the host from 140 to 400 points, the lazy candidate keeps
  a paragraph at 140 points, loses the second native paragraph from the mounted export, and fails
  geometry/reflow assertions. Showing the window during a temporary diagnostic did not fix it. Adding
  a flexible-width frame to every block also did not fix it; neither probe was retained.
- **Initial image-lifecycle observation:** the lazy candidate fails the reverse-completion wording and exact two-request
  assertions while resizing a single paragraph. This reproduces in isolation; the precise lifecycle
  cause is not yet established.

The original eager renderer passes both tests together (two tests, zero issues). The saved lazy logs
show five reflow issues and two image issues. No existing test assertions or reference images were
changed. Other new failures involve whole-document native exports and readiness expectations that
assume eager realization. Those need viewport-aware investigation, not automatic dismissal or blanket
baseline replacement.

## Follow-up: test-host sizing and Group experiment

After commit `cdc98c6`, tried a direct `ForEach` inside the document's `LazyVStack`, with a `Group`
around each block, instead of the `FlatMarkBlocks` intermediary. Both focused tests still failed with
the same seven issues. The two-paragraph resize fixture contains no quote or list stack, so nested
`VStack`s cannot explain that reproduction. The Group variant was discarded; renderer code remains
unchanged from that commit. Quotes still need a vertical layout inside their horizontal rule/content
row; a `Group` alone would not provide it.

A window-sizing diagnostic requested an 800-point height but observed heights around 80–144 points.
The test helper used `NSHostingView`'s default sizing options, including `.maxSize`. Lazy content's
estimated maximum could therefore shrink the viewport instead of retaining the requested test size.

The retained fix sets:

```swift
hosting.sizingOptions = [.minSize, .intrinsicContentSize]
```

This excludes automatic maximum sizing while retaining the minimum/intrinsic sizing used by the
helper's content checks. Disabling every sizing option also repaired the two focused tests, but made
the existing `fittingSize`-based content check fail, so that broader variant was not retained.

Added an explicit requested-viewport assertion to the existing resize test. No reflow, identity,
image-completion or request-count assertion was removed or relaxed. With the corrected host:

- Both original focused tests pass without any renderer change.
- The two tests plus `FlatMarkMentionTests` pass three consecutive runs: ten tests in three suites
  per run. This includes nested heading/list/table/quote coverage and the content-presence check.
- The full package suite runs 189 tests in 27 suites and reports 38 issues, including one known issue.
  It remains unverified overall. Failures still include HTML-navigation subprocesses, snapshot
  comparisons, recipe readiness and recipe whole-document exports. Those were not rewritten here.

This corrects the initial reflow/image regression conclusion. It does not establish that every other
failure is a test artifact. No new iOS run, performance comparison, scrolling, selection or live
VoiceOver check was performed in this follow-up. The earlier measurement samples remain historical.

## Follow-up: matched control and viewport readiness

Qualification continued on macOS 27.0.1 (26A434), Apple Swift 6.4
(`swiftlang-6.4.0.34.1`). No reference images were recorded or changed.

With the corrected mounted host, full `swift test` reproduced 189 tests in 27 suites:

| Configuration | Reported issues, including one known issue |
| --- | ---: |
| Committed lazy renderer and original recipe readiness | 38 |
| Temporary eager control and original recipe readiness | 37 |
| Lazy renderer and viewport-aware recipe readiness | 40 |

The eager control changed only the top-level `LazyVStack` to `VStack` during testing.
The lazy renderer was restored after each control. Production renderer code is unchanged.

The primary/dark readiness gate required all three document image requests on page 1.
Lazy page 1 requested only two; the gate prevented scrolling to the remaining image.
The retained test change waits for request count and native geometry to settle on each
page. It still rejects counts above the expected total. The final exact request-count
assertion and bottom-of-document assertion are unchanged.

With this change, both primary and dark reach three pages without a readiness timeout
or final request-count failure. Six snapshot mismatches replace four readiness issues,
which explains the higher full-suite issue count. This is not a green suite.

A focused `swift test --filter FlatMarkRecipeIntegrationSnapshotTests` ran all ten
scenarios with the readiness change, once lazy and once eager. Both reported the same
15 snapshot mismatches. The 15 emitted failure captures have zero differing pixels
between eager and lazy under `magick compare -metric AE`. Compared with their references,
all 15 have zero differing pixels at `-fuzz 0.5%`. Exact baseline comparisons still fail;
this evidence does not authorize re-recording or establish reviewed appearance.
Two other page filenames in the temporary output directory were not reported as failures;
they are excluded from this comparison because they could be stale artifacts.

The final lazy full suite still fails the three recipe whole-document export assertions.
The matched eager suite passes that test. Those assertions need viewport-aware investigation;
they were not removed or relaxed. Navigation subprocess failures and other snapshot suites
also remain unresolved. No running-demo, XR, scrolling interaction, selection, keyboard or
VoiceOver verification was performed in this follow-up. Automated snapshot scrolling is not
an interactive runtime qualification.

Temporary logs are `/tmp/flatmark-lazy-pickup-{suite,eager-suite,readiness-probe,eager-recipe,final-suite}.log`.
Comparison images are under `/tmp/flatmark-lazy-pickup-images/`. These are diagnostic artifacts,
not durable evidence; this section records their outcomes. `git diff --check` passed.

## Follow-up: native export order and navigation click target

Continued on the same macOS 27.0.1 / Swift 6.4 environment. No production renderer,
reference image, snapshot tolerance or public API changed.

### HTML navigation

All eight remaining HTML-navigation subprocess failures exited with status 7, before
activation or report emission. Diagnostic geometry showed a 32-point-high native text
view with a trailing newline. The host clicked at y=16, on the empty line rather than
inside the first line's glyphs. Its existing glyph-containment guard correctly rejected
that point. This was not evidence of HTML resource activation.

The host now computes a click at the first glyph's center for native text targets. It
still verifies hit-target identity, glyph containment and the expected link attribute,
and exercises the same mouse events and callback/resource assertions. All nine navigation
tests, including the 18 HTML-policy cases and positive image/link controls, pass.

### Recipe exports

The long recipe fixture was mounted without a scroll view. Lazy realization did not
include the title or appended task in the exported native descendants. A scroll-view probe
brought both into the native export, but exposed another observation assumption: lazy
stacks retain offscreen native regions and can reorder their subviews. Concatenating those
regions in descendant order produced different exports for the two initializers even
when their viewport content agreed. The probe's failure logs showed the same text chunks
in different positions, including offscreen title content after the lower recipe text.

The retained test now mounts both initializers in real scroll views and walks the document
from top to bottom before and after editing. It compares native region exports intersecting
the viewport in geometric order, including wording and attributes. It checks matching scroll
offsets, title presence at the top, appended-task presence at the bottom, reaching the bottom,
source/snapshot pairing and retained refresh behavior. It does not sort text signatures,
discard styling, or claim that native export establishes glyph visibility or selection gestures.
The original short-document whole-export parity test is unchanged.

### Verification and remaining failures

- Full lazy suite: 189 tests in 27 suites, 29 issues including one known issue.
- Matched temporary eager control with the same test fixes: the same totals and failing
  snapshot cases. Lazy was restored after the control.
- Three subsequent lazy runs of
  `swift test --filter 'FlatMarkDocumentRenderingTests|FlatMarkNavigationTests'`:
  11 tests in two suites pass each time.
- All 28 snapshot failure entries (25 distinct reference/output path pairs) report zero
  differing pixels under `magick compare -fuzz 0.5% -metric AE`. Repeated transition
  filenames share their last emitted output, so this is not 28 independently retained captures.
  Exact snapshot comparisons still fail. No tolerances or references were changed.
- Visually inspected the primary page-1 lazy capture and its reference at readable scale;
  no layout or content difference was apparent. Other snapshot pairs have metric inspection
  only in this follow-up, not a complete visual review.
- `git diff --check` passed.

These results resolve the demonstrated navigation-target and export-observation failures,
not complete lazy-renderer qualification. Runtime scrolling, width changes, offscreen-image
lifecycle, task activation after scrolling, selection, keyboard, VoiceOver and XR checks
remain outstanding. No new running-demo or physical-device check was performed.

Diagnostic logs are under `/tmp/flatmark-issues-*`, `/tmp/flatmark-navigation-*` and
`/tmp/flatmark-document-*`. They are temporary; this section records their outcomes.

## Evidence, limits and reproduction

- Raw CSVs, compact diagnostic summaries, source hashes, test logs and inspected screenshots:
  [`Construction/Baselines/lazy-comparison/`](Construction/Baselines/lazy-comparison/).
- Device host generation, launch and capture protocol:
  [DeviceHost/README.md](DeviceHost/README.md).
- Desktop command and metric definitions:
  [benchmark guide](README.md#preview-mount-and-visible-content-checkpoint-macos).
- To reproduce the candidate, inspect and apply `top-level-lazy.patch`, then rebuild each target.
  `git apply --check` succeeds against the restored production source. The final local desktop
  benchmark executable was rebuilt against the restored eager renderer.

Visually inspected the first measured capture for each completed iOS fixture/variant and each macOS
lazy fixture. They show expected content. Only those representative captures are retained in the
repository. Remaining device captures are local under `/tmp/flatmark-lazy-comparison-captures/`;
remaining desktop captures are under `/tmp/flatmark-lazy-mac-captures/`.

Capture timings are **upper bounds on time to first visible content**, not first-frame timestamps.
On iOS they include a 100 ms suspension, two-second marker polling, screenshot work, file transfer
and acknowledgement polling. That overhead dominates small fixtures and can vary between samples.
On macOS the checkpoint includes a 20 ms yield and local screen capture. Neither measures physical
scanout, source-to-screen latency, GPU time or frame rate. Parsing is outside both mount and capture
intervals. Do not interpret the capture differences as pure rendering-time differences.

Device charging, battery, clock speed, background activity and ambient temperature were not controlled.
Low Power Mode was off in the recorded startup rows; nominal startup thermal state does not establish
stable conditions throughout a run. Some macOS package checks overlapped device measurements, so host
capture transport was not isolated from that work. Physical-device capture and file transfer used
`devicectl` because MobileBuildMCP lacks those device tools. No appearance, accessibility, orientation
or viewport settings were changed. The temporary host disabled auto-lock during each run; its process
is no longer running. No scrolling, task gestures, selection or live VoiceOver checks were performed.
