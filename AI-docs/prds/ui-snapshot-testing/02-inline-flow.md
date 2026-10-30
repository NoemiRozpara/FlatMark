# 02 — Cover mixed inline flow

Track: product. Status: local draft.

## Parent

[UI snapshot testing](../ui-snapshot-testing.md). This ticket is self-contained.

## Outcome and relevant stories

US-02: A maintainer can detect wrapping, baseline, ordering, break, and overflow regressions in mixed inline content.

## Scope, contracts, and non-goals

Cover text around a resolved linked image, custom replacement views, and explicit breaks.
FlatMark wraps native runs, not browser-style character fragments across arbitrary views.
Do not impose continuous selection or change layout behavior to match browser output.
Images are local; navigation is handled locally and never opens external resources.
Snapshots supplement the existing drawn-pixel width guard, not replace it.

## Implementation approach

1. Inspect `FlatMarkInlineFlowLayout` and `FlatMarkInlineView` in `Sources/FlatMark/Rendering`.
2. Inspect `linked image flow wraps inside its column at enlarged effective text sizes`, `linked image flow preserves non-breaking spaces`, and inline-element tests in the rendering test directory.
3. Add one focused suite through the public `FlatMarkView`. Use absolute image/link URLs so the fixture really enters linked-image flow.
4. Cover a narrow column with long text on both sides of an image. Include a custom replacement of a distinct height, adjacent supported emphasis/link text, and a hard break. Add a wide control.
5. Add selected standard/enlarged and RTL variants. Include a consecutive-break case to expose lost vertical separation; judge it against the documented break contract, not accidental current output.
6. Capture margins outside the offered column. Report defects rather than blessing overflow.

Use ticket 01 support. Keep fixture Markdown local and baseline names unique. Do not edit shared helpers or old suites.

## Acceptance criteria

- [ ] AC-06: Both platforms have reviewed narrow mixed-flow references.
- [ ] A wide control makes wrapping differences visible.
- [ ] Enlarged text and RTL each have a reviewed variant.
- [ ] Explicit breaks, replacement positions, and baseline differences are visible in the fixture.
- [ ] Capture bounds expose overflow rather than crop it into a passing result.
- [ ] Non-breaking-space and numeric drawn-width assertions remain intact.

## Verification

On each platform, run this ticket's snapshots at least twice in the same qualified environment.
First use explicit recording and visually review the resulting references.
Then start a separate non-recording run; it must pass without changing references.
Missing references fail verification. Do not re-record to hide a mismatch.
Distinguish expected recording assertions from real capture/readiness failures.
Report both commands, results, and review evidence; two runs are a minimum repeatability check.

Run this suite through both qualified lanes and visually inspect all variants.
On iOS use an explicit Dynamic Type setting; on macOS label the font override as effective text size only.
Demonstrate that a temporary relevant layout/content change produces a snapshot mismatch, then revert it.
Use real mounted rendering; a projected element list is not visual evidence.
Follow `AI-docs/BUILD_AND_TEST.md` and `$tdd` where suitable, one behavior at a time.
Record unavailable running-app checks separately.

## Blocked by

**Blocked by:** [01](01-snapshot-lane.md) — qualified cross-platform support, commands, and reference conventions.
Own one new mixed-flow suite and its baseline namespace.
External prerequisites: both capture environments and visual review.
Shared helper requests go to the orchestrator; no existing-test retirement here.
