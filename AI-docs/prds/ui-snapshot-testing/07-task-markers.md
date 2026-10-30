# 07 — Cover task-marker appearance and alignment

Track: product. Status: local draft.

## Parent

[UI snapshot testing](../ui-snapshot-testing.md). This ticket is self-contained.

## Outcome and relevant stories

US-05, partial: A maintainer can detect task-marker appearance, baseline, indentation, and wrapping regressions.

## Scope, contracts, and non-goals

Markers are passive drawings. FlatMark owns interaction and semantics.
Custom markers apply to checked/unchecked, nested, interactive, and read-only tasks.
Inherited disabling prevents edits; snapshots establish disabled appearance, not that prevention.
Keep interaction, distinct task-label, source-byte, and accessibility-state tests.

## Implementation approach

1. Inspect `FlatMarkTaskMarker`, `FlatMarkListRowView`, `FlatMarkFixtureTaskMark`, and `FlatMarkTaskMarkerTests`.
2. Add a compact public-view list with checked/unchecked parent and nested tasks and a long wrapping label.
3. Capture default square and visibly distinct custom markers. Reuse the shared passive fixture marker where suitable.
4. Cover interactive, read-only, and inherited-disabled appearance without requiring those modes to look different unless the documented styling does so.
5. Add selected enlarged and RTL cases to expose marker baseline and directional indentation.
6. Cover source and retained-document initializers for custom marker output. Avoid duplicating the full environment matrix for both.

Use 01 support. Own a new suite/namespace. Do not add actions to marker drawings, edit existing tests, or redesign marker sizing.

## Acceptance criteria

- [ ] AC-11: Both platforms have reviewed default/custom checked/unchecked references.
- [ ] Nested wrapping labels expose marker baseline and indentation.
- [ ] Read-only and inherited-disabled variants retain their markers.
- [ ] Enlarged and RTL variants are reviewed.
- [ ] Both initializers render the intended custom drawings.
- [ ] Existing editing-policy and source-preservation coverage remains intact.

## Verification

On each platform, run this ticket's snapshots at least twice in the same qualified environment.
First use explicit recording and visually review the resulting references.
Then start a separate non-recording run; it must pass without changing references.
Missing references fail verification. Do not re-record to hide a mismatch.
Distinguish expected recording assertions from real capture/readiness failures.
Report both commands, results, and review evidence; two runs are a minimum repeatability check.

Run both lanes and inspect marker shapes, baseline, label wrapping, and nesting.
Observe marker variants in the shared running demo on both platforms where feasible.
Do not infer hit-target size, keyboard activation, or VoiceOver focus order from screenshots.
Follow `AI-docs/BUILD_AND_TEST.md` and use `$tdd` for suitable behavior.
Record any custom-view environment difference without assuming an undocumented disabled visual style.

## Blocked by

**Blocked by:** [01](01-snapshot-lane.md) — qualified snapshot support.
Own one new task suite and references. Existing marker tests are edited only by ticket 14.
External prerequisites: both environments and baseline review.
