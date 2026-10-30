# 11 — Cover live unsupported-policy transitions

Track: product. Status: local draft.

## Parent

[UI snapshot testing](../ui-snapshot-testing.md). This ticket is self-contained.

## Outcome and relevant stories

US-03 and US-05, partial: A maintainer can detect stale output after render-setting changes without losing image lifecycle guarantees.

## Scope, contracts, and non-goals

Capture transitions on one mounted identity, not separate static views.
Unsupported policy is a render-time setting; source and construction settings remain unchanged.
Surviving image loads should not restart. Removed views need not retain their state.
The host still owns accepting task source updates.
Keep projected identity, source-address, and independent-action coverage.

## Implementation approach

1. Inspect `FlatMarkOmissionLiveUpdateTests`, live policy tests in `FlatMarkCustomUnsupportedContentTests`, and image-description policy tests in `FlatMarkImageLoadingTests`.
2. Reuse `FlatMarkCustomFixtureModel` and `FlatMarkCustomDocumentFixture` where they express the scenario. Otherwise use a small test-local observable host with real public view inputs.
3. Capture literal → custom → omit → literal on unchanged Markdown containing inline tags, a whole HTML block, a task, and a loaded local image.
4. Wait for each intended drawn result. Require the restored literal frame to match the reviewed initial expectation.
5. Change the custom replacement label on the same mount and capture the new output.
6. Cover image-description literal → omit → literal without a loader, plus the loaded-image control where the raster stays unchanged. Retain exact request-count assertions.
7. Exercise source and retained-document initializer paths on a compact transition fixture without duplicating every environment variant.

Use 01 support. Own a new transition suite and namespace. Coordinate common readiness changes; do not edit old suites yet.

## Acceptance criteria

- [ ] AC-15: Both platforms capture every transition state on one mounted identity.
- [ ] Restored output matches the initial reviewed literal result.
- [ ] Replacement-label changes appear without source edits.
- [ ] Image-description policy visibly changes placeholder wording and restores it.
- [ ] Loaded images remain drawn and do not reload on unrelated policy changes.
- [ ] Request-count and unchanged-source assertions accompany visual expectations.
- [ ] Both initializer paths have focused transition coverage.

## Verification

On each platform, run this ticket's snapshots at least twice in the same qualified environment.
First use explicit recording and visually review the resulting references.
Then start a separate non-recording run; it must pass without changing references.
Missing references fail verification. Do not re-record to hide a mismatch.
Distinguish expected recording assertions from real capture/readiness failures.
Report both commands, results, and review evidence; two runs are a minimum repeatability check.

Run both lanes repeatedly with bounded state readiness.
Delay local image completion to check that a transient loading frame cannot pass as final.
Inspect layout gaps and replacement positions after every transition.
Use `$tdd` for suitable transition behavior and follow `AI-docs/BUILD_AND_TEST.md`.
Do not infer task mutation, VoiceOver, or independent action correctness from snapshots.

## Blocked by

**Blocked by:** [01](01-snapshot-lane.md) — retained hosting, readiness, and comparison support.
Own one new transition suite/references. Avoid editing shared fixture sources; request orchestrator-owned changes if unavoidable.
External prerequisites: both environments and review.
