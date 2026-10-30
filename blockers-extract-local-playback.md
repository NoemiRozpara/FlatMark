# Blockers — UI snapshot testing program (tickets 01–14)

Coordination record for the [UI snapshot testing plan](AI-docs/prds/ui-snapshot-testing.md).
These are findings that the snapshot tickets cannot resolve themselves, because the plan forbids
production changes in these tickets ("Do not fix production behavior incidentally in these
tickets"). None of them stops the remaining tickets. See
[the work ledger](AI-docs/prds/ui-snapshot-testing-work-ledger.md) for ticket-by-ticket status.

## Blocker 1 — Lists draw outside the offered reading column (blocks full AC-08 RTL fit)

- Found by ticket 04. Confirmed independently by the acceptance reviewer on macOS and iOS.
- Symptom: list content (paragraph and quote text, and the code-block background) draws outside the
  offered 240pt column. In RTL it crosses the left boundary; in LTR it crosses the right boundary.
  Plain before/after paragraphs stay inside. Cause is not established; the alignment-guide offsets
  in `Sources/FlatMark/Rendering/FlatMarkListView.swift` are the leading suspect.
- Evidence (diagnostics, not baselines):
  `AI-docs/prds/ui-snapshot-testing/evidence/defect-rtl-list-{rtl,ltr}-{macOS,iOS}.png`
- Effect on the plan: accepted baselines use large outside insets, so they capture the drawing
  honestly instead of clipping it. RTL column fit stays unqualified.
- Needed: a separate bounded production fix, then deliberate re-review of the affected references.

## Blocker 2 — RTL task markers indent outward (blocks the RTL part of AC-11)

- Found by ticket 07. Confirmed independently by the acceptance reviewer on macOS and iOS.
- Symptom: in RTL, nested task markers move outward toward the trailing boundary instead of inward
  away from the leading edge. LTR indents correctly. All wording stays visible, so this is wrong
  indentation, not clipping. Distinct from Blocker 1: this fixture does not reproduce the
  out-of-column overflow.
- Evidence (diagnostics, not baselines):
  `AI-docs/prds/ui-snapshot-testing/evidence/defect-task-list-{leftToRight,rightToLeft}-{macOS,iOS}.png`
- Effect on the plan: no RTL task-marker baseline was recorded. Recording the current output would
  bless a defect, which the plan forbids. AC-11 therefore remains partially open.
- Needed: a separate bounded production fix, then new reviewed RTL baselines on both platforms.

## Blocker 3 — Snapshot targets cannot reach the shared fixtures (blocks tickets 11 and 13)

- Found by the orchestrator while briefing ticket 11. Recorded as ticket 10a in
  [the work ledger](AI-docs/prds/ui-snapshot-testing-work-ledger.md), enqueued before tickets 11 and 13.
- Symptom: neither `FlatMarkSnapshots-macOS` nor `FlatMarkSnapshots-iOS` can reference
  `FlatMarkRecipeSample`, `FlatMarkCustomFixtureModel`, or `FlatMarkCustomDocumentFixture`.
- Cause, verified in the repository:
  - `Package.swift` declares one product, `FlatMark`. `FlatMarkFixtures` is a target at
    `Support/FlatMarkFixtures` and is not a product, so an Xcode target consuming the package cannot
    depend on it.
  - `Demo/project.yml` compiles `../Support/FlatMarkFixtures` into the `Demo` target template only. The
    snapshot targets list only `../Tests/FlatMarkTests/Snapshots`. The generated project confirms the
    fixture sources appear in exactly two source build phases, both belonging to the two demo apps.
  - `FlatMarkSnapshots-macOS` sets `TEST_HOST = ''` and `BUNDLE_LOADER = ''`, so it has no route to
    app-internal types at all. The iOS bundle is hosted by `FlatMarkDemo.app` and could only reach them
    through `@testable import FlatMarkDemo`, which is asymmetric across lanes and unverified.
  - `Support/FlatMarkFixtures/FlatMarkFixtureResources.swift` resolves `focaccia.jpeg` through
    `Bundle.module` under SwiftPM and `Bundle.main` otherwise, so resource availability inside a test
    bundle is unresolved too.
- Precedent for the cost: ticket 06 built its own raster and ticket 07 owned a private task marker, both
  because the shared fixture was unreachable.
- Effect on the plan: ticket 11 cannot express custom-replacement transitions through the shared fixture
  model, and ticket 13 cannot capture the shared recipe without a parallel fixture system or a second
  recipe copy, both of which the plan forbids. Ticket 13 also lists bundled image availability as an
  external prerequisite.
- Needed: ticket 10a, a build-configuration change owned by the orchestrator lane. The smallest candidate
  adds `../Support/FlatMarkFixtures` to both snapshot targets in `Demo/project.yml` and regenerates the
  project. Exposing `FlatMarkFixtures` as a package product instead would change `Package.swift`, a public
  build surface, and needs agreement first.

## Blocker 4 — macOS captures inherit the main display's ICC profile, so the macOS lane is hardware-bound (blocks the macOS half of every remaining ticket)

- Found by the orchestrator while qualifying ticket 10a, on a clean checkout of `53f543a` with no
  ticket-10a changes applied. It is therefore not caused by ticket 10a.
- Symptom: 27 of the 72 committed macOS references fail byte comparison, and the same 27 fail in the
  `swift test` package lane. The iOS lane passes 62/62 in the same session on the same machine.
- Measured, not assumed:
  - All 72 committed macOS references embed one 3372-byte ICC profile, reported by `sips` as
    `profile: LG ULTRAFINE`. All 72 iOS references embed a separate 536-byte profile and are unaffected.
  - Every capture produced now embeds a different 4076-byte profile, reported as `Display P3`.
  - `system_profiler SPDisplaysDataType` now lists only the built-in Liquid Retina XDR display as main.
    The LG UltraFine used during recording is no longer connected.
  - `flatMarkSnapshotImage` builds its bitmap with `bitmapImageRepForCachingDisplay` and `cacheDisplay`,
    so the bitmap takes the current main display's pixel format and color profile. Nothing in the shared
    capture layer pins a color space.
  - Difference is color-only and sub-visible: per case, 68 to 20 000 of up to 384 000 pixels differ, with
    a maximum rendered-channel delta of 1 to 4 and a maximum stored-sample delta of 32. Differences sit on
    colored content only (checkboxes, accent-tinted links, purple custom markers, rasters, custom host
    views). Pure black-on-white text cases in `OmissionSpacing`, `Tables`, and `NativePlaceholderFlow`
    still pass byte-exact. The failures are deterministic: three consecutive runs produced identical bytes.
- Effect on the plan: this breaks the acceptance gate for every remaining ticket. Each one requires a full
  non-recording run that passes on both platforms, and the macOS half cannot pass right now, on a clean
  tree or with any ticket applied. It also makes new baselines inconsistent: a reference recorded now is
  tagged `Display P3` and will fail again the moment the recording display is reconnected.
- Why the orchestrator did not resolve it: every available fix changes either the user's machine or the
  accepted baseline corpus, and both need agreement.
  1. Reconnect the display used during recording. Zero repository change, restores the lane today, leaves
     the harness hardware-bound and unqualified for any other Mac or CI machine.
  2. Pin a color space in the shared capture helper, then deliberately re-record and re-review all 72
     macOS baselines. This is the durable fix and the one the plan's AC-02 spirit points to, but it rewrites
     accepted references across all ten namespaces and edits ticket-01 shared support outside a ticket's
     ownership. The plan forbids re-recording to make a mismatch pass, so this needs an explicit decision.
  3. Add a narrow reviewed pixel tolerance. Keeps every byte of the corpus, weakens all 72 macOS
     comparisons, and the plan says to avoid unreviewed broad tolerances.
- Until this is settled, ticket 10a holds at: iOS verified, macOS unverified, nothing committed.

## Not blockers, but permanently unverified by these tickets

Reported as unverified, never as passed. Each is an evidence-boundary limit, not a defect.

- Running-app horizontal scroll reachability for tables (ticket 05): demo schemes launched, no
  horizontal gesture into the table could be driven. NOT PERFORMED on both platforms.
- Running-app task-marker variant observation (ticket 07): both demos launched with the
  `hostMarkers` preset; only the introduction was reachable, marker controls were not operated.
  NOT PERFORMED on both platforms.
- Minimum-OS (iOS 17 / macOS 14) qualification: every snapshot ran on macOS 27.0.1 and the
  iPhone 18 Pro simulator on iOS 27.0 with Xcode 27.0 / Swift 6.4.
- Live VoiceOver announcements, focus order, selection gestures, keyboard activation, and hit-target
  size. Screenshots cannot establish these.
- iOS failure-phase readiness by mounted observation: iOS exposes no usable accessibility phase
  label in the capture host, and native text frames do not separate loading from failure. Worked
  around in ticket 06 with completion plus bounded quiescence gates, phase identity from pixel
  comparison plus independent controls, and a delayed-loader probe. No production change needed.
- Historical macOS quote-truncation source (ticket 04): not recoverable from repository history, so
  the new long-quote fixture does not prove that old defect is fixed.
