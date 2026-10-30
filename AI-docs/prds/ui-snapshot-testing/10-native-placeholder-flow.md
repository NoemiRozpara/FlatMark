# 10 — Cover native image-placeholder wrapping and hard breaks

Track: product. Status: local draft.

## Parent

[UI snapshot testing](../ui-snapshot-testing.md). This ticket is self-contained.

## Outcome and relevant stories

US-02 and US-05, partial: A maintainer can detect native image-placeholder wrapping and break regressions directly in drawn output.

## Scope, contracts, and non-goals

An ordinary unloaded image may remain in native selectable `Text` rather than custom flow.
Use an unlinked image and no loader for this path.
Snapshots are preferred over reconstructing a second native `Text` expression and comparing fitted sizes.
Do not replace link destinations, alt-text policy, exact whitespace, or semantic selectability tests.

## Implementation approach

1. Inspect `FlatMarkInlineView.renderingMode`, `inlineText`, and `labeledImageText`.
2. Inspect the existing tests named `ordinary image matches native wrapping across effective text sizes` and `ordinary image matches native hard break layout across effective text sizes`.
3. Use those focused sources as starting fixtures through the public view.
4. Capture narrow/wide columns and standard/enlarged text for ordinary placeholder wrapping.
5. Capture explicit hard breaks before and after the placeholder. Include enough text to make a lost break visible.
6. Use real iOS Dynamic Type settings and a clearly labelled macOS font override. Record the effective settings so two identical-size variants cannot accidentally count as enlarged coverage.

Use 01 support. Own a new suite and namespace. Leave removal of old fitted-size tests to ticket 14.

## Acceptance criteria

- [ ] AC-14: Both platforms have reviewed narrow/wide and standard/enlarged placeholder references.
- [ ] Wrapping output includes the icon, alt label, and neighboring wording.
- [ ] Hard-break references visibly preserve the intended line structure.
- [ ] The enlarged variant visibly exercises larger effective text.
- [ ] Captures require nonempty successful output rather than accepting two collapsed layouts.

## Verification

On each platform, run this ticket's snapshots at least twice in the same qualified environment.
First use explicit recording and visually review the resulting references.
Then start a separate non-recording run; it must pass without changing references.
Missing references fail verification. Do not re-record to hide a mismatch.
Distinguish expected recording assertions from real capture/readiness failures.
Report both commands, results, and review evidence; two runs are a minimum repeatability check.

Run and review both lanes, including all line breaks and trailing text.
Probe a removed hard break or altered placeholder label and confirm a mismatch, then revert.
Report exactly which settings changed text size; macOS font override is not system accessibility verification.
Follow `AI-docs/BUILD_AND_TEST.md` and use `$tdd` where suitable.

## Blocked by

**Blocked by:** [01](01-snapshot-lane.md) — qualified support and environment settings.
Own new native-placeholder suite/references. Existing image test edits belong exclusively to 14.
External prerequisites: both environments and baseline review.
