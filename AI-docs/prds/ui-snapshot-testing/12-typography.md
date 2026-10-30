# 12 — Cover typography and representative mentions

Track: product. Status: local draft.

## Parent

[UI snapshot testing](../ui-snapshot-testing.md). This ticket is self-contained.

## Outcome and relevant stories

US-06, partial: A maintainer can detect typography, code-background, and representative mention-style regressions.

## Scope, contracts, and non-goals

Cover appearance, not a new theme system or syntax highlighting.
Heading levels 4–6 currently share headline styling; do not invent a distinct style contract.
Mention detection is opt-in and does not create a link.
Keep exact grammar, token-boundary, attributed-range, and destination tests.

## Implementation approach

1. Inspect heading/code/thematic-break rendering in `FlatMarkDocumentView.swift` and inline attributed projection.
2. Inspect `FlatMarkMentionTests` and relevant formatting/projector tests.
3. Add a compact sampler with headings 1–6, bold, italic, strikethrough, inline code, fenced code, thematic break, and hard/soft breaks.
4. Add representative enabled/disabled mention output, including `@ja*ne*`, whole-token emphasis/strike, an email, code, and a link label. Keep this a visual sampler, not a screenshot per grammar case.
5. Cover light and dark appearance plus a selected narrow/enlarged variant. Keep code/background and secondary styling visible.

Use 01 support and a unique suite/namespace. Do not retire exact mention tests or add public styles.

## Acceptance criteria

- [ ] AC-16: Both platforms have reviewed typography and mention samplers.
- [ ] Heading, code, inline formatting, breaks, and divider appearance are visible.
- [ ] Enabled/disabled mention output has a focused visual comparison.
- [ ] Dark references expose code backgrounds and secondary styling.
- [ ] A narrow/enlarged reference exposes wrapping and typography interactions.
- [ ] Precise mention and attributed-string coverage remains intact.

## Verification

On each platform, run this ticket's snapshots at least twice in the same qualified environment.
First use explicit recording and visually review the resulting references.
Then start a separate non-recording run; it must pass without changing references.
Missing references fail verification. Do not re-record to hide a mismatch.
Distinguish expected recording assertions from real capture/readiness failures.
Report both commands, results, and review evidence; two runs are a minimum repeatability check.

Run and visually inspect both platform lanes at readable scale.
Check low-contrast symbols/backgrounds visually without claiming automated contrast or accessibility conformance.
Confirm representative style changes produce comparison failures, then revert probes.
Use `$tdd` for suitable behavior and follow `AI-docs/BUILD_AND_TEST.md`.

## Blocked by

**Blocked by:** [01](01-snapshot-lane.md) — support and environment conventions.
Own one new sampler suite and references; no existing-test edits.
External prerequisites: both capture environments and review.
