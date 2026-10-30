# 05 — Cover table rendering and horizontal overflow

Track: product. Status: local draft.

## Parent

[UI snapshot testing](../ui-snapshot-testing.md). This ticket is self-contained.

## Outcome and relevant stories

US-04, partial: A maintainer can detect table clipping, row-height, border, and viewport regressions.

## Scope, contracts, and non-goals

Tables use fixed-width native cells inside a horizontal scroll view.
Parsed column alignment does not change native alignment.
Do not redesign tables or require all columns to fit a narrow screen.
Screenshots at two positions establish drawn output there, not working scroll gestures.
Keep parser span, uneven-cell, and structural tests.

## Implementation approach

1. Inspect `FlatMarkTableView` in `FlatMarkDocumentView.swift`, including `adaptivelySized`, `rendersTable`, and grid spans.
2. Inspect `FlatMarkTableViewTests` and table projector tests in the rendering test directory.
3. Add a public Markdown table with long multiline headers/body, formatting, authored blank cells, and enough columns to exceed a narrow viewport.
4. Capture wide output and narrow leading/trailing positions. Set the scroll offset deterministically through test-only hosting support; ask the orchestrator for a small shared extension if needed. Do not add production inspection APIs.
5. Add a public header-only GFM table and an empty internal `FlatMarkRenderTable` between visible neighbors. The latter is an internal-only fixture, not a parser claim.
6. Add a selected enlarged-text long-cell case. Keep blank-after-omission fixtures in ticket 09.

Own a new suite and namespace. Do not retire eligibility tests yet. Revalidate anchors.

## Acceptance criteria

- [ ] AC-09: Both platforms have reviewed long-cell, header-only, and empty-table references.
- [ ] Long content determines sufficient row height without hidden glyphs.
- [ ] Narrow leading and trailing viewport captures show the intended columns and borders.
- [ ] Empty internal table output adds no visible table or unexpected neighbor gap.
- [ ] Header-only output visibly draws headers and its table boundary.
- [ ] Enlarged text remains readable within the documented scrolling model.

## Verification

On each platform, run this ticket's snapshots at least twice in the same qualified environment.
First use explicit recording and visually review the resulting references.
Then start a separate non-recording run; it must pass without changing references.
Missing references fail verification. Do not re-record to hide a mismatch.
Distinguish expected recording assertions from real capture/readiness failures.
Report both commands, results, and review evidence; two runs are a minimum repeatability check.

Run both lanes and visually inspect cell bottoms, borders, and offscreen-column captures.
Exercise horizontal scrolling in the running shared demo on both platforms to check actual trailing-cell reachability.
Keep that running-app result separate from snapshot comparison results.
If deterministic offset capture is unavailable, report this criterion blocked; a wide capture alone does not replace it.
Follow `AI-docs/BUILD_AND_TEST.md` and use `$tdd` where suitable.

## Blocked by

**Blocked by:** [01](01-snapshot-lane.md) — qualified capture support and runner.
Own one new table suite and baseline namespace. Shared scrolling support is orchestrator-owned.
External prerequisites: both capture environments, visual review, and running-app scroll checks.
