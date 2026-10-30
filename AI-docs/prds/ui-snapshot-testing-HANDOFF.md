# Handoff — UI snapshot testing program

Resume point only. Authority stays in [the plan](ui-snapshot-testing.md),
[the work ledger](ui-snapshot-testing-work-ledger.md), and
[the blockers file](../../blockers-extract-local-playback.md).

## State

- Branch `snapshot-tests`, HEAD `fa7b884`. Tickets 01–10 accepted and committed: 144 references
  (72 macOS, 72 iOS).
- Ticket 10a is implemented but **not accepted** and uncommitted. It compiles `../Support/FlatMarkFixtures`
  into both snapshot targets (`Demo/project.yml`, project regenerated) and makes
  `FlatMarkFixtureResources` prefer the bundle of a private class token over `Bundle.main`, so
  `focaccia.jpeg` resolves from each platform's own `.xctest` bundle. iOS verified 62/62, both demos
  build, all 144 hashes unchanged.
- Tickets 11, 12, 13, 14 not started. All four need a passing macOS snapshot run.

## Issue

The macOS lane is hardware-bound. `flatMarkSnapshotImage` uses `bitmapImageRepForCachingDisplay` and
`cacheDisplay`, so captures inherit the main display's ICC profile, and nothing pins a color space. All 72
macOS references embed a 3372-byte `LG ULTRAFINE` profile; captures now embed a 4076-byte `Display P3`
profile because that monitor is disconnected. 27 of 72 macOS references fail byte comparison, and the same
27 fail in `swift test`. Differences are color-only, deterministic, max rendered-channel delta 1 to 4, on
colored content only. iOS is unaffected: one stable 536-byte profile, 62/62 passing. Reproduced on a clean
checkout with ticket 10a reverted, so ticket 10a is not the cause. Details: Blocker 4.

## Pick

User chose **option 2**: pin an explicit hardware-independent color space in the macOS capture path, then
deliberately re-record and re-review the 72 macOS baselines. Authorized as **ticket 10b**, which must land
before 10a is accepted and before 11–14. Rejected and not to be retried: reconnecting the display only, and
a pixel tolerance.

Ticket 10b owns `Tests/FlatMarkTests/Snapshots/FlatMarkSnapshotCapture.swift` and the macOS reference
namespaces — an explicit orchestrator reassignment, following the ticket 05 precedent. It does not own
production sources, `Package.swift`, demo sources, or any iOS reference. If it pins iOS as well, it must
re-record and re-review all 72 iOS baselines in the same ticket and say so in `Tests/README.md`.

Gates:

- Named color space in code and in `Tests/README.md`, with the reason.
- Two consecutive non-recording macOS runs pass with no reference change.
- A fixture mutation still fails with comparison diagnostics. Pinning must not become a tolerance.
- Reviewer opens all 72 re-recorded macOS references, including lower recipe and table regions.
- All 72 iOS references byte-identical to accepted hashes.
- `swift test`: 231 tests in 30 suites, one known issue, no snapshot failures.
- Blocker 1 and Blocker 2 evidence must survive: list content still outside the offered column, and no new
  RTL task-marker baselines.

Limit to keep stating: only this Mac has ever run the macOS lane. The pin makes output hardware-independent
by construction, unverified on a second Mac.

## Commands

Full list in [Tests/README.md](../../Tests/README.md#snapshot-baselines).

```bash
(cd Demo && xcodegen generate)
swift test
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac \
  --non-interactive --result-bundle /tmp/flatmark-10b/mac-verify.xcresult
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS \
  --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --non-interactive \
  --result-bundle /tmp/flatmark-10b/ios-verify.xcresult
find Tests/References -name "*.png" | sort | xargs shasum -a 256
```

Regenerate `/tmp` manifests rather than trusting them to survive. Never run a `-Record` scheme without
explicit authorization in the assignment.
