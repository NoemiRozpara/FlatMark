# 04 — Cover nested quotes and list continuation layout

Track: product. Status: local draft.

## Parent

[UI snapshot testing](../ui-snapshot-testing.md). This ticket is self-contained.

## Outcome and relevant stories

US-04, partial: A maintainer can detect truncation, indentation, and spacing regressions in nested lists and quotes.

## Scope, contracts, and non-goals

Cover long multiline quotes, nested quotes, and rich continuation blocks in lists.
Preserve FlatMark's flattened list projection and native layout limits.
Tests/README.md records earlier macOS quote truncation that remains unverified.
Do not claim the historical bug is covered unless its original failing source is recovered and tested.

## Implementation approach

1. Inspect quote rendering in `FlatMarkDocumentView.swift` and list alignment/continuation rendering in `FlatMarkListView.swift`.
2. Inspect projector tests for rich list children and continuation blocks after nested lists.
3. Search existing repository evidence for the original quote failure. Reuse it if available; otherwise record that gap and use a long multiline regression fixture.
4. Add narrow/wide snapshots of a nested quote with a custom inline replacement and enough text to reveal lost lines.
5. Add a mixed ordered/unordered nested list with a continuation paragraph, quote, and code block after a child list. Show content before and after to expose wrong nesting or alignment.
6. Add a selected enlarged or RTL variant for directional indentation. Use outside margins to expose overflow.

Use ticket 01 support. Own a new container suite and namespace. Do not edit projector tests, production code, or shared recipe sources.

## Acceptance criteria

- [ ] AC-08: Both platforms have reviewed narrow/wide nested-container references.
- [ ] Quote text remains fully drawn without clipping or an incorrectly stretched rule.
- [ ] Continuation blocks appear after the intended nested rows and align with their parent content.
- [ ] A selected enlarged/RTL variant exposes indentation and wrapping behavior.
- [ ] Historical fixture recovery or its absence is documented accurately.

## Verification

On each platform, run this ticket's snapshots at least twice in the same qualified environment.
First use explicit recording and visually review the resulting references.
Then start a separate non-recording run; it must pass without changing references.
Missing references fail verification. Do not re-record to hide a mismatch.
Distinguish expected recording assertions from real capture/readiness failures.
Report both commands, results, and review evidence; two runs are a minimum repeatability check.

Run both platform suites and inspect all lines, rules, and continuation positions.
Observe the relevant long-content behavior in the running demo on both platforms where feasible, using the shared host rather than a second app.
Record exact source and environment if a failure is found.
Use `$tdd` for suitable automated behavior and follow `AI-docs/BUILD_AND_TEST.md`.
Do not accept known clipping as the expected reference.

## Blocked by

**Blocked by:** [01](01-snapshot-lane.md) — qualified hosting and snapshot support.
Own only the new suite/references. Coordinate any need for shared host changes with the orchestrator.
External prerequisites: both capture environments and baseline review; historical fixture recovery is a reporting uncertainty, not a reason to omit the new long-content case.
