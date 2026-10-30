# 09 — Cover supported empty structures after omission

Track: product. Status: local draft.

## Parent

[UI snapshot testing](../ui-snapshot-testing.md). This ticket is self-contained.

## Outcome and relevant stories

US-04, partial: A maintainer can detect lost markers, numbering, and cell geometry when omission empties supported structures.

## Scope, contracts, and non-goals

Omission removes unsupported nodes, not supported list rows or table cells.
An empty-label task keeps its marker/control and source address.
Ordered numbering remains authored, including a non-one starting number.
Keep byte-exact toggle and table/list projection tests.
Do not add synthetic label text to make empty structures easier to inspect.

## Implementation approach

1. Inspect `FlatMarkOmittedContentTests`, `FlatMarkOmissionSample`, list visible-entry filtering, and table rendering.
2. Add compact public-view fixtures for `- [ ] <u></u>` with a neighboring checked task, `7. <u></u>` followed by `8. keep`, and a two-column table with omitted-only cells.
3. Capture omission output with visible supported neighbors to expose lost or shifted slots.
4. Cover an interactive and a read-only empty-label task appearance. Add a selected enlarged variant where the neighboring row or cell wraps.
5. Keep this suite focused on supported structure. Recursive paragraph/quote removal belongs to ticket 03; generic table overflow belongs to ticket 05.

Use 01 support. Own a new suite and namespace. Do not edit old suites or production rules.

## Acceptance criteria

- [ ] AC-13: Both platforms have reviewed empty-task, ordered-row, and empty-cell references.
- [ ] The empty task retains its visible marker in interactive and read-only modes.
- [ ] Ordered output retains `7.` and `8.` in the intended positions.
- [ ] Empty cells retain table columns, row positions, and boundaries.
- [ ] The enlarged case preserves supported structure without synthetic wording.
- [ ] Existing source-update and structure assertions remain intact.

## Verification

On each platform, run this ticket's snapshots at least twice in the same qualified environment.
First use explicit recording and visually review the resulting references.
Then start a separate non-recording run; it must pass without changing references.
Missing references fail verification. Do not re-record to hide a mismatch.
Distinguish expected recording assertions from real capture/readiness failures.
Report both commands, results, and review evidence; two runs are a minimum repeatability check.

Run both snapshot lanes and inspect marker/number presence and table geometry.
Do not use exported blank text or nonzero fitted size as the oracle for visible markers.
Preserve the existing omitted-label activation test as separate behavioral evidence.
Follow `AI-docs/BUILD_AND_TEST.md` and `$tdd` for suitable behavior.

## Blocked by

**Blocked by:** [01](01-snapshot-lane.md) — capture/comparison support.
Own one new empty-structure suite and references; no shared edits.
External prerequisites: both capture environments and review.
