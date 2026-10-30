# 13 — Cover shared Recipe Lab sections

Track: product. Status: local draft.

## Parent

[UI snapshot testing](../ui-snapshot-testing.md). This ticket is self-contained.

## Outcome and relevant stories

US-06, partial: A maintainer can detect cross-component composition regressions in the real shared recipe, including lower content.

## Scope, contracts, and non-goals

Reuse `FlatMarkRecipeSample` and the renderer-only fixture, not a second recipe copy or demo application.
Capture renderer content without settings controls, counters, window chrome, clocks, or status bars.
Existing Recipe Lab capture scripts produce manual artifacts, not deterministic references.
Do not rely solely on a giant initial-viewport screenshot.

## Implementation approach

1. Inspect `FlatMarkRecipeSample`, `FlatMarkCustomDocumentFixture`, `FlatMarkCustomFixtureModel`, and `FlatMarkRecipeCapture` in `Support/FlatMarkFixtures`.
2. Inspect `Tests/References/RecipeLab/README.md` and existing fixture-host scripts for limits, not as a baseline comparison harness.
3. Render the unchanged shared recipe with its local raster. Confirm the raster draws instead of accepting a fallback symbol after a missing resource.
4. Capture deterministic sections of the same rendered document: title/image, nested tasks/quotes, table/code, and lower notes. Use fixed offsets/crops after full layout or another test-only deterministic framing method; do not retype sections as separate Markdown sources.
5. Use the normal light/custom-content configuration and selected dark/enlarged variants where they add integration coverage. Set the policy explicitly: capture preset names/docs are not authoritative substitutes for inspecting current preset behavior.
6. Keep section names and baseline sizes readable. Preserve full-recipe semantics and initializer-parity tests.

Use 01 support. Own a new recipe suite/namespace. Shared fixture changes require orchestrator coordination and demo project regeneration where repository policy requires it.

## Acceptance criteria

- [ ] AC-17: Both platforms have reviewed upper and lower shared-recipe references.
- [ ] Tasks, quotes, table, code, and lower notes appear in deterministic captures.
- [ ] No controls, platform chrome, or clocks enter the baselines.
- [ ] Local image readiness checks actual raster output rather than request start.
- [ ] Selected dark/enlarged output has reviewed integration coverage.
- [ ] The recipe source remains shared and unchanged for capture convenience.

## Verification

On each platform, run this ticket's snapshots at least twice in the same qualified environment.
First use explicit recording and visually review the resulting references.
Then start a separate non-recording run; it must pass without changing references.
Missing references fail verification. Do not re-record to hide a mismatch.
Distinguish expected recording assertions from real capture/readiness failures.
Report both commands, results, and review evidence; two runs are a minimum repeatability check.

Run both lanes and visually inspect every section, not just the title viewport.
Run the shared demo on both platforms and inspect lower scroll content separately from automated snapshots.
Record which presets/settings were used and which manual interactions remain unverified.
Follow `AI-docs/BUILD_AND_TEST.md`; use `$tdd` for suitable behavior without building infrastructure solely to unit-test view presentation.

## Blocked by

**Blocked by:** [01](01-snapshot-lane.md) — qualified support and deterministic framing conventions.
Own one new integration suite and its references. Resource/helper changes belong to the orchestrator.
External prerequisites: both environments, bundled image availability, and review.
