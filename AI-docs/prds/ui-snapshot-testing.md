# UI snapshot testing

Status: local specification and implementation ticket drafts. No tracker publication is authorized.
Track: product (test coverage and test maintenance).

## Goal

Add reviewed image baselines for all visual cases proposed in the code/test analysis.
Prefer a snapshot when choosing how to test appearance or layout.
Keep direct assertions for behavior that pixels cannot establish.
One orchestrator may deliver this plan through bounded subagent assignments.
Each worker implements one ticket and stops; only the orchestrator schedules subsequent work.

## Repository grounding

Planning inspected working tree at HEAD `0bf74e4`.
The working tree has unrelated edits; HEAD alone does not identify the inspected content.
Revalidate anchors before implementation.
No tests, builds, or UI captures were run during planning.

- `Sources/FlatMark/Rendering/FlatMarkDocumentView.swift`: block spacing, quotes, table grid, inline rendering modes, image phases.
- `Sources/FlatMark/Rendering/FlatMarkInlineFlowLayout.swift`: wrapping, baselines, explicit breaks, RTL placement.
- `Sources/FlatMark/Rendering/FlatMarkListView.swift`: markers, indentation, continuation blocks, independent controls.
- `Sources/FlatMark/Rendering/FlatMarkTaskMarker.swift`: passive default/custom drawings.
- `Tests/FlatMarkTests/Rendering`: model, mounted native-export, drawn-pixel geometry, and isolated interaction tests.
- `Support/FlatMarkFixtures`: shared recipe, fixture model, local image, host marker.
- `Package.swift`: no snapshot library dependency today.
- `Demo/project.yml`: demo source of truth; currently no test target is declared there.
- `Tests/References/RecipeLab/README.md`: existing captures are manual artifacts, not deterministic baselines.

## Stories

- **US-01:** As a maintainer, I can run deterministic, diagnostic visual regression tests on iOS and macOS.
- **US-02:** As a maintainer, I can detect wrapping, baseline, ordering, break, and overflow regressions in mixed inline content.
- **US-03:** As a maintainer, I can detect unsupported-policy spacing, replacement, empty-output, and live-update regressions.
- **US-04:** As a maintainer, I can detect nested list, quote, table, and empty-structure layout regressions.
- **US-05:** As a maintainer, I can detect image phase, fitting, placeholder, and task-marker appearance regressions.
- **US-06:** As a maintainer, I can detect typography and shared-recipe composition regressions.
- **US-07:** As a maintainer, I can replace weak visual proxies without losing semantic or lifecycle coverage.

## Requirements and acceptance

- **AC-01:** Separate iOS and macOS baselines run in documented, qualified environments.
- **AC-02:** Captures fix dimensions, appearance, locale, layout direction, text settings, and pixel scale.
- **AC-03:** Captures use local data and wait for the intended drawn state with bounded diagnostic failure.
- **AC-04:** Missing captures and missing baselines fail verification rather than silently recording or skipping.
- **AC-05:** Each ticket records its scoped snapshots, reviews them visually, then passes a separate non-recording run in the same environment on each platform.
- **AC-06:** Narrow mixed flow covers linked images, custom replacements, explicit breaks, enlarged text, and RTL.
- **AC-07:** Omission removes recursively emptied block slots and quote rules without removing supported structure.
- **AC-08:** Long nested quotes and list continuation blocks have reviewed narrow/wide coverage.
- **AC-09:** Tables cover long cells, header-only output, empty output, and leading/trailing narrow viewports.
- **AC-10:** Images cover placeholder, held loading, loaded raster, failure, empty alt text, and linked/unlinked presentation.
- **AC-11:** Task markers cover checked/unchecked, default/custom, nested/wrapping labels, read-only, disabled, enlarged, and RTL appearance.
- **AC-12:** Literal/custom/omit and empty custom output preserve their distinct visual contracts.
- **AC-13:** Omission preserves empty-label tasks, authored ordered numbering, and empty table cells.
- **AC-14:** Ordinary image placeholders cover native wrapping and explicit hard breaks at narrow/wide and standard/enlarged settings.
- **AC-15:** Policy transitions on one mounted identity restore correct output without unnecessary image reloads.
- **AC-16:** Typography covers heading levels, inline styles, code, breaks, mentions, and selected dark appearance.
- **AC-17:** Shared recipe coverage includes content below the initial viewport without demo controls or platform chrome.
- **AC-18:** Weak PNG inequality and visual-only scaffolding are replaced by stronger snapshots with a documented coverage mapping.
- **AC-19:** Byte-exact updates, URLs, callbacks, identity, accessibility semantics, and useful numeric drawn-geometry invariants remain covered.
- **AC-20:** Final verification reports distinguish inspection, compilation, automated comparisons, baseline review, and running-app observations.

## Technical direction

Use Point-Free's `swift-snapshot-testing` for reference management, image comparison, and diff reporting.
Add its product only to test targets and select a compatible released version in ticket 01.
Reuse native hosting/capture patterns for the small FlatMark-specific environment and readiness layer.
Do not build a custom comparator, general screenshot framework, or second demo application.
Additional dependencies still require agreement.

Prefer Swift Testing where the supported runner permits it.
Keep all test support outside the shipped library product.
Do not expose renderer state or public APIs solely for snapshots.
Use real public views and controlled host loaders for phase/transition coverage.
Internal render values remain appropriate for otherwise unrepresentable empty-table cases.
Use the shared recipe rather than copying it into a parallel fixture system.
Small test-local Markdown fixtures are appropriate for focused regressions.

Snapshot expectations follow documented contracts, including native run-based wrapping rather than browser typesetting.
Never bless a known clipping defect as correct because it is the current output.
Do not fix production behavior incidentally in these tickets.
If a fixture exposes a defect, retain the evidence, report the blocked criterion, and request a separate bounded fix.

iOS enlarged text uses a real Dynamic Type environment setting.
macOS may use the existing explicit font override for deterministic enlarged-text cases.
Do not call that override system Dynamic Type verification.
Use selected variants, not a Cartesian product of every environment.

Capture outside margins for overflow cases.
Do not size a capture to a possibly wrong fitted result and clip away the failure.
A loader callback is not proof that SwiftUI drew the image.
Held loading tests must release/cancel their work during teardown.
Each ticket runs its scoped snapshots at least twice on each platform:
1. Run explicit recording to create or update that ticket's intended references.
2. Visually review those references before accepting them.
3. Start a separate non-recording test run in the same qualified environment and compare fresh output against the recorded references.
The second run must pass without changing references; it is the minimum repeatability check, not proof against all nondeterminism.
Missing references are expected to fail verification; the recording run establishes them first.
Recording may report failures because references were created or updated; distinguish these from real capture, readiness, or fixture failures.
Do not re-record after a verification mismatch just to make it pass.
Record both commands, results, and review evidence in the ticket report.
Ticket 14 scopes recording to intended integration changes and must not overwrite all accepted references indiscriminately.
Use explicit record and verify modes; verification never updates references.
Publish useful actual/reference/diff artifacts on failure.
Avoid unreviewed broad pixel tolerances.

## Non-goals

- No renderer redesign, public API changes, parser changes, or new fetching/navigation ownership.
- No replacement of source-coordinate, URL, callback, identity, or accessibility-semantic checks by screenshots.
- No claim that screenshots establish VoiceOver, hit targets, keyboard behavior, selection gestures, or external opening.
- No generic CI overhaul, dependency migration, performance project, or repository-wide cleanup.
- No commits, tracker issues, or automatic closing of work.

## Tickets and coverage

All child documents are self-contained implementation drafts under [ui-snapshot-testing/](ui-snapshot-testing/).
New test file names are local implementation choices, not pre-existing anchors.
Each child owns a separate snapshot suite and its baseline namespace.

| ID | Ticket | Story / acceptance coverage | Blockers |
| --- | --- | --- | --- |
| 01 | [Establish the snapshot lane with linked-image presentation](ui-snapshot-testing/01-snapshot-lane.md) | US-01, US-05; AC-01–05, linked/unlinked part of AC-10 | Free to start |
| 02 | [Cover mixed inline flow](ui-snapshot-testing/02-inline-flow.md) | US-02; AC-06 | 01 |
| 03 | [Cover omission spacing](ui-snapshot-testing/03-omission-spacing.md) | US-03; AC-07 | 01 |
| 04 | [Cover nested quotes and list continuations](ui-snapshot-testing/04-nested-containers.md) | US-04; AC-08 | 01 |
| 05 | [Cover table rendering and overflow](ui-snapshot-testing/05-tables.md) | US-04; AC-09 | 01 |
| 06 | [Cover image phases and fitting](ui-snapshot-testing/06-image-phases.md) | US-05; phase/fitting part of AC-10 | 01 |
| 07 | [Cover task-marker appearance](ui-snapshot-testing/07-task-markers.md) | US-05; AC-11 | 01 |
| 08 | [Cover policies and empty custom output](ui-snapshot-testing/08-unsupported-policies.md) | US-03; AC-12 | 01 |
| 09 | [Cover supported empty structures](ui-snapshot-testing/09-empty-structures.md) | US-04; AC-13 | 01 |
| 10 | [Cover native image-placeholder wrapping](ui-snapshot-testing/10-native-placeholder-flow.md) | US-02, US-05; AC-14 | 01 |
| 11 | [Cover live policy transitions](ui-snapshot-testing/11-policy-transitions.md) | US-03, US-05; AC-15 | 01 |
| 12 | [Cover typography and mentions](ui-snapshot-testing/12-typography.md) | US-06; AC-16 | 01 |
| 13 | [Cover shared recipe sections](ui-snapshot-testing/13-recipe-integration.md) | US-06; AC-17 | 01 |
| 14 | [Retire visual proxies and qualify the integrated suite](ui-snapshot-testing/14-consolidation.md) | US-07, US-01; AC-18–20 | 01–13 |

AC-01–05 and AC-19 apply to every child as cross-cutting constraints.

## Orchestrator runbook

### Start

1. Read this specification and current `AGENTS.md`, planning, architecture, UI, build/test, and review guidance.
2. Inspect status and preserve unrelated edits, including `TESTING_HANDOVER.md`.
3. Treat this parent as permission to coordinate all listed tickets, not permission for workers to pick additional issues.
4. Maintain a work ledger with ticket status, owner, paths, blockers, review status, commands, environment, and evidence.
5. Do not mark a ticket done because code compiled or an agent reported success.

### Wave A: qualify one complete lane

Assign ticket 01 to one implementation agent.
It owns package/runner configuration, common capture support, commands, baseline conventions, and the first linked-image suite.
Run and review both platform baselines before releasing dependent work.
Record the actual runner and helper contract in `Tests/README.md`.
Freeze shared support for Wave B; later changes require the orchestrator's coordination.
Use SnapshotTesting for comparison and keep custom support limited to hosting, environment, and readiness.
Require the explicit recording run, visual review, and separate passing non-recording run on both platforms before releasing dependent tickets.

### Wave B: independent suites

Tickets 02–13 are logically parallel after 01.
Delegate only as many as can work without file conflicts or competing build/capture processes.
Each owns new suite files and uniquely named baseline/artifact directories.
Workers do not edit existing rendering test files, shared fixture sources, package configuration, demo configuration, or common helpers unless the orchestrator reassigns ownership.
Workers report needed shared changes to the orchestrator instead of duplicating infrastructure.

Give each worker its complete ticket, current guidance, ticket 01's support contract, owned paths, environment lane, and the relevant portion of this runbook.
A worker returns changed paths, cases added, baseline review status, exact checks, remaining uncertainty, and a suggested imperative commit message.
Workers do not commit, close tickets, or start another ticket.

### Resource scheduling

Use one capture/recording process per simulator or desktop session.
Serialize native mounted tests if they compete for event-loop or window resources.
Use separate build/scratch and artifact paths if independent builds run concurrently.
Do not run record mode against baseline directories owned by another worker.
Code authoring may overlap even when runtime verification must queue.
Do not assume worktrees, commits, or merges are authorized to enable parallelism.

### Wave C: integration and retirement

Assign ticket 14 after all replacement coverage is implemented and reviewed.
That agent is the only owner of edits to existing test suites for retirement.
It also owns final shared documentation changes and dead-helper deletion.
No worker removes old tests early.
Run the full package suite and both qualified snapshot lanes after integration.
Test the documented failure and record workflows; ensure verify mode never records.
Perform the targeted running-app checks required by the affected scenarios.

### Review and completion gates

Use `swift-code-review` as primary review for Swift changes.
Use the repository's specialist rules for material SwiftUI or concurrency risks.
Review initial references visually at readable scale, including lower recipe content.
Record who reviewed each set and what was inspected.
Report unavailable OS lanes or manual checks as unverified, not passed.
Do not accept a known renderer defect, missing capture, or missing destination as a baseline success.
Stop for public-contract conflicts or material architecture changes.
The final report lists delivered tickets, outstanding blockers, baseline environments, test results, review evidence, and remaining manual checks.

## Verification limits

This plan is grounded in source inspection, not a successful run of a new harness.
SnapshotTesting is selected but not installed by this planning change.
No helper API, test destination, or simulator identifier is assumed to exist.
Historical Recipe Lab captures do not verify the current fixture.
Follow [BUILD_AND_TEST.md](../BUILD_AND_TEST.md) and [Tests/README.md](../../Tests/README.md) for evidence boundaries.
