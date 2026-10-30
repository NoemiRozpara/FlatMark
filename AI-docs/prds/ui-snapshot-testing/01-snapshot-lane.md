# 01 — Establish the snapshot lane with linked-image presentation

Track: product. Status: local draft.

## Parent

[UI snapshot testing](../ui-snapshot-testing.md). This ticket is self-contained.

## Outcome and relevant stories

US-01: A maintainer can run deterministic visual regression tests on iOS and macOS.
US-05, partial: A maintainer can inspect linked versus unlinked image presentation.
Deliver the first complete capture → reviewed baseline → repeatable verification flow.

## Scope, contracts, and non-goals

Use Point-Free's `swift-snapshot-testing` for references, image comparison, and diff reporting.
Select a compatible released version and add `SnapshotTesting` only to test targets.
No snapshot package is currently declared in `Package.swift`.
Keep native hosting/environment/readiness support small; do not build a custom comparator.
Do not add a general framework, new demo application, or renderer API for inspection.
Prefer Swift Testing where supported by the selected runner.
Preserve iOS 17/macOS 14 deployment floors and Swift 6.2 requirements.
Use separate platform references and explicit record/verify modes.
Verification must not create or update baselines.

## Implementation approach

1. Read `Package.swift`, `FlatMarkMountedView.swift`, and capture helpers in `FlatMarkImageLoadingTests.swift` under `Tests/FlatMarkTests/Rendering`.
2. Discover usable Xcode destinations and the supported iOS package-test runner. `Demo/project.yml` currently declares app targets, not a test lane. Add only the runner configuration needed for this outcome. Regenerate the demo project if its source configuration changes.
3. Integrate SnapshotTesting and establish test-only capture, bounded readiness, and actual/reference/diff artifacts. Keep helper responsibilities small. Require successful nonempty captures. Use outside margins where overflow matters. Configure explicit recording and non-recording modes rather than relying on automatic missing-reference recording.
4. Add linked and unlinked variants of `Before [![Diagram](https://example.com/image.png)](https://example.com/details) after.` with a no-network placeholder. Snapshot both outputs against explicit references, not just against each other.
5. Document commands, directory naming, baseline metadata, ownership namespaces, readiness contract, review procedure, and serialization needs in `Tests/README.md`.
6. Give the orchestrator the exact helper/runner contract for later suites. Do not retire existing tests yet.

Revalidate anchors. SnapshotTesting is the selected dependency. Stop for agreement if the lane requires additional dependencies or material infrastructure.

## Acceptance criteria

- [ ] AC-01: Both platform lanes execute the linked and unlinked cases against separate references.
- [ ] AC-02: Dimensions, pixel scale, appearance, locale, direction, and text settings are explicit.
- [ ] AC-03: Capture readiness is bounded and does not rely solely on loader callbacks or sleeps.
- [ ] AC-04: Capture failure, missing baseline, and changed output fail with useful diagnostics.
- [ ] AC-05: On each platform, an explicit recording run and visual review are followed by a separate passing non-recording run without reference changes.
- [ ] AC-10, partial: Linked/unlinked presentation has reviewed snapshots.
- [ ] Record mode is explicit and verify mode leaves baseline files unchanged.
- [ ] Test support does not enter the consumed library product.

## Verification

Run the scoped snapshots at least twice on each platform in the same qualified environment.
First run explicit recording for this ticket's intended references, then visually review them.
Next start a separate non-recording test run to validate fresh output against those references.
The second run must pass without changing references; missing references must fail.
Recording-related assertion failures may be expected; capture, readiness, and fixture failures are not.
Do not re-record a verification mismatch merely to make it pass.
Report both commands, results, and baseline review evidence.
Two runs provide a minimum repeatability check, not proof against all nondeterminism.

Run the first cases repeatedly in each qualified OS/toolchain lane.
Deliberately change fixture text and confirm a comparison failure and usable artifacts, then revert it.
Temporarily remove a reference and confirm verification fails without recording.
Exercise a capture/readiness failure and confirm bounded failure rather than a skipped assertion.
Record the actual environments; latest-OS success is not minimum-OS compatibility proof.
Use the installed mobile build skill before Apple build/run automation.
Follow `AI-docs/BUILD_AND_TEST.md`; use `$tdd` for suitable support behavior, one example at a time.
No claim about activation, VoiceOver, or gestures follows from these images.

## Blocked by

**Free to start.** External prerequisites: supported Xcode, usable iOS simulator, macOS hosting session, and baseline visual review.
Own common support, runner/package configuration, first suite, and initial testing docs.
Later workers must not edit these shared files without orchestrator approval.
