# Handoff — UI snapshot testing program

Resume point only. Authority stays in [the plan](ui-snapshot-testing.md),
[the work ledger](ui-snapshot-testing-work-ledger.md), and
[the blockers file](../../blockers-extract-local-playback.md).

## State

- Branch `snapshot-tests`. Tickets 01–10, 10a, 10b, and 11 accepted and committed.
- **Ticket 10b landed:** the macOS capture path is pinned to `NSColorSpace.sRGB`; all 72 macOS references
  were re-recorded (now `sRGB IEC61966-2.1`), reviewed, and pass two consecutive non-recording macOS runs
  (62/62) and `swift test` (231 tests in 30 suites, one known issue). iOS references unchanged. Blocker 4
  is resolved (see the blockers file). The macOS lane now passes on this Mac.
- **Ticket 10a landed:** both Xcode snapshot targets now compile `../Support/FlatMarkFixtures` via one
  identical `@testable import FlatMark`, and `FlatMarkFixtureResources` resolves `focaccia.jpeg` from each
  platform's own `.xctest` bundle (SwiftPM path unchanged). Both non-recording lanes 62/62, both demos
  build, `swift test` 231/30, 144 reference hashes unchanged. Shared-fixture reachability (Blocker 3) is
  resolved; tickets 11 and 13 may use `FlatMarkRecipeSample`, `FlatMarkCustomFixtureModel`, and
  `FlatMarkCustomDocumentFixture` and the shared raster directly.
- Ticket 11 (live policy transitions) landed: 32 references in a new `.policyTransitions` namespace, on an
  orchestrator-added shared `FlatMarkRetainedSnapshotHost` (one mount, repeatable `capture()`/`close()`).
  No-reload proven by constant request count vs the fresh-mount 1→2 contrast. 144 prior refs unchanged.
- Tickets 12, 13, 14 not started. 12 and 13 are independent suites; 14 depends on all of 01–13.

## Issue

The macOS lane is hardware-bound. `flatMarkSnapshotImage` uses `bitmapImageRepForCachingDisplay` and
`cacheDisplay`, so captures inherit the main display's ICC profile, and nothing pins a color space. All 72
macOS references embed a 3372-byte `LG ULTRAFINE` profile; captures now embed a 4076-byte `Display P3`
profile because that monitor is disconnected. 27 of 72 macOS references fail byte comparison, and the same
27 fail in `swift test`. Differences are color-only, deterministic, max rendered-channel delta 1 to 4, on
colored content only. iOS is unaffected: one stable 536-byte profile, 62/62 passing. Reproduced on a clean
checkout with ticket 10a reverted, so ticket 10a is not the cause. Details: Blocker 4.

## Pick

**Next: ticket 12** (typography and mentions), then 13, then 14 (Wave C integration). All prerequisites are
met; 12 and 13 are unblocked.

The shared capture support now includes `FlatMarkRetainedSnapshotHost` (added for ticket 11). Treat it as
frozen shared support; later tickets may USE it but need orchestrator approval to change it. Never re-record
to make a mismatch pass.

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
