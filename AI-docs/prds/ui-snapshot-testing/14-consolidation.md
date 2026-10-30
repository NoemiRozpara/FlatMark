# 14 — Retire visual proxies and qualify the integrated suite

Track: product. Status: local draft.

## Parent

[UI snapshot testing](../ui-snapshot-testing.md). This ticket is self-contained.

## Outcome and relevant stories

US-07: A maintainer can replace weak visual proxies without losing semantics or lifecycle guarantees.
US-01, final integration: The documented workflow runs the complete reviewed suite on both platforms.
Prefer snapshots when the remaining question is visual appearance or layout.

## Scope, contracts, and non-goals

Retire old checks only after their replacements run and their baselines are reviewed.
Keep source-byte updates, exact URLs, callback counts, image policy/cancellation/configuration identity, accessibility semantics, extraction inputs, and useful projected identity tests.
Keep the numeric drawn-pixel aspect-fit and linked-flow width bounds.
Do not delete the native-text observation helpers wholesale; exact attributes and semantic parity still use them.
No production redesign, broad formatting, or unrelated cleanup.

## Implementation approach

1. Read all completed child reports and current test bodies. Confirm replacement coverage before changing old suites.
2. Apply the migration map below. Prefer removal of duplicate visual-only assertions; keep distinct semantic evidence.
3. Remove helpers only when no remaining meaningful tests use them. Avoid a new shared abstraction just to hide old scaffolding.
4. Consolidate `Tests/README.md` with actual commands, environments, baseline review/record workflow, coverage boundaries, and remaining manual work. Update reference-capture docs only where needed to distinguish manual artifacts.
5. Run package tests and both complete snapshot lanes. Check that intended tests actually execute.
6. Review changed Swift under `AI-docs/CODE_REVIEW.md`. Report integrated evidence and unresolved checks without claiming unobserved UI behavior.

Revalidate anchors and preserve unrelated working-tree edits. This is the single owner of retirement edits to existing test suites.

## Migration map

All test paths below are under `Tests/FlatMarkTests/Rendering`.

| Current check | Required action after reviewed replacement |
| --- | --- |
| `FlatMarkImageLoadingTests`: `mixed linked image receives visible link presentation` | Replace entirely with ticket 01's explicit linked/unlinked references; do not retain arbitrary optional-PNG inequality. |
| `ordinary image matches native wrapping across effective text sizes` | Replace visual size scaffolding with ticket 10. Keep exact native-size parity only if it protects a documented independent invariant; otherwise prefer snapshots. |
| `ordinary image matches native hard break layout across effective text sizes` | Replace with ticket 10's hard-break references under the same rule. |
| `font size override changes the effective size of mounted text` | Remove if it only supports retired size-proxy tests; retain a compact control if surviving numeric tests still rely on it. |
| `generic loader error renders the failure state` | Replace anonymous PNG comparisons with ticket 06's captured real throwing-loader transition; preserve that integration behavior. |
| `switching image description policy restores wording without reloading` | Replace visual PNG equalities/inequalities with ticket 11; preserve request counts and same-mounted restoration. |
| `reloads only when the host loader configuration changes` | Keep configuration/request assertions. Replace phase PNG comparisons with explicit phase snapshots on the same lifecycle path or reuse reviewed expectations from 06. Do not replace the sequence with unrelated static fixtures. |
| `linked image flow wraps inside its column at enlarged effective text sizes` | Keep drawn-width bounds and useful effective-size controls. Remove redundant positive-size/row proxies only where ticket 02 covers their intended visual outcome. |
| `large raster is aspect fitted to the proposed paragraph width` | Keep actual drawn aspect-fit dimensions and capture-margin checks. Ticket 06 adds appearance, not a replacement for those numeric invariants. |
| `FlatMarkCustomUnsupportedContentTests`: empty-host wording test and literal export control | Let ticket 08 take over appearance and spacing. Keep a compact dispatch assertion so mere omission cannot pass as custom replacement. Remove export-only scaffolding when no longer needed for a distinct claim. |
| `replaces separate inline tags in source order as well as blocks` | Let ticket 08 take over visible order/fallback and redundant `showsContent`; preserve distinct payload/structural-position coverage without duplicating unrelated tests. |
| Live policy-output tests in custom/omission suites | Use ticket 11 for visual state output; keep same-mount source/request/task assertions. Avoid maintaining duplicate full visual matrices in old and new suites. |
| `FlatMarkTaskMarkerTests`: `host draws checked and nested unchecked markers through either initializer` | Prefer ticket 07 for appearance and redundant exported wording. Keep a compact exact state-input check only if it protects a distinct contract. Preserve editing-policy/source tests. |
| `FlatMarkTableViewTests`: header-only and empty-table eligibility | Prefer ticket 05's rendered presence/absence. Remove direct eligibility tests if no independent predicate contract remains. Preserve table projection tests. |
| Mention grammar, link destinations, source mutation, initializer semantic parity, and helper contract tests | Retain; screenshots do not prove these contracts. Remove isolated `showsContent` assertions only when redundant with stronger observation, not as a repository-wide cleanup. |

## Acceptance criteria

- [ ] AC-18: Each retired visual proxy maps to a reviewed replacement with at least its meaningful coverage.
- [ ] No arbitrary PNG inequality remains as evidence of correct linked-image presentation.
- [ ] AC-19: Semantic/lifecycle assertions and useful drawn-geometry invariants remain covered.
- [ ] Duplicate visual scaffolding is removed rather than layered indefinitely beside snapshots.
- [ ] Unused capture helpers are removed only after checking callers.
- [ ] AC-20: The final report distinguishes compilation, automated tests, baseline review, and running-app observations.
- [ ] Both complete platform lanes pass in documented environments with reviewed baselines.
- [ ] Verify mode leaves all references unchanged and reports missing references as failures.
- [ ] Missing platform access or known renderer defects are reported as blockers, not silently accepted output.

## Verification

On each platform, run this ticket's integrated snapshot scope at least twice in the same qualified environment.
First use explicit recording only for intended integration changes and visually review the resulting references.
Do not overwrite all accepted child-ticket references indiscriminately.
Then start a separate non-recording run of the complete suite; it must pass without changing references.
Missing references fail verification. Do not re-record to hide a mismatch.
Distinguish expected recording assertions from real capture/readiness failures.
Report both commands, results, and review evidence; two runs are a minimum repeatability check.

Run `swift test` from the repository root with the supported toolchain.
Run the actual iOS and macOS snapshot commands established by ticket 01.
Repeat the integrated snapshot lanes to expose nondeterminism and transient state capture.
Run concurrent verification only where the harness declares it safe; serialize shared desktop/simulator capture resources.
Check failure diagnostics with a temporary visible fixture change and a missing reference, then restore them.
Inspect all new references or confirm the recorded review evidence for each set.
Verify the running-app scenarios recorded by container/table/task/recipe tickets; leave gestures and live accessibility unverified unless actually observed.
Use `$tdd` where suitable for changed support behavior, one example at a time.
Do not claim minimum-platform support from a newer-OS run.

## Blocked by

**Blocked by:** [01](01-snapshot-lane.md), [02](02-inline-flow.md), [03](03-omission-spacing.md), [04](04-nested-containers.md), [05](05-tables.md), [06](06-image-phases.md), [07](07-task-markers.md), [08](08-unsupported-policies.md), [09](09-empty-structures.md), [10](10-native-placeholder-flow.md), [11](11-policy-transitions.md), [12](12-typography.md), and [13](13-recipe-integration.md) — all replacement suites, support, and reviewed references must be available.
External prerequisites: both qualified environments and baseline visual review.
Own existing rendering-test edits, dead-helper removal, and final shared documentation.
Coordinate with the orchestrator; no other worker edits these paths during consolidation.
