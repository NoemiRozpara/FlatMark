# 08 — Cover unsupported policies and empty custom output

Track: product. Status: local draft.

## Parent

[UI snapshot testing](../ui-snapshot-testing.md). This ticket is self-contained.

## Outcome and relevant stories

US-03, partial: A maintainer can detect incorrect literal output, replacement positions, fallback text, and empty-host spacing.

## Scope, contracts, and non-goals

Literal HTML is inert source text, not rendered HTML.
Custom output receives one host view per unsupported parser node; opening and closing tags remain separate.
Opaque host views keep ambient environment, not copied inline Markdown attributes.
FlatMark adds no fallback wording, synthetic spaces, minimum-size boxes, or enclosing Markdown-link action to replacements.
Empty custom output is not recursive omission; parent spacing may remain.
Keep payload extraction, independent activation, and no-HTML-fetch tests.

## Implementation approach

1. Inspect custom branches in `FlatMarkBlockView` and `FlatMarkInlineView` and current `FlatMarkCustomUnsupportedContentTests`.
2. Add a compact source with strong/emphasized neighboring text, a Markdown link around inline tags, a whole HTML block, and visible before/after content.
3. Capture literal/custom/omit variants. Use distinct opening/closing replacement drawings so order mistakes are visible.
4. Capture `a<u></u>b` and a whole HTML block between paragraphs with `EmptyView()` output. Compare with omission and literal controls without requiring empty custom parent spacing to disappear.
5. Include an explicitly styled custom view inside styled Markdown to protect host styling, and a visibly environment-responsive host control in enabled/disabled variants.
6. Keep a compact dispatch assertion for empty output so a renderer that simply omits the node cannot pass as successful custom dispatch.

Use 01 support. Own a new suite and namespace. Leave legacy retirement to 14.

## Acceptance criteria

- [ ] AC-12: Both platforms have reviewed literal/custom/omit references.
- [ ] Separate inline replacements occupy the intended source-order positions.
- [ ] Supported neighboring formatting and link presentation survive.
- [ ] Empty host output adds no fallback, synthetic wording, or minimum box.
- [ ] Empty custom and omission preserve their distinct parent-spacing contract.
- [ ] Explicit host styles and ambient enabled state have focused visual coverage.
- [ ] Exact dispatch and independent-action coverage remains intact.

## Verification

On each platform, run this ticket's snapshots at least twice in the same qualified environment.
First use explicit recording and visually review the resulting references.
Then start a separate non-recording run; it must pass without changing references.
Missing references fail verification. Do not re-record to hide a mismatch.
Distinguish expected recording assertions from real capture/readiness failures.
Report both commands, results, and review evidence; two runs are a minimum repeatability check.

Run both lanes and inspect replacement order, styles, spacing, and neighboring content.
Demonstrate that adding fallback text or exchanging replacement positions causes a mismatch, then revert.
Keep visual appearance separate from callback and accessibility claims.
Follow `AI-docs/BUILD_AND_TEST.md` and use `$tdd` where suitable.

## Blocked by

**Blocked by:** [01](01-snapshot-lane.md) — snapshot support and conventions.
Own new policy snapshots only. Ticket 03 owns recursive omission shells; ticket 11 owns state transitions.
External prerequisites: both environments and visual review.
