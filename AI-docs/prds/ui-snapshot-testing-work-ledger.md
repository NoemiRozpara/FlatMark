# UI snapshot testing work ledger

## Coordination

Execute tickets 01–14 in order. Each ticket has an isolated implementation worker, independent acceptance review, and a separate bookkeeping worker for a commit after acceptance. The user's explicit commit authorization overrides the draft plan's no-commit default. Preserve unrelated changes. Stop on critical blockers; record them in `@blockers-extract-local-playback.md`.

Resume point for a new orchestrator session: [the handoff note](ui-snapshot-testing-HANDOFF.md).

Initial working tree: clean.

## Status

| Tickets | Status | Owner | Evidence / blockers |
| --- | --- | --- | --- |
| 01 | Implemented; acceptance review pending | coding assistant | Both platform comparisons pass; simplified capture per user direction. |
| 02 | Implemented; known break defect retained | coding assistant | Both SweetPad lanes recorded and verified; mutation checks fail as expected. See ticket 02 below. |
| 03 | Accepted; committed | coding assistant + reviewer | Both lanes recorded, reviewed, verified; mutation probe failed as expected. See ticket 03 below. |
| 04 | Accepted after 2 review rounds; committed | coding assistant + reviewer | List-overflow defect evidence retained; blocked criterion documented. See ticket 04 below. |
| 05 | Accepted after 2 review rounds; committed | coding assistant + reviewer | Shared capture hook added; achieved scroll offset asserted. See ticket 05 below. |
| 06 | Accepted after 2 review rounds; committed | coding assistant + reviewer | Readiness contract redesigned by orchestrator; delayed-success probe added. See ticket 06 below. |
| 07 | Accepted; committed with RTL criterion blocked | coding assistant + reviewer | Second renderer defect found: RTL task indentation runs outward. See ticket 07 below and the blockers file. |
| 08 | Accepted; committed | coding assistant + reviewer + orchestrator | 16 references; both falsification probes failed as expected. See ticket 08 below. |
| 09 | Accepted; committed | coding assistant + reviewer + orchestrator | 10 references; numbering probe failed as expected; no new defect. See ticket 09 below. |
| 10 | Accepted after 2 review rounds; committed | coding assistant + reviewer + orchestrator | Hard-break fixtures were mutation-insensitive at 3 macOS settings; repaired. See ticket 10 below. |
| 10a | Accepted; committed | coding assistant + reviewer + orchestrator | Fixture sources and raster reach both snapshot targets via one identical import; both lanes 62/62, both demos build, `swift test` 231/30, 144 hashes unchanged. See ticket 10a below. |
| 10b | Accepted; committed | coding assistant + reviewer + orchestrator | Blocker 4 resolved: macOS captures pinned to sRGB; 72 macOS baselines re-recorded, reviewed, verified twice. iOS 72 references byte-identical. See ticket 10b below. |
| 11 | Accepted; committed | coding assistant + reviewer + orchestrator | 32 references (16/platform); one retained host captures literal→custom→label→omit→restored-literal; no-reload proof (1 request vs fresh-mount 1→2); delayed-completion probe. See ticket 11 below. |
| 12 | Accepted; committed | coding assistant + reviewer + orchestrator | 12 references (6/platform): light/dark typography, enabled/disabled mentions, narrow + enlarged. Inline-code-is-monospaced (no background) confirmed as current contract, not a defect. See ticket 12 below. |
| 13 | Accepted; committed | coding assistant + reviewer + orchestrator | 18 references (9/platform): upper/lower recipe sections (title+image, tasks/quotes, table/code, lower notes) via public `FlatMarkView` + suite-local controlled loader; raster-draw proven vs a `leaf.fill` control; no shared-fixture change. See ticket 13 below. |
| 14 | Not started | Unassigned | Depends on accepted tickets 01–13. |

## Ticket 01

Owned paths: package/runner configuration, test-only common capture support, linked-image suite and its references, initial `Tests/README.md` documentation. Do not change production rendering or retire tests.

Review status: pending. Commands, helper contract, environment, and baseline review are in [Tests/README.md](../../Tests/README.md#snapshot-baselines).

- Removed unfinished green-pixel, ink-count, clipping, and custom readiness validators per the user's request. Capture uses three bounded native layout passes; image comparison owns regressions.
- Recorded and visually reviewed four references. Separate macOS and iOS verification runs passed; final reference hashes were unchanged.
- Changed fixture text failed with SnapshotTesting comparison diagnostics on both platforms. Temporarily removed references failed without recreating them on both platforms; restored originals afterward.
- Final `swift test`: 171 tests passed with one known issue. Final iOS hosted lane: two tests passed. `git diff --check` passed.
- Native capture failure injection and minimum-OS qualification were not performed. The original pixel-readiness requirements are intentionally not implemented under the user's simpler comparison-only direction.
- No commits were made. Do not start another ticket automatically.

## Ticket 02

Added the inline-flow suite and ten references covering narrow, wide, enlarged, RTL,
and consecutive-break output on both platforms. Added the new source to both generated
snapshot test targets. Shared support adds the suite namespace and real iOS Dynamic Type
for enlarged captures; existing body references retain their absolute font sizes.

Follow-up acceptance repair adds the missing consecutive-break case and removes the
incorrect claim that two hard breaks should collapse to one. Per the user's direction,
the references retain the current missing blank row for a later renderer fix. Production
rendering is unchanged. The earlier text-only evidence images are historical, not proof
of a mixed-flow defect.

[Ticket-specific commands, visual review, and limitations](../../Tests/README.md#inline-flow-qualification-ticket-02)
record the evidence. SweetPad explicit recording produced five expected recording
assertions per platform. Separate verification and final restored-fixture runs each
passed seven tests per platform. Temporary text mutation produced four comparison
failures per platform. All ten reference hashes stayed unchanged during verification.
`git diff --check` passed. Minimum-OS, running-demo interaction, and live accessibility
checks remain unverified. No production fixes, commits, or next-ticket work were made.

## Ticket 03

Added `FlatMarkOmissionSpacingSnapshotTests` with three paired cases (omitted fixture plus
supported-only control) and twelve references on both platforms: HTML block, HTML-only paragraph,
heading, quote, and nested quote; a quote that retains a supported list; and a narrow enlarged
variant. Added the suite case to `FlatMarkSnapshotSuite` and the new source to both generated
snapshot targets. Production rendering and existing omission tests are unchanged.

Initial quote captures clipped because a flexible quote rule stretched to the offered height. The
fixture now requests intrinsic vertical size; capture dimensions stayed fixed and oversized. The
rejected images are outside the repository under `/tmp/flatmark-ticket03/initial-unaccepted/`.

[Ticket-specific commands, visual review, and limitations](../../Tests/README.md#omission-spacing-qualification-ticket-03)
record the evidence. Explicit recording produced three expected recording assertions per platform.
Separate verify and restored runs each passed three tests per platform. The mutation probe
(`<u></u>` to `<u> </u>`) produced two genuine mismatches per platform on the omitted captures
only. All twelve reference hashes stayed unchanged. Final `swift test`: 179 tests passed with one
known issue. `git diff --check` passed. Independent acceptance review found no blocking items and
re-reviewed all twelve references. Constrained-host quote sizing, minimum-OS, running-demo, live
VoiceOver, and gesture checks remain unverified. No production fixes or commits were made by the
worker.

## Ticket 04

Added `FlatMarkNestedContainerSnapshotTests` with five cases and ten references on both
platforms: narrow/wide nested quotes with a custom inline replacement, narrow/wide mixed
three-level lists with paragraph, quote, and code continuations, and an enlarged list variant.
Added the suite case to `FlatMarkSnapshotSuite` and the new source to both generated snapshot
targets. Production rendering and projector tests are unchanged.

Round 1 review rejected the disposition of an RTL list capture that lost text at the left edge.
The worker reproduced the fixture with 400pt outside padding and a red border at the offered
240pt column. All wording reappears, so the loss was capture bounds, but list content still draws
outside the offered column in both directions. The finding is a renderer symptom, not a proven
internal cause. Four diagnostic PNGs are retained in
`AI-docs/prds/ui-snapshot-testing/evidence/defect-rtl-list-{rtl,ltr}-{macOS,iOS}.png`; they are
evidence, not baselines. RTL column fit stays unqualified and needs a separate bounded production
fix. The accepted suite keeps the permitted enlarged variant and 100pt insets.

Round 2 review accepted. It also asked for list-only mutation probes: moving a continuation row and
changing continuation indentation each mismatched the three list references and left the two quote
references passing on both platforms. All ten reference hashes stayed unchanged. Final
`swift test`: 184 tests passed with one known issue. `git diff --check` passed. Historical
quote-truncation source was not recovered; the README states that plainly. Running-demo, VoiceOver,
gestures, minimum-OS, RTL list fit, and vertically constrained quote hosts remain unverified. No
production fixes and no commits were made by the worker.

**Open production issue found by this ticket:** FlatMark lists draw outside the offered reading
column in both directions. Out of scope for the snapshot tickets; needs a separate bounded fix.

## Ticket 05

Added `FlatMarkTableSnapshotTests` with seven cases and fourteen references on both platforms:
wide long cells, narrow leading and trailing viewports, header-only output, an empty internal
table between visible neighbours, a visible public-table control, and an enlarged long-cell case.
Added the suite case to `FlatMarkSnapshotSuite` and the new source to both generated snapshot
targets.

Orchestrator-approved shared-support change: `flatMarkSnapshotImage` gained an optional
`prepareMountedView` hook for deterministic scroll positioning. The worker correctly stopped when
my first authorized signature would have added an await to the default path, and I approved the
optional-closure form instead. The default path is unchanged; all 36 existing references stayed
byte-identical.

Round 1 review passed every visual criterion and accepted the running-app horizontal scroll check
as NOT PERFORMED, but rejected the suite because it asserted the requested scroll offset rather
than the achieved one. Round 2 confirmed the fix: the hook now reads
`contentView.bounds.origin.x` / `contentOffset.x` after its final yield and requires an exact 0pt
or 400pt match plus the 640pt content and 240pt viewport geometry. The orchestrator independently
recomputed all fourteen table reference hashes against the recorded manifest, and Git confirms the
four existing namespaces are unchanged. Final `swift test`: 191 tests passed with one known issue.
`git diff --check` passed. Running-app scroll reachability, minimum-OS, VoiceOver, and selection
gestures remain unverified. No production changes and no commits were made by the worker.

## Ticket 06

Added `FlatMarkImagePhaseSnapshotTests` with ten cases and 34 references on both platforms:
placeholder, empty-alt placeholder, held loading, throwing failure, empty-alt failure, small
intrinsic raster, oversized 2:1 raster, mixed loaded text, and dark placeholder/failure, with
independent plain SwiftUI controls for the seven symbol phases. Added the suite case to
`FlatMarkSnapshotSuite` and the new source to both generated snapshot targets.

The first worker attempt stopped on a real blocker: iOS mounted geometry could not distinguish the
loading frame from the failure frame, and that host exposes no usable accessibility phase label.
The orchestrator ruled that phase identity must not be inferred from mounted state. Readiness
became two honest gates, completion plus bounded geometry quiescence, with phase identity coming
from exact pixel comparison, same-run contract controls, and probes. The worker accepted that
contract and implemented it.

Round 1 review passed the implementation, controls, gates, cleanup, concurrency, and all 34
references, and rejected the ticket because the ticket's delayed-loader requirement was unproven:
the held probe bypassed readiness. Round 2 confirmed the fix. With a 1s post-request delay and both
gates enabled, the delayed case passed on both platforms; with only the completion predicate
weakened, the same fixture failed. Final `swift test`: 201 tests in 26 suites passed with one known
issue. The orchestrator independently verified 34 new and 50 existing reference hashes.
`git diff --check` passed. Cancellation, accessibility labelling, URL policy, VoiceOver, minimum-OS,
and running-app behaviour remain unverified. No production changes and no commits were made by the
worker.

## Ticket 07

Added `FlatMarkTaskMarkerSnapshotTests` with nine cases and eighteen references on both platforms:
default and custom markers, interactive, read-only, and inherited-disabled, the retained-document
initializer, and two enlarged variants. Every case carries checked and unchecked parents and
children plus a long wrapping nested label. Added the suite case to `FlatMarkSnapshotSuite` and the
new source to both generated snapshot targets. The shared `FlatMarkFixtureTaskMark` is not
reachable from the snapshot targets, so the suite owns a passive purple-circle marker; this costs no
custom-marker API coverage and the README says so.

Round 1 review accepted the implementation, all eighteen references, disabled/enlarged honesty,
distinctness, mutations, and discipline, with no required changes. Reviewer independently confirmed
the RTL finding: child task markers indent outward toward the trailing boundary in RTL on both
platforms, while LTR indents inward correctly. That is a second renderer symptom, distinct from
ticket 04's column overflow. Four diagnostics are retained in
`AI-docs/prds/ui-snapshot-testing/evidence/defect-task-list-{leftToRight,rightToLeft}-{macOS,iOS}.png`
and are not baselines. RTL task baselines are withheld rather than recorded, so AC-11's RTL part
stays open pending a separate bounded production fix.

The orchestrator independently verified 84 existing and 18 new reference hashes, and confirmed with
`cmp` that default and custom references differ while the two initializers match. Final
`swift test`: 210 tests in 27 suites passed with one known issue. `git diff --check` passed.
Running-demo marker observation, hit targets, keyboard activation, VoiceOver focus order, edit
prevention, and minimum-OS remain unverified. No production changes and no commits were made by the
worker.

## Ticket 08

Added `FlatMarkUnsupportedPolicySnapshotTests` with eight cases and sixteen references on both
platforms: literal, custom, and omit policy output for a compact fixture containing emphasized text,
a Markdown link wrapped around inline tags, and a whole HTML block; empty-`EmptyView()` literal,
custom, and omit variants that separate empty custom output from recursive omission; and enabled and
disabled ambient host-control captures. Added the `.unsupportedPolicies` case to
`FlatMarkSnapshotSuite`, registered the new source through `xcodegen generate`, and added a suite-local
exact-payload empty-dispatch assertion so a renderer that silently drops unsupported nodes cannot pass.
Production rendering, shared capture support, shared fixtures, and `Demo/project.yml` are unchanged.

The worker stopped correctly once to request the generated-project change; the orchestrator approved
`xcodegen generate` as the established workflow. Independent acceptance review accepted all seven
criteria with no required changes and opened every reference itself.

Per-platform runs: final explicit recording reported eight expected recording assertions; a separate
non-recording run passed eight; injecting fallback wording into the empty host output produced one
genuine mismatch and seven passes; exchanging the opening and closing replacement labels produced one
genuine mismatch and seven passes. Restored sources and references matched the accepted manifests.
Full snapshot lanes passed 49 tests per platform, and the orchestrator independently re-ran both
non-recording lanes plus all 118 reference hashes: no drift in the 102 accepted references. Final
`swift test`: 218 tests in 28 suites passed with one known issue. `git diff --check` passed.
Running-demo observation, iOS action activation, VoiceOver, keyboard behavior, selection gestures, and
minimum-OS remain unverified. No production changes and no commits were made by the worker.

## Ticket 09

Added `FlatMarkEmptyStructureSnapshotTests` with five cases and ten references on both platforms:
an interactive and a read-only empty-label task next to a checked neighbor, authored ordered rows
`7.` and `8. keep`, an omitted-only-cell two-column table with left-empty, right-empty, fully empty,
and populated anchor rows, and an enlarged empty-task variant whose neighbor genuinely wraps. Added
the `.emptyStructures` case to `FlatMarkSnapshotSuite` and registered the source through
`xcodegen generate`. Production rendering, shared capture support, shared fixtures, and existing
behavioral tests are unchanged.

Independent acceptance review opened all ten images and accepted every criterion with no required
changes. The reviewer established from `FlatMarkDocumentView.swift` that tables draw horizontal rules
and one outer border rather than vertical column rules, so the references are described as retaining
column placement and outer/horizontal boundaries, not as proving vertical grid lines; the README says
so plainly.

Per-platform runs: explicit recording reported five expected recording assertions; a separate
non-recording run passed five; changing the authored numbers to `9.`/`10.` produced one genuine
mismatch and four passes; restored sources matched the accepted manifests. Full snapshot lanes passed
54 tests per platform, and the orchestrator independently re-ran both non-recording lanes (54 each)
and all 128 reference hashes with no drift in the 118 accepted references. Final `swift test`: 223
tests in 29 suites passed with one known issue. `git diff --check` passed. Running-demo observation,
new iOS activation, VoiceOver, keyboard, selection gestures, macOS system Dynamic Type, and
minimum-OS remain unverified. No production changes and no commits were made by the worker.

## Ticket 10

Added `FlatMarkNativePlaceholderFlowSnapshotTests` with eight cases and sixteen references on both
platforms: narrow/wide × standard/enlarged ordinary placeholder wrapping, and the same four settings
with an authored hard break before and after the placeholder. Fixtures use an unlinked image with no
loader, so they stay on the native `inlineText` path. Added the `nativePlaceholderFlow` case to
`FlatMarkSnapshotSuite` and registered the source through `xcodegen generate`. The two existing
fitted-size proxy tests in `FlatMarkImageLoadingTests.swift` are untouched for ticket 14.

Round 1 review returned the ticket. It reproduced from the retained probe log that removing the first
authored break produced byte-identical macOS output at narrow standard, wide standard, and narrow
enlarged: natural wrapping already forced the line end, so three required settings could not detect a
lost break. The README also claimed every appearance criterion passed. Round 2 shortened the boundary
runs so each authored break is the only reason its line ends (`A`, placeholder, one sentence) and
probed each break separately: all four hard-break references mismatched on both platforms for each of
the two break removals. Reviewer round 2 opened all sixteen images, confirmed no setting masks either
break, confirmed wrapping coverage stayed intact, and withheld acceptance only for the fresh byte-level
hash gate it was not permitted to run.

The orchestrator ran that gate and the lanes: current bytes of all sixteen ticket-10 references match
the round-2 manifest exactly; the eight wrapping references are identical to round 1 while the eight
hard-break references differ; all 128 pre-existing references are byte-identical to their accepted
baseline and no committed reference shows drift in Git. Independent non-recording lanes passed 62 tests
per platform. Final `swift test`: 231 tests in 30 suites passed with one known issue. `git diff --check`
passed. Selection gestures, semantic selectability, VoiceOver, keyboard behavior, minimum-OS, and
running-demo behavior remain unverified. No production changes and no commits were made by the worker.

## Ticket 10a — Expose shared fixture sources to both snapshot targets (enqueued before 11 and 13)

**Why this ticket exists.** Discovered by the orchestrator while briefing ticket 11, and recorded as
Blocker 3 in [the blockers file](../../blockers-extract-local-playback.md). Tickets 11 and 13 require the
shared fixtures, and the plan forbids a second recipe copy (`Use the shared recipe rather than copying it
into a parallel fixture system.`). Neither snapshot target can currently reach them:

- `Package.swift` exposes one product, `FlatMark`. `FlatMarkFixtures` is a target under
  `Support/FlatMarkFixtures` and is not a product, so an Xcode project target that consumes the package
  cannot depend on it.
- `Demo/project.yml` gives each snapshot target `sources: - path: ../Tests/FlatMarkTests/Snapshots` only.
  It gives the `Demo` target template `- path: ../Support/FlatMarkFixtures`. So the shared recipe and
  custom fixtures compile into the two app targets only.
- The generated project confirms this: fixture sources appear in exactly two source build phases, both
  belonging to `FlatMarkDemo-iOS` and `FlatMarkDemo-macOS`.
- `FlatMarkSnapshots-macOS` sets `TEST_HOST = ''` and `BUNDLE_LOADER = ''`, so it has no route to
  app-internal types. `FlatMarkSnapshots-iOS` is hosted by `FlatMarkDemo.app`, so it could only reach
  those types through `@testable import FlatMarkDemo`, which is asymmetric across lanes and unverified.
- No snapshot suite references these types today. Ticket 06 built its own raster and ticket 07 owned a
  private marker for the same reason. `Tests/FlatMarkTests` (package lane) reaches them fine through the
  `FlatMarkFixtures` target dependency in `Package.swift`.
- `Support/FlatMarkFixtures/FlatMarkFixtureResources.swift` resolves `focaccia.jpeg` via `Bundle.module`
  in SwiftPM and `Bundle.main` otherwise, so bundled-image availability inside a test bundle is also
  unresolved. Ticket 13 lists bundled image availability as an external prerequisite for the same reason.

**Effect if unresolved.** Ticket 11 cannot express its custom-replacement transition through the shared
fixture model, and ticket 13 cannot capture the shared recipe at all without either a parallel fixture
system (forbidden) or a second recipe copy (forbidden). Both would have to be reported blocked.

**Owned paths.** `Demo/project.yml`, the regenerated `Demo/FlatMarkDemo.xcodeproj` (project file and
schemes), a probe-then-delete temporary snapshot source used only to prove reachability, and the
`Tests/README.md` support contract. Not owned: `Package.swift` (report, do not edit), production
`Sources/FlatMark`, existing snapshot suites, and every accepted reference.

**Acceptance criteria.**

- [ ] Both `FlatMarkSnapshots-macOS` and `FlatMarkSnapshots-iOS` compile against `FlatMarkRecipeSample`,
      `FlatMarkCustomFixtureModel`, and `FlatMarkCustomDocumentFixture` in the same qualified environment,
      with the same import path on both platforms.
- [ ] The shared recipe raster resolves inside the test bundle on both platforms, with the resolving
      location recorded, or the ticket reports it unresolved instead of substituting a generated image.
- [ ] All 144 accepted references stay byte-identical, and a full non-recording run passes on both lanes.
- [ ] Both demo apps still build with the shared fixture sources, so the demo is not silently broken.
- [ ] `swift test` totals stay unchanged, proving the package lane is unaffected.
- [ ] `Tests/README.md` records the chosen mechanism, why it is the smallest one, and the exact commands.

**Verification.** Compile proof on both lanes, a temporary reachability source that is removed afterwards
with the project regenerated, both full non-recording lanes, both demo builds, the full package suite, the
reference hash guard, and `git diff --check`. Report each as compilation, automated test, or build only.

**Decision the worker must make and justify.** Adding `../Support/FlatMarkFixtures` to both snapshot
targets' `sources` needs no manifest change. Exposing `FlatMarkFixtures` as a package product instead
changes `Package.swift`, which is a public build-surface change: report that option rather than making it.

### Ticket 10a result (accepted; committed)

Ticket 10b landed first, which resolved the macOS lane that had held 10a. 10a was then re-verified on
that working lane: both non-recording lanes pass 62/62, both demo schemes build, `swift test` passes 231
tests in 30 suites with one known issue, and all 144 reference hashes are unchanged. The temporary
reachability probe was re-added, passed one test on each lane (raster resolved from each platform's own
`.xctest` bundle), and was deleted with the project regenerated. The `Tests/README.md` 10a section now
reports the passing state and attributes the earlier macOS failure to Blocker 4 (fixed by 10b). Only the
four intended files changed. Independent review accepted with no critical or warning items. Demo raster
resolution is build-only, not running-app.

Two rounds. Round 1 added the two `Demo/project.yml` source entries, proved all three fixture types compile
into both snapshot targets through one identical import, and stopped honestly when the raster resolved to nil
on macOS and from the demo app on iOS. Round 2, after the orchestrator reassigned bounded ownership of
`Support/FlatMarkFixtures/FlatMarkFixtureResources.swift`, made the non-SwiftPM path prefer the bundle of a
private class token before `Bundle.main`, and kept `Bundle.module` for SwiftPM. The probe then resolved
`focaccia.jpeg` from each platform's own `.xctest` bundle:

- macOS: `…/Debug/FlatMarkSnapshots-macOS.xctest/Contents/Resources/focaccia.jpeg`
- iOS: `…/FlatMarkDemo.app/PlugIns/FlatMarkSnapshots-iOS.xctest/focaccia.jpeg`

The probe source was deleted and the project regenerated. `Package.swift`, production sources, existing
snapshot suites, the demo sources, and all 144 accepted references are unchanged.

Verified with the changes in the tree: iOS non-recording lane 62/62 passed (the orchestrator re-ran it); both
demo schemes built; all 144 reference hashes matched the accepted manifest; `git diff --check` passed.

Not accepted, because two criteria are unmet and the orchestrator could not attribute them to this ticket:
the macOS non-recording lane fails 27 of 62, and `swift test` reports the same 27 mismatches. The
orchestrator reproduced both on a clean checkout of `53f543a` with the ticket reverted, so they come from
[Blocker 4](../../blockers-extract-local-playback.md), not from ticket 10a. Demo runtime raster resolution is
build-only evidence, not a running-app observation. The worker made no commits.

## Ticket 10b — Pin the macOS capture color space and re-record the macOS baselines

Added after Blocker 4. The user chose this option over reconnecting the recording display and over adding a
pixel tolerance. It is authorized bulk re-recording, not a workaround for a failing comparison.

**Why.** `flatMarkSnapshotImage` builds its bitmap with `bitmapImageRepForCachingDisplay` and `cacheDisplay`,
so the captured image takes the current main display's pixel format and ICC profile. Nothing pins a color
space. Every macOS reference therefore records the display that was main during recording, and the lane only
passes on that hardware.

**Owned paths.** `Tests/FlatMarkTests/Snapshots/FlatMarkSnapshotCapture.swift` and the macOS reference
namespaces under `Tests/References/Snapshots/*/macOS/`. The shared capture helper is reassigned by the
orchestrator for this ticket, following the ticket 05 precedent. `Tests/README.md` records the pin.
**Not owned:** production `Sources/FlatMark`, `Package.swift`, `Demo/project.yml`, demo sources, existing
suites other than capture support, and every iOS reference.

**Acceptance criteria.**

- [ ] macOS captures are produced in one named, hardware-independent color space, chosen and justified in
      code and in `Tests/README.md`. The three layout passes, the `prepareMountedView` hook, and the
      unavailable-capture failure path keep working.
- [ ] All 72 macOS references are re-recorded, reviewed visually, and then pass two consecutive
      non-recording macOS runs with no reference change.
- [ ] A fixture mutation still fails with SnapshotTesting comparison diagnostics. Pinning must not be
      implemented as a pixel tolerance or a looser comparison.
- [ ] All 72 iOS references stay byte-identical to their accepted hashes. If iOS is pinned too, all 72 iOS
      baselines are re-recorded and re-reviewed in this ticket and `Tests/README.md` says so.
- [ ] `swift test`: 231 tests in 30 suites, one known issue, no snapshot failures.
- [ ] Blocker 1 and Blocker 2 evidence survives re-recording: list content still draws outside the offered
      column, and no RTL task-marker baseline is added.

**Verification.** Recording run, two non-recording runs per platform, a mutation probe, the full package
suite, both demo builds, the iOS hash guard, and `git diff --check`. Report each as inspection, compilation,
automated test, or build only.

**Known limit to keep reporting.** Only this Mac has run the macOS lane. A pin makes output
hardware-independent by construction; that remains unverified on a second machine.

### Ticket 10b result (accepted; committed)

One round. The macOS branch of `flatMarkSnapshotImage` now converts the flattened native bitmap to
`NSColorSpace.sRGB` and returns an `NSImage` backed by that explicit bitmap representation. The three
layout passes, the optional `prepareMountedView` hook, the background flatten, and the
`FlatMarkSnapshotCaptureError.unavailable` path are unchanged; a nil CGImage or failed conversion also
throws `.unavailable`. Comparison stays byte-exact: `assertFlatMarkSnapshot` still uses precision `1`
with no tolerance, and the iOS branch is untouched.

All 72 macOS references were re-recorded through `FlatMarkSnapshots-macOS-Record`, visually reviewed
through per-suite contact sheets, and now embed one `sRGB IEC61966-2.1` profile (`sips`), replacing the
old `LG ULTRAFINE` profile. Two consecutive non-recording macOS runs passed 62/62 with unchanged hashes;
the orchestrator independently re-ran the non-recording macOS lane (62/62) and `swift test` (231 tests in
30 suites, one known issue, no snapshot failures). A content mutation produced genuine SnapshotTesting
comparison failures on the linked-image cases and was restored without recording. The 72 iOS references
stayed byte-identical to the accepted iOS baseline (`diff` clean). Both demo schemes built (build only).
Blocker 1 evidence survives (NestedContainers list content still draws outside the offered column) and
no RTL task-marker baseline was added. `git diff --check` passed.

Independent acceptance review returned ACCEPT with no critical or warning items; it opened the colored
link, purple custom marker, raster, table-rule, and both NestedContainers overflow references and
confirmed content is intact and the overflow defect is still faithfully captured.

Unverified: cross-display (second Mac) execution, forced capture/conversion failure, minimum-OS, running
app, VoiceOver, and gestures. The macOS lane has still only ever run on this one Mac; the sRGB pin makes
output hardware-independent by construction, unverified on other hardware.

## Ticket 11

Added `FlatMarkPolicyTransitionSnapshotTests` with five cases and 32 references (16 per platform) in a new
`.policyTransitions` namespace: retained `literal → custom → label-change → omit → restored-literal`; an
image-description `literal → omit → literal`; a no-reload control; a fresh-mount request-count contrast; and
a retained-host transition for each of the source and retained-document initializers.

**Orchestrator-owned shared-support change (blocker resolved):** the fresh-mount helper cannot retain
mounted image `@State` across captures, so AC-15's "one mounted identity / no reload" was unreachable. The
worker stopped and reported it. Following the ticket 05/06 precedent, the orchestrator ruled for a small
additive retained host (`FlatMarkRetainedSnapshotHost` / `flatMakeRetainedSnapshotHost`) in the shared
capture support, reached by extracting the existing per-platform mount and capture code into shared private
helpers. `flatMarkSnapshotImage` now composes mount→capture→close with unchanged behavior; the 144 prior
references stayed byte-identical (git shows 0 modified; the 16 new macOS refs embed the same sRGB profile).

The suite drives one retained mount and asserts exact loader request counts: the loaded raster is requested
**once** across retained policy-only changes, while the `freshMountsStartNewRequests` contrast shows two
fresh `flatMarkSnapshotImage` captures request **1 then 2** (no test-side cache hides requests). The
restored literal is compared to the initial `literal` reference with `mode: .verify` (never records), so a
stale restore fails. A one-second delayed loader plus a requests+completion+stable-geometry readiness gate
proves a transient loading frame cannot pass as final; weakening readiness to request-only makes the loaded
reference mismatch. Independent review opened the transition, held-loading, description, and initializer
references and accepted with no critical or warning items.

Per-platform: recording produced expected recording assertions for the new namespace only; two consecutive
non-recording lanes passed 67/67; the replacement-label mutation mismatched `retainedPolicyTransitions.custom`
only. The orchestrator independently re-ran both lanes (67/67) and `swift test` (236 tests in 31 suites, one
known issue), and confirmed the 144 prior references unchanged. `git diff --check` passed. Minimum-OS,
dark/RTL/enlarged transitions, VoiceOver, gestures, task activation, general cancellation, and running-demo
behavior remain unverified. No production changes and no commits were made by the worker.

## Ticket 12

Added `FlatMarkTypographySnapshotTests` with six cases and 12 references (6 per platform) in a new
`.typography` namespace: a light and a dark typography sampler (headings 1–6, bold/italic/strike, inline
monospaced code, fenced code, thematic break, hard + soft breaks), a focused mentions-enabled vs
mentions-disabled comparison (`@ja*ne*`, whole-token emphasis/strike, email, code, link label), and narrow +
enlarged wrapping variants.

**Orchestrator ruling (misread, not a blocker):** the worker first stopped believing the ticket required an
inline-code BACKGROUND. Inspection confirmed `FlatMarkInlineAttributedStringProjector.visitInlineCode` sets
only `inlinePresentationIntent = .code`, so inline code is monospaced with no background — the renderer's
long-standing intended contract, not a clipping defect. The plan forbids production fixes and inventing style
contracts here, so the ticket captures the honest current output. AC "dark exposes code backgrounds" is met by
the fenced-code background + secondary styling being visible.

Independent review opened all 12 references and accepted with no critical or warning items; it confirmed
headings 1–3 differ and 4–6 share styling, mentions add styling without link attributes, dark shows the fenced
background, and narrow/enlarged wrap without edge clipping. Per-platform: recording produced six expected
recording assertions each; two consecutive non-recording lanes passed 73/73; heading, inline-code, and mention
mutations each produced genuine mismatches and were restored. The orchestrator independently re-ran both lanes
(73/73) and `swift test` (242 tests in 32 suites, one known issue) and confirmed every non-Typography reference
byte-identical. `git diff --check` passed. Existing mention/attributed tests are untouched. Minimum-OS, system
Dynamic Type, VoiceOver, contrast/WCAG conformance, and running-demo behavior remain unverified. No production
changes and no commits were made by the worker.

## Ticket 13

Added `FlatMarkRecipeIntegrationSnapshotTests` with 18 references (9 per platform) in a new `.recipe`
namespace: `primary` and `dark` each contribute four fixed crops (upper title+image, tasks/quotes, table/code,
lower notes) taken from one full-layout loaded capture, plus an enlarged upper variant.

**Orchestrator ruling (blocker resolved without touching shared fixtures):** the renderer-only shared fixture
`FlatMarkCustomDocumentFixture` has a fixed `public let` loader that records the URL before decoding, so it
cannot supply a load-completion predicate. The worker stopped and reported it. Following the plan's "use real
public views and controlled host loaders for phase/transition coverage" and the ticket 06 precedent, the
orchestrator ruled: build the recipe with the public `FlatMarkView(markdown: FlatMarkRecipeSample.markdown, ...)`
initializer and a suite-local controlled loader. Shared fixtures and production stayed unchanged; the shared
recipe markdown is reused (not copied).

Readiness mirrors ticket 06 (loader completion + bounded geometry quiescence, not request count). The real
raster draw is proven by a **fallback contrast**: the loaded upper crop must differ from an identically
configured always-`leaf.fill` control render, with `#expect(delivery.requests == 1)` per loader. Policy is set
explicitly to `.literal` after inspecting `FlatMarkRecipeCapture.apply(to:)`. Independent review opened all 18
references, confirmed the focaccia photo (not a leaf glyph), visible tasks/quotes/table/code, lower notes and
final code block, dark code backgrounds, enlarged text, and no controls/chrome, and accepted with no critical
items.

Per-platform: recording produced nine expected recording assertions each; two consecutive non-recording lanes
passed 76/76; the raster/fallback contrast passed and a test-side markdown mutation mismatched the upper
references then restored. The orchestrator independently re-ran both lanes (76/76) and `swift test` (245 tests
in 33 suites, one known issue) and confirmed every non-Recipe reference byte-identical. `git diff --check`
passed. RTL is deliberately excluded (known-defect area). Enlarged coverage is upper-only (selected variant).
The iOS running-app lower-scroll was observed (six swipes, screenshot inspected); **macOS running-app
lower-scroll was NOT PERFORMED**. Minimum-OS, gestures, activation, live accessibility, and contrast/WCAG remain
unverified. No production changes and no commits were made by the worker.
