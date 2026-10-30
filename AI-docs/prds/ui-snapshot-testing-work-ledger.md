# UI snapshot testing work ledger

## Coordination

Execute tickets 01–14 in order. Each ticket has an isolated implementation worker, independent acceptance review, and a separate bookkeeping worker for a commit after acceptance. The user's explicit commit authorization overrides the draft plan's no-commit default. Preserve unrelated changes. Stop on critical blockers; record them in `@blockers-extract-local-playback.md`.

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
| 09–13 | Pending | Unassigned | Depend on accepted preceding tickets. |
| 14 | Pending | Unassigned | Depends on accepted tickets 01–13. |

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
