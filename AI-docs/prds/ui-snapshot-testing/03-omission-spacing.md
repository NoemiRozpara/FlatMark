# 03 — Cover omission spacing and quote-rule removal

Track: product. Status: local draft.

## Parent

[UI snapshot testing](../ui-snapshot-testing.md). This ticket is self-contained.

## Outcome and relevant stories

US-03, partial: A maintainer can detect layout slots and quote rules left behind by omitted content.

## Scope, contracts, and non-goals

`.omit` removes unsupported nodes and recursively emptied paragraphs, headings, and quotes.
It preserves supported structures, authored spaces, and pre-existing empty constructs.
Do not treat an empty custom replacement as recursive omission.
Keep source-coordinate, projected-identity, and precise whitespace tests.

## Implementation approach

1. Inspect `FlatMarkBlockListView.visibleBlocks` and quote rendering in `FlatMarkDocumentView.swift`.
2. Inspect `FlatMarkUnsupportedContentPolicy.presents`, current omission tests, and `FlatMarkOmissionSample.swift`.
3. Build compact public-view fixtures with visible before/after paragraphs around HTML-only paragraphs, headings, quotes, and nested quotes.
4. Capture `.omit` output and a hand-authored supported-only control under the same environment. Both must match the same intended visual result without an intermediate gap or quote rule.
5. Include a quote that retains a supported list or thematic break so over-aggressive omission is visible.
6. Add a narrow enlarged-text variant where retained neighbors wrap. Keep this distinct from ticket 09's empty rows/cells.

Use ticket 01 support and a dedicated suite/namespace. Revalidate anchors. Do not change production omission rules or retire old tests.

## Acceptance criteria

- [ ] AC-07: Both platforms show no removed block slot or orphan quote rule.
- [ ] Omitted output agrees visually with the supported-only control.
- [ ] Quotes containing supported structure remain visible.
- [ ] The enlarged narrow case preserves neighbor spacing and wording.
- [ ] Structural IDs, whitespace, and source-update tests remain intact.

## Verification

On each platform, run this ticket's snapshots at least twice in the same qualified environment.
First use explicit recording and visually review the resulting references.
Then start a separate non-recording run; it must pass without changing references.
Missing references fail verification. Do not re-record to hide a mismatch.
Distinguish expected recording assertions from real capture/readiness failures.
Report both commands, results, and review evidence; two runs are a minimum repeatability check.

Run and visually review both platform references.
Check full vertical gaps, not merely exported wording or positive view size.
Demonstrate that retaining a removed slot/rule would produce a mismatch, then revert the probe.
Follow `AI-docs/BUILD_AND_TEST.md`; use `$tdd` for suitable behavior one example at a time.
If current output violates the documented contract, report a blocked criterion and a separate fix need rather than accept it.

## Blocked by

**Blocked by:** [01](01-snapshot-lane.md) — capture/comparison lane and baseline conventions.
Own one new omission-spacing suite and its references.
External prerequisites: both capture environments and visual review.
Likely conceptual overlap: ticket 08 covers empty custom output; ticket 09 covers supported empty structures. Share no mutable files.
