# 06 — Cover image phases and fitted raster appearance

Track: product. Status: local draft.

## Parent

[UI snapshot testing](../ui-snapshot-testing.md). This ticket is self-contained.

## Outcome and relevant stories

US-05, partial: A maintainer can detect placeholder, loading, loaded, failure, and fitting regressions.

## Scope, contracts, and non-goals

The host owns image fetching and decoding; FlatMark owns presentation and cancellation.
Use bundled/generated rasters and controlled loaders, never the network.
A request callback is not proof that the loaded pixels were drawn.
Preserve accessibility phase-label, URL-policy, cancellation, and loader-configuration tests.
Keep the existing numeric drawn-raster aspect-fit invariant.

## Implementation approach

1. Inspect `FlatMarkInlineView.imageText`, `imageView`, and `loadImages` in `FlatMarkDocumentView.swift`.
2. Inspect `SuspensionGate`, `LoaderSpy`, phase tests, and painted-raster support in `FlatMarkImageLoadingTests.swift`.
3. Add public-view snapshots for no-loader placeholder, held loading, a distinctive loaded local raster, and a real throwing-loader failure. Include empty-alt generic fallback and a descriptive alt label.
4. Use bounded rendered-state readiness. Clean up suspended requests on every exit path.
5. Add small intrinsic-size and oversized 2:1 raster cases at a narrow proposal. Include mixed adjacent text after successful load to exercise responsive image flow.
6. Capture outside margins so an oversized image is not clipped into appearing correctly fitted. Include a selected dark variant for placeholder/failure symbols.

Use common support from 01; keep any phase-specific test host local. Do not expose image phases publicly or remove old assertions here.

## Acceptance criteria

- [ ] AC-10, partial: Both platforms have reviewed placeholder/loading/loaded/failure references.
- [ ] A throwing loader reaches the captured failure state through real renderer loading.
- [ ] Empty alt text visibly uses the generic image label where applicable.
- [ ] Small and oversized rasters have reviewed intrinsic/fitted output.
- [ ] Loaded mixed content shows image/text placement without hidden overflow.
- [ ] Readiness cannot accept the loading frame as final loaded output.
- [ ] Every held operation is released or cancelled during teardown.

## Verification

On each platform, run this ticket's snapshots at least twice in the same qualified environment.
First use explicit recording and visually review the resulting references.
Then start a separate non-recording run; it must pass without changing references.
Missing references fail verification. Do not re-record to hide a mismatch.
Distinguish expected recording assertions from real capture/readiness failures.
Report both commands, results, and review evidence; two runs are a minimum repeatability check.

Run both platform lanes repeatedly; inspect all phase references.
Use a delayed loader to demonstrate that verification waits for drawn success rather than request start.
Run relevant existing loading/fitting tests after shared support changes, if any.
Follow `AI-docs/BUILD_AND_TEST.md`; use `$tdd` for suitable async support behavior one example at a time.
Report image appearance separately from cancellation, accessibility, and URL-policy evidence.

## Blocked by

**Blocked by:** [01](01-snapshot-lane.md) — runner, capture support, readiness conventions.
Own a new image-phase suite and namespace; leave `FlatMarkImageLoadingTests.swift` to ticket 14 for retirement edits.
External prerequisites: both environments and reference review.
