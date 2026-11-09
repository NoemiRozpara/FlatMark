# Testing FlatMark

[Package usage](../README.md) · [Construction benchmarks](../Benchmarks/README.md) ·
[Capture references](References/RecipeLab/README.md)

## Shared demo snapshot coverage

Static presentation snapshots now use `FlatMarkCustomDocumentFixture` and the shared
recipe in `Support/FlatMarkFixtures/FlatMarkRecipeSample.swift`. Recipe Lab builds
its document from the same sections used by focused captures. There is no separate
Markdown sampler for these cases.

| Shared recipe captures | Replaces custom snapshot content |
| --- | --- |
| Full document, light and dark | Typography sampler and fixed recipe section crops |
| Narrow/wide and RTL baking instructions | Nested quotes, list continuations, and wrapping |
| Dimpling paragraph and checklist with custom replacements | Mixed image/text flow and inline/block HTML replacement |
| Default/custom tasks, interactive/read-only/disabled, retained document | Task-marker presentation matrix |
| Omit and empty replacements | Static unsupported-policy presentation |
| Images without a loader, narrow/wide and enlarged iOS text | Linked/unlinked placeholders and adjacent hard breaks |

The matrix has 18 macOS scenarios and 23 iOS scenarios. Enlarged iOS captures use
real Dynamic Type. Each scenario keeps one scroll view and document mounted across
its pages. Captures check the actual scroll offset, reach the content bottom, and
assert that scrolling does not start new image requests. A final page may overlap
its predecessor. Page-boundary clipping and horizontal table clipping are expected.
Frame stability and loader request counts are readiness gates, not proof of drawing.

Focused fixtures remain where the demo does not express the tested contract:

- held image loading, throwing failures, empty alt labels, and exact raster sizes;
- retained policy/image transitions and request lifecycle checks;
- table scroll offsets, internal empty tables, and native cell layout bounds;
- omission/control pairs and deliberately empty tasks, ordered rows, and table cells;
- the consecutive-hard-break regression and native baseline/paragraph probes.

The empty-replacement payload-dispatch assertion remains in the mounted shared-fixture
policy test. The duplicate initializer-path pixel test is retired; that same mounted
test still traverses all six policy edges through both initializers and checks source,
requests, task updates, and host dispatch. Removing static captures did not remove
those semantic checks.

### Consolidation verification

Verification used Xcode 27 RC / Swift 6.4, macOS 27.0.1 on a 2x display, and the
iPhone 18 Pro simulator running iOS 27.0.

- Recorded 25 macOS and 53 iOS recipe references. Recording assertions were expected
  failures, not verification passes. Retired references were removed, not re-recorded.
- `swift test`: 222 tests in 30 suites passed, with the existing known LoaderSpy issue.
- Non-recording `FlatMarkSnapshots-macOS`: 51 tests passed.
- Non-recording `FlatMarkSnapshots-iOS`: 53 tests passed. The 23-case recipe matrix
  also passed a separate repeat run.
- Reviewed all 41 scenario contact sheets and 10 representative original PNGs.
  No unintended blank capture, missing selected-section ending, or actual content
  overlap was observed within that review. This is not full-size approval of every PNG.
- Both demo targets compiled. Full running-app observation of every setting, live
  VoiceOver, selection gestures, and minimum-runtime compatibility remain unverified.

Historical suite counts and namespace mappings below predate this consolidation.
Manual [Recipe Lab captures](References/RecipeLab/README.md) were not refreshed.

## Native macOS image paragraphs — issue #41

Both platforms now render all image phases in native attributed paragraphs. The custom flow
layout and renderer selector are removed. Earlier descriptions of whole-value SwiftUI image
routing below are historical and do not describe the current implementation.

macOS uses fresh attachments for each measurement graph and committed width. Unsupported inline
output and image labels resolve at render time, before sizing probes. Request ownership stays in
`FlatMarkInlineView`. Native image-link children receive destination-first names and use the
current text-view delegate. Ordinary native links remain separate.

Verification on 2026-11-05 used arm64 macOS 27.0.1 (26A434), Xcode 27 RC, Apple Swift 6.4,
and a 2x display. iOS checks used the iPhone 18 Pro simulator with iOS 27.0.

- `swift test`: 261 tests in 35 suites passed, with one existing known issue in `LoaderSpyTests`.
- `FlatMarkSnapshots-macOS`: 88 tests passed in a separate non-recording run.
- iOS paragraph, image-phase, and linked-image suites: 30 tests passed, with no reference changes.
- New mounted checks cover reverse image completions in source order, retained width changes
  without new requests, intrinsic small-image sizing, isolated unchosen-width attachment probes,
  late completion after replacement, repeated image destinations around an ordinary link,
  current phase/width accessibility frames, stale-target rejection, and one opener call per action.
- Updated 29 macOS references for native paragraph typography, baseline placement, wrapping,
  and the static hourglass. No comparison tolerance changed. Small and oversized raster-only
  references passed unchanged. Prior environment-sensitive pixel failures remain historical;
  none reproduced in the final runs.
- Reviewed a contact sheet of the changed references and full-size representative native
  placeholder, mixed loaded, and policy-transition captures. This is not full-size approval
  of every reference.
- Built and launched `FlatMarkDemo-macOS`. Captures of the same running recipe window at
  900×1000 and 560×900 points show the loaded photo and reflowed surrounding text. The wide
  image keeps its intrinsic width; the narrow image shrinks to the text column. Captures used
  the current native macOS process, not another running simulator host.

Live VoiceOver and actual selection/copy gestures remain unverified. Running-demo checks for
all non-success phases, multiple images, long/empty labels, RTL, enlarged text, and image-bearing
heading/list/table contexts remain incomplete. Automated exports, direct accessibility actions,
and snapshots do not replace those observations. No iOS running-app observation was repeated;
its presentation is unchanged and the affected automated suites passed. Minimum-runtime
macOS 14/iOS 17 compatibility remains unverified.

Diagnostic artifacts are in the MobileBuildMCP workspace
`~/Library/Developer/MobileBuildMCP/workspaces/image-rendering-attachment-mac-f8fe33f9b2d3/`.
The final macOS result stem is `test_macos_2026-11-05T12-11-16-201Z_pid20325_348d4326`.
The iOS result stem is `test_sim_2026-11-05T12-01-22-044Z_pid16538_157be391`.

## Native image accessibility — wrapper removal (historical)

The iOS renderer now uses a plain `UITextView` with attributed attachments. The custom
accessibility wrapper, image identity/label metadata, and wrapper-only accessibility test
were removed. Earlier wrapper qualification below is historical, not the current contract.
See [layout and accessibility limits](../README.md#layout-and-selection-limits).

The user tested the plain native path on both platforms and reported that all content was
reachable and links were active. iOS announced “Attachment png link”; macOS announced “Link”.
These are user-reported observations, not guaranteed wording. Runtime versions, fixture,
and navigation actions were not recorded for that manual check.

After removal, the iOS paragraph suite passed 18 tests on the iPhone 18 Pro simulator with
iOS 27.0. The macOS image-loading suite passed 14 tests. These checks do not establish live
VoiceOver behavior. No snapshots were recorded during wrapper removal.

## Image attachment recovery verification — 2026-11-05

After recovering the image attachment changes, both snapshot Record schemes ran on
macOS 27 and the iPhone 18 Pro simulator with iOS 27.0 using Xcode 27 RC.
Recording updated 103 tracked PNGs: 64 iOS and 39 macOS. Recording assertions are
expected failures, not verification passes.

Separate non-recording checks:

- `swift test`: 262 tests in 35 suites passed, with one known issue.
- `FlatMarkSnapshots-macOS`: 85 passed.
- `FlatMarkSnapshots-iOS`: 103 passed and 3 reported failures. No pixel mismatches
  remained. First-baseline assertions differed by 22 and 38 points. The primary
  and dark recipe checks measured 2417.33 points against a 2320-point fit limit.
- The iOS composition-count/accessibility-element identity test and image-phase
  composition test passed on the simulator.
- Contact-sheet inspection covered all 103 changed PNGs. This is not full-size
  visual approval. The enlarged iOS recipe shows crowded/overlapping introductory
  text, and recipe fit assertions remain unresolved. These references record the
  current output, not a claim that all layouts are correct.

MobileBuildMCP result bundles and logs are under
`~/Library/Developer/MobileBuildMCP/workspaces/image-rendering-attachment-29a5db523f8d/`.
The final verify result stems are `test_sim_2026-11-05T11-08-02-942Z_pid1540_1958d046`
and `test_macos_2026-11-05T11-08-39-537Z_pid1684_cce873db`.
Live VoiceOver, selection gestures, and minimum-runtime compatibility were not tested.

## Native-text qualification — branch delivery

This batch is stopped. It does not complete the migration or the full #31 qualification.
No further execution is required by this document. Remaining work is deferred, not passed.
Earlier qualification records below describe their own revisions and do not qualify this HEAD.

| Work | Delivered status | Commit |
| --- | --- | --- |
| #32 attributed content and semantic typography | Focused UIKit/AppKit attribute and composition coverage. | `19c7170` |
| AppKit minimum-width regression | Zero-width proposals no longer report the unwrapped ideal width. | `c320753` |
| AppKit baseline isolation | Private, synchronous TextKit measurement disables background layout and is safely nonisolated. | `af5ffe7` |
| #33 retained updates and measurement | Accepted by owner exception: AC-24 failed, AC-25 partial. | `a1bd49f` |
| #34 lists, tables, and image routing | Added native baseline/row geometry checks; reused image-routing/lifecycle evidence. | `4b1ed22` |
| #35 navigation | Added callback/opener freshness and independent-control coverage; retained UIKit action check deferred by owner. Other iOS interaction limits remain below. | `3ea0804` |
| #36 selection/copy/VoiceOver | Not started in this batch. No new human VoiceOver or selection/copy qualification. | — |
| #37 final consolidation | Not completed. No final full-suite, affected-snapshot, both-demo-build, minimum-runtime, or rendering-cost qualification. | — |

### Scope and known issue

FlatMark owns native conversion, typography, configuration, measurement, and navigation wiring.
Hosts retain source, services, navigation decisions, and custom content ownership. At that revision, image-containing values still used the whole existing SwiftUI renderer.
That transitional layout has since been removed by #41; this historical batch added no
attachments or replacement image-lifecycle suite. No new defect in that transitional path was established.

The UIKit test
[`proposalProbesAndTrailingBreaksKeepCommittedLayoutSeparateFromNeighbor`](FlatMarkTests/Snapshots/FlatMarkParagraphTextTests.swift)
allocates **116pt**, while native terminal-line geometry ends at **132pt**. Source-bearing
lines end at 110pt. Removing explicit proposal probes produces the same discrepancy.
This fixture mounts the native bridge directly, so the issue is not attributed to the
transitional image renderer. Visible clipping, overlap, and a production sizing defect have
not been established; UIKit's terminal-empty-line allocation contract remains unresolved.

The owner accepted #33 with **AC-24 failed and AC-25 partial**. Only this fixture's
terminal-inclusive containment assertion is wrapped in `withKnownIssue`. Source-bearing
containment, native configuration, container geometry, and neighboring-frame separation remain
ordinary expectations. No terminal-line sizing fix was made. The targeted run passed with one
expected known issue; this is not an AC-24 pass.

### Coverage and deferred evidence

| Criteria | Evidence delivered | Limit |
| --- | --- | --- |
| AC-01–11, AC-16 | Unicode/order, breaks, combined traits, literal/omitted/multi-run composition, inheritance and explicit host precedence; framework-resolved body/headings/header fonts on both platforms. | Storage/font evidence, not visible glyphs or accessibility. Existing projector tests supply break-projection evidence. |
| AC-12–15, AC-17 | Retained UIKit normal → accessibility → normal typography/height; fixed host fonts; following-frame separation; retained document setting updates. | No claim of system Settings propagation or selection preservation. |
| AC-18–23 | Native configuration, offered/container widths, narrow → wide → narrow, replacement updates, source order and independent alignment/direction checks. | Native geometry/attributes do not establish every visual state. |
| AC-24–25 | AppKit trailing lines and native-frame separation checked; UIKit terminal-line exception above. | AC-24 failed; AC-25 partial. No observed overlap. |
| AC-26–27 | Wrapped-label first-line baselines, including host-font metrics; multiline native table-cell containment and next-row separation. Ordinary/accessibility iOS sizes and standard macOS. | Reviewed existing static references; no new pixel comparisons. |
| AC-28 | Unspecified/infinite/unchosen proposal probes followed by a committed native width. AppKit zero/minimum width has a separate regression test. | iOS demo remains fixed-width; its rotation does not qualify width transitions. |
| AC-29–33, AC-35–36 | macOS isolated native-click host checks destination/decision routing, zero render-time calls, inert prose, neighbors and callback addition/removal. iOS retained public adapter checks current decisions/openers and zero update-time calls. | Direct iOS coordinator invocation is not native link activation. Actual iOS link/inert-neighbor interaction remains unverified. |
| AC-34 | Retained macOS callback/opener tests and iOS public-adapter freshness. | Owner deferred retained UIKit `primaryActionFor` action dispatch. Human-assisted capture test/helper were removed; no capture procedure remains. |
| AC-37–38, AC-41 | Shared image routing/style inspection and existing image phase/policy/loading suites reused. `containsImages` routes the whole value outside native conversion before phase handling. | Structural and historical evidence, not fresh image-path pixel qualification. Request/loading production code was unchanged. |
| AC-39–40 | macOS block → task → block → native link checks exact independent counters/source/destination. An actual iOS task tap changed only that task. | Live iOS block/task/link independence remains unverified. |
| AC-42–47 | No new selection/copy or live VoiceOver qualification in this batch. | Deferred with #36. Existing export or accessibility structure is not equivalent to gestures or speech. |

The removed retained-action example timed out before receiving a system action; it established
neither freshness nor a production defect. Existing adapter coverage does not close that gap.
No private `UITextItem` construction, production test hook, or external browser opening was added.

### Recorded environment and results

Runs took place on 2026-11-04: arm64 macOS 27.0.1 (26A434), Xcode 27.0 (27A266a),
Apple Swift 6.4 (`swiftlang-6.4.0.34.1`), developer directory
`/Applications/Xcode-27-RC.app/Contents/Developer`. iOS runs used iPhone 18 Pro / iOS 27.0,
simulator `674C04A9-8792-4995-A6A9-66F80E5F96AA`. Scheme/destination discovery preceded runs.
These results do **not** qualify iOS 17/macOS 14 or Xcode 26/Swift 6.2.

| Selection | Recorded result | Revision context |
| --- | --- | --- |
| #32 AppKit attributes; UIKit paragraph suite; AppKit composition/mentions | 8 methods; 14 methods; 8 methods passed, respectively. Initial composition selector matched zero and was corrected. | Base `6297caf`, delivered in `19c7170`. |
| #33 initial AppKit/retained UIKit checks | 5 AppKit methods and 14 UIKit methods passed; 2 affected UIKit methods passed after active-TextKit inspection correction. | Base `19c7170`, delivered in `a1bd49f`. Initial legacy-layout inspection was superseded. |
| #33 proposal/alignment additions | AppKit proposal method and UIKit parameterized alignment method passed. UIKit terminal-line case failed, then passed with one owner-authorized expected issue. | Same #33 development patch. |
| AppKit minimum-width regression | New test failed before fix (zero and ideal both 369pt), then passed; 2 affected existing methods passed. | Delivered in `c320753`. |
| AppKit baseline isolation | 2 focused methods passed. | Delivered in `af5ffe7`. |
| macOS demo build | One explicit-arm64 build succeeded; affected production files compiled without the baseline actor warning. Reported exit-0 SwiftCompile failure did not reproduce. Unrelated AppIntents warning remained. | Fix2 development patch. |
| #34 geometry/routing/loading | 24 macOS tests and 4 iOS tests passed. | Base `a1bd49f`, delivered in `4b1ed22`. |
| #35 navigation/independent controls/iOS adapter | 12 macOS navigation methods, 1 independent-control example and 1 iOS adapter method passed. | Base `4b1ed22`, delivered in `3ea0804`. |
| iOS demo | Built/launched; actual task tap observed. A paragraph-container tap was not counted as link activation. | #35 development patch. |

No snapshot baseline was recorded. Historical task/nested-container/table references were
inspected for #34; they are static references, not captures of retained transitions at HEAD.
No full package suite or broad snapshot comparison was run for this final batch. Passing
checks were not rerun merely for independent review. Documentation cleanup ran no builds/tests.

### Commands and diagnostic artifacts

These are the executed focused selections, not instructions to resume deferred work.
Simulator commands used `FlatMarkSnapshots-iOS` in `Demo/FlatMarkDemo.xcodeproj` with the
explicit simulator above. Local `/tmp` logs and result bundles are diagnostic artifacts,
not committed baselines or durable evidence links.

```sh
# #32
swift test --filter 'FlatMarkAppKitParagraphTextTests/(combinedIntents|literalAndOmitted|bodyUses|explicitEmpty|headingRoles|tableHeaderRole|inlineTraits|hostFont)'
mobilebuildmcp simulator test --project-path Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS --simulator-id 674C04A9-8792-4995-A6A9-66F80E5F96AA --extra-args '-only-testing:FlatMarkSnapshots-iOS/FlatMarkParagraphTextTests'
swift test --filter 'FlatMarkCustomUnsupportedContentTests/`(inline replacements|replacement runs|host intent|replacement uses|host font|replacement links)|FlatMarkMentionTests/`(opted in mentions|mention styling)'
# AppKit fixes
swift test --filter 'FlatMarkAppKitMinimumProposalTests/zeroWidthProposalDoesNotReportUnwrappedIdealWidth'
swift test --filter 'FlatMarkAppKitParagraphTextTests/(unchosenProposalsDoNotChangeCommittedNativeWidth|nativeParagraphsMeasureOfferedWidthWithoutOverlappingFollowingText)'
swift test --filter 'FlatMarkAppKitBaselineIsolationTests|FlatMarkAppKitParagraphTextTests/inlineTextExportsTheFirstLineBaselineToSwiftUI'
mobilebuildmcp --log-level debug macos build --project-path Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkDemo-macOS --configuration Debug --arch arm64 --derived-data-path .build/demo --prefer-xcodebuild --verbose
# #33 owner exception
mobilebuildmcp simulator test --project-path Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS --simulator-id 674C04A9-8792-4995-A6A9-66F80E5F96AA --extra-args '-only-testing:FlatMarkSnapshots-iOS/FlatMarkParagraphTextTests/proposalProbesAndTrailingBreaksKeepCommittedLayoutSeparateFromNeighbor()'
# #34
swift test --filter 'FlatMarkTaskMarkerSnapshotTests/wrappedNativeLabelExportsFirstLineBaseline|FlatMarkTableSnapshotTests/multilineNativeCellsStaySeparateFromNextRow|FlatMarkDocumentViewTests|FlatMarkImageLoadingTests'
mobilebuildmcp simulator test --project-path Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS --simulator-id 674C04A9-8792-4995-A6A9-66F80E5F96AA --extra-args '-only-testing:FlatMarkSnapshots-iOS/FlatMarkTaskMarkerSnapshotTests/wrappedNativeLabelExportsFirstLineBaseline()' '-only-testing:FlatMarkSnapshots-iOS/FlatMarkTaskMarkerSnapshotTests/accessibilityWrappedNativeLabelExportsFirstLineBaseline()' '-only-testing:FlatMarkSnapshots-iOS/FlatMarkTableSnapshotTests/multilineNativeCellsStaySeparateFromNextRow()' '-only-testing:FlatMarkSnapshots-iOS/FlatMarkTableSnapshotTests/accessibilityMultilineNativeCellsStaySeparateFromNextRow()'
# #35
swift test --filter 'FlatMarkNavigationTests'
swift test --filter 'task checkbox link and block host button'
mobilebuildmcp simulator test --project-path Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS --simulator-id 674C04A9-8792-4995-A6A9-66F80E5F96AA --extra-args '-only-testing:FlatMarkSnapshots-iOS/FlatMarkParagraphTextTests/retainedPublicNavigationAdapterUsesCurrentOptionalCallbackAndOpener()'
mobilebuildmcp simulator build-and-run --project-path Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkDemo-iOS --simulator-id 674C04A9-8792-4995-A6A9-66F80E5F96AA
```

Recorded logs: `/tmp/flatmark32-macos.log`, `/tmp/flatmark32-ios.log`,
`/tmp/flatmark32-composition-selected.log`, `/tmp/33-owner-exception-ios.log`,
`/tmp/flatmark-fix1-{red,green,affected}.log`, `/tmp/flatmark-fix2-baseline.log`,
`/tmp/flatmark-fix2-demo-arm64-full.log`, `/tmp/flatmark34-{macos,ios}.log`,
`/tmp/35-macos-tests.log`, `/tmp/35-controls.log`, `/tmp/35-ios-final.log`.
MobileBuildMCP retains corresponding logs/result bundles under
`~/Library/Developer/MobileBuildMCP/workspaces/native-attributed-text-rendering-e6253af6ee59/`.

### User-reported observations

After the AppKit fixes, the user reported no warnings, normal window size/resizing,
visible and correct RTL/LTR layout, and working macOS links. The user reported the iOS
manual checks passed except the fixed-width reading column. Revision/build correspondence,
OS, toolchain and dimensions were not recorded, so these are supporting user observations,
not revision-matched qualification or proof of all navigation decisions.

Selection/copy, live VoiceOver, minimum-runtime checks, retained UIKit action dispatch,
full iOS link/control interaction and final rendering-cost assessment remain deferred.
No performance guarantee or complete migration qualification is claimed.

## Native iOS image paragraphs (#40)

The iOS renderer now composes all image phases in native paragraph storage. macOS retains its
SwiftUI image flow. The #29 results below describe the earlier implementation, not this change.

Verification used Swift 6.4 on macOS 27 and an iPhone 18 Pro simulator running iOS 27.0 through
MobileBuildMCP. These runs do not establish iOS 17 compatibility. No references were recorded.

- The iOS demo compiled. UIKit paragraph tests passed 15/15 after fixing duplicate image
  accessibility boundaries. A later measurement-identity fix compiled, but final test retries
  terminated the test host with signal TERM; that final revision is not fully test-verified.
- New paragraph checks cover source order, Unicode, explicit breaks, RTL attributes, intrinsic and
  proportional image bounds, phase descriptions, separate same-destination images, direct actions,
  and stale accessibility targets. Direct actions do not prove live VoiceOver or link gestures.
- Focused iOS image-phase, linked-image, and policy-transition snapshots: nine passed, eight failed
  pixel comparisons. Fresh visual review and intended reference updates remain outstanding.
- macOS image-loading tests: 14 passed. `swift test --skip Snapshot`: 186 passed with the existing
  known LoaderSpy issue. Full `swift test`: 254 tests, 37 issues including that known issue.
  Snapshot failures were not recorded away; their full provenance remains unverified.
- Running-demo phase/width observations, selection/copy gestures, system text scaling, and live
  VoiceOver order, names, reachability, and activation remain unverified for this implementation.
- Held reverse-order completion and retained-mount width/request-count scenarios still need
  explicit native iOS integration qualification; attributed-storage sizing checks are narrower.

## Integrated native text qualification (#29)

This section is the current evidence for #25–#28. Earlier sections are historical reports, not
qualification of later code. In particular, historical macOS enlarged-text observations and
reference counts below no longer describe the registered snapshot inventory.

### Boundary and inspection

Image-free paragraphs, headings, list labels, and table cells use selectable, noneditable native
text by default. Their supported and replacement runs share storage, without synthetic spaces.
Body/headings use semantic system fonts; table headers use bold body text. Explicit host native
fonts/colors win per run, including fixed fonts. Missing replacement intents/links inherit; explicit
values and explicit empty intents win. Arbitrary ambient SwiftUI font/foreground-style/tint
inheritance is not promised. Selection may reset on content, styling, or measurement updates.
Neither selection preservation nor cross-block selection is promised. See the authoritative
[layout contract](../README.md#layout-and-selection-limits) and [support matrix](../SUPPORT.md).

Inspection confirms that `containsImages` selects the whole old renderer before native conversion,
in every image phase. Block overrides, task controls, and fenced code remain outside conversion.
Finite positive offered widths control native measurement; other proposals retain native sizing.
Writing direction and leading/trailing alignment resolve separately. Native delegates refresh their
opener on updates. `activationOpenURL(inheriting:)` calls the host decision and delegates default
opening once to the inherited opener, not a browser-opening substitute.

### Environment and automated results

Run on 2026-11-04: Xcode 27.0 (27A266a), Swift 6.4, arm64, macOS 27.0.1 (26A434), built-in
3456×2234 Retina display; iPhone 18 Pro simulator on iOS 27.0. These are not minimum-platform results.
Build/test commands used MobileBuildMCP with `Demo/FlatMarkDemo.xcodeproj`, discovered schemes,
and the booted simulator. No reference recording or comparison-tolerance changes were made.

- `swift test`: 254 tests in 33 suites, **not green**. Ten issues include the known LoaderSpy issue
  and nine image-path pixel comparisons. The same comparison failures occur before and after the
  fixture change. No native text behavior assertion failed.
- `swift test --skip Snapshot`: 186 tests in 20 suites passed, with the known LoaderSpy issue.
- `FlatMarkSnapshots-iOS`: 93/93 passed before the new fixture test; **94/94 passed twice** after its fix.
  The test first failed at 17pt versus the expected 40pt for `.accessibility3`. Normal Recipe Lab
  mode now inherits ambient Dynamic Type; the explicit enlarged preset still uses `.accessibility2`.
  This mounted environment test is not an actual system Settings transition.
- Regeneration exposed an omitted AppKit test source in the checked-in project. The macOS target
  now includes it and the existing mounted/selection helpers. `FlatMarkSnapshots-macOS` runs
  **80 tests: 74 pass, six fail**, all in image snapshot tests. The earlier 68-test run omitted the
  twelve AppKit test methods and must not be used as complete native-output evidence.
- The failing macOS methods are `linkedImagePresentationMatchesReviewedBaseline`,
  `smallIntrinsicRaster`, `oversizedRaster`, `mixedLoadedText`,
  `loadedImageDescriptionDoesNotReload`, and `freshMountsStartNewRequests`.
  Comparisons include repeated phase/mount captures. An ImageMagick 0.5% fuzz diagnostic found
  zero differing pixels in the seven reference/actual pairs printed by the initial macOS result.
  That diagnostic supports the documented exact-pixel environment limitation; it does not make
  the exact suite green or qualify every image phase visually. References were not recorded away.
- Both `FlatMarkDemo-iOS` and `FlatMarkDemo-macOS` build and launch with the changed fixture.
  `cd Demo && xcodegen generate` regenerated the project, including the previously omitted tests.
- `swift test list` confirms the removed macOS snapshot methods no longer register. Fourteen
  iOS-only enlarged methods retain their source and all fifteen iOS PNGs. All fifteen artificial
  enlarged macOS PNGs are deleted. The inventory includes `enlargedEmptyTask` and
  `enlargedNarrowNeighborsKeepTheirSpacing`, beyond the issue's initial anchors.
  Standard-size, narrow/wide, RTL, image-phase, task, and navigation cases remain. Shared iOS sizing
  support and the separate enlarged image-flow behavior test remain.

### Evidence by lane

| Lane | Current evidence | Limits |
| --- | --- | --- |
| Native output | UIKit/AppKit paragraph tests cover combined traits, Unicode/order, consecutive/trailing breaks, semantic roles, per-run host precedence, and direction versus alignment. Shared custom-content tests plus UIKit replacement tests cover multi-run inheritance/overrides without changing neighbors. | Exports/attributes are not glyph visibility or live accessibility. |
| Mounted updates | Retained UIKit/AppKit tests cover width/content/direction/attributes and following-block separation; UIKit also covers mounted environment Dynamic Type changes. AppKit tests verify the first baseline. | Actual system-driven iOS Dynamic Type transitions, including accessibility categories, remain unverified. |
| Navigation | Package navigation tests pass, including retained callback/opener replacement, supported/replacement links, handled/rejected/default/omitted callbacks, independent links, and inert neighbors. UIKit's primary-action delegate coverage was previously claimed here without a corresponding test; that claim is withdrawn (see [branch delivery](#native-text-qualification--branch-delivery)). | macOS uses the controlled isolated click host; iOS delegate tests are not native link gestures. Live demo link activation remains unverified on both platforms. |
| Image/control preservation | Existing image lifecycle, custom block, task, and navigation tests remain; iOS production snapshots pass. Routing inspection preserves image-containing values as a whole. | macOS image pixel failures remain as reported above. No new blanket image qualification. |
| Selection — iOS / macOS | Native selectability and macOS selection exports are automated. | Actual selection gestures/copy and selection-reset observations are unverified on both platforms. |
| VoiceOver — iOS / macOS | No new accessibility wrapper was added. | No live VoiceOver operator session was available. Wording/order, independent supported/replacement link reachability/activation, and absence of duplicate announcements remain unverified on both platforms. Semantic exports and screenshots are not substitutes. |

### Running-host observations and rendering costs

Both Recipe Lab apps were launched, not just compiled. iOS at its existing 240pt reading column
shows the title, wrapped bold/italic/strike/mention paragraph, literal HTML fallback, photo, and
following Ingredients heading with clear separation in the inspected viewport. Scrolling changes
the visible region normally. The macOS recipe at a 1325pt window shows the same upper structure,
complete paragraph wording, photo, and following heading. These are limited viewport observations,
not full-document, table/task, blank-line, RTL-transition, or link-interaction qualification.

For a proportionate macOS cost check, the existing Markdown source editor received a heading and
200 copies of this paragraph, separated by blank lines:

```markdown
A **bold** café 👩🏽‍💻 paragraph with *italic* wording and English עברית العربية. A wrapping sentence that ends with END.
```

The mounted host accepted the update and exposed 200 native paragraph controls. Its window was
resized 763 → 1325 → 763pt, then the source was replaced with a heading, one longer mixed-direction
paragraph ending `THIRD END.`, and `Following paragraph.`. The inspected final capture shows the
longer paragraph wrapping completely with its following block separate. The host remained responsive
to these editor/window operations; no hang or overlap appeared in the inspected upper regions.
This is an uninstrumented smoke assessment, not latency/allocation measurement or a performance
promise. It does not establish long-document iOS rendering cost, sustained scrolling cost, or the
visibility of all 200 paragraphs. No construction benchmark was substituted for native rendering.

### Outstanding qualification

The ticket's runtime acceptance is incomplete: live VoiceOver, actual selection/copy gestures,
live independent text links, system-driven iOS text-size changes, visual consecutive blank lines,
and the full two-platform direction/container/update matrix still need operator checks. Long-text
iOS rendering cost is unassessed. Minimum iOS 17, macOS 14, and Xcode 26/Swift 6.2 execution remain
unverified. Local logs/captures are under `/tmp/flatmark29`; MobileBuildMCP logs/result bundles live
under its reported workspace paths. Temporary artifacts are not durable reference baselines.

## Native inline roles and macOS baseline correction (#27)

Image-free headings, list labels, and table cells now share the paragraph bridges. Headings resolve
semantic level fonts; table headers resolve bold body typography. Image-containing values retain
the complete SwiftUI path. The macOS inline entry supplies a first-text-baseline alignment guide
from TextKit glyph geometry. Overriding the native view's baseline alone did not affect SwiftUI.
Markers and task controls remain siblings of the text.

Verification environment: Xcode 27.0 (27A266a), Swift 6.4, macOS 27.0.1 (26A434), arm64,
and iPhone 18 Pro simulator on iOS 27.0. Minimum OS/toolchain behavior remains unverified.

- A mounted baseline test compares the inline entry with SwiftUI body text. Removing the alignment
  guide fails with a 13-point baseline difference; restoring it passes. Fresh macOS task captures
  show aligned first lines for default/custom markers and RTL rows, including wrapped labels.
- Re-recorded nine affected namespaces: Typography, Tables, NestedContainers, TaskMarkers,
  UnsupportedPolicies, PolicyTransitions, Recipe, OmissionSpacing, and EmptyStructures. Relative to
  the preceding commit, 72 macOS and 45 iOS PNGs changed. Image-only suites and three image-only
  macOS PolicyTransitions references remain unchanged. No comparison tolerance changed.
- Inspected all changed captures in trimmed contact sheets, plus the full-size macOS baseline
  capture. Text, table endpoints, nested list labels, custom replacements, and recipe sections remain
  visible in the inspected captures. This is static capture review, not live interaction evidence.
- The affected macOS selection passes 54 tests in nine suites twice. It excludes the unchanged
  image-description and fresh-image-mount cases. `swift test --skip Snapshot` passes 181 tests in
  20 suites, with one known LoaderSpy issue. Focused bridge/custom-content checks pass 35 tests.
- The full iOS target passes 91/91 on two runs. An intervening run passes 89 tests but reports a
  killed fresh-mount test and a runner bootstrap failure; a later full run passes 91/91.
- The final full package run selects 263 tests and reports 11 issues, including the known issue:
  nine comparisons in unchanged image paths and one image-loader confirmation timeout. The isolated
  loader test passes afterward. The full package suite is not green; image-path failures were not
  hidden by re-recording those references.
- Reference SHA-256 manifests remain identical through final verification. `git diff --check` passes.
  Logs, pre-record references, manifests, and review sheets are under `/tmp/flatmark27-review/`.

The earlier demo builds/launches do not qualify the corrected macOS baseline in a running app.
Independent live task/link/block activation, selection, VoiceOver, and minimum-platform checks
remain unperformed for this correction.

## Native macOS paragraphs (#26)

Image-free macOS paragraphs now use selectable, noneditable `NSTextView` storage with AppKit's
preferred body font. Paragraphs containing Markdown images retain their existing renderer.
Explicit native fonts/colors and SwiftUI foreground/background colors survive native defaults.
Sizing probes use separate TextKit storage; the displayed container follows the allocated frame.
AppKit ensures layout before drawing so cached glyphs do not retain an earlier width.

Verification environment: Xcode 27.0 (27A266a), Swift 6.4, macOS 27.0.1 (26A434), arm64,
built-in Retina display. This does not qualify macOS 14 or Xcode 26.

- Five focused test methods pass. They cover native Unicode and combined traits, per-run host
  precedence, RTL direction versus alignment, initial 140/280-point layout, and trailing empty lines.
- `swift test --skip Snapshot` passes 175 tests in 20 suites, including one known LoaderSpy issue.
  Mounted exports use a temporary pasteboard and AppKit's advertised legacy export types.
- The isolated navigation suite passes eight methods, including handled/rejected/default/omitted
  decisions, inherited/explicit replacement links, independent adjacent links, and inert text.
  The host now checks the fixed click point against native glyph geometry for leading native links.
- `swift test` selects 257 tests in 33 suites and fails with 79 issues, including the known issue:
  77 snapshot comparisons and one image-link host timeout during the concurrent full run.
  The isolated navigation rerun passes. No snapshot references were recorded. These comparisons
  include intentional native typography changes and existing environment-sensitive captures;
  they have not been fully classified or visually qualified.
- `FlatMarkDemo-macOS` builds and launches. `FlatMarkDemo-iOS` compiles for the iPhone 18 Pro
  simulator on iOS 27.0. The shared edit only changes paragraph routing's platform guard.
- Running-demo screenshot inspection caught clipped cached glyphs despite a correctly sized frame.
  After ensuring native layout before drawing, the inspected recipe paragraph wraps completely,
  shows bold/italic/strike styling, and remains separate from the following photo.

Wide-column and mixed-direction running-demo checks, visible blank-line inspection, independent
live demo links, minimum-platform behavior, and visual baseline qualification remain incomplete.
Exported wording and automated layout checks do not establish those observations. Retained-update
qualification belongs to #28; integrated selection and live VoiceOver belong to #29.

## Native iOS paragraphs (#25)

Image-free iOS paragraphs now use selectable, noneditable `UITextView` storage. Every paragraph
containing a Markdown image keeps its existing renderer in all phases. Other inline callers and
macOS keep their existing presentation.

The agreed font boundary preserves native `UIFont` attributes. SwiftUI `Font` attributes instead
use semantic native typography. Explicit native foreground/background colors and SwiftUI
foreground/background colors are preserved per run.

### Verification

Environment: Xcode 27, Swift 6.4, macOS 27.0.1 (26A434), iPhone 18 Pro simulator on iOS 27.0.
These results do not qualify the minimum toolchain or OS.

- Five iOS test methods cover native Unicode storage, combined intents, consecutive newlines,
  replacement inheritance and explicit overrides, host fonts/colors, Dynamic Type resolution,
  direction versus alignment, and mounted initial layout at 140- and 280-point widths.
  Mounted checks establish inset-free selectable controls, offered widths, sufficient measured
  heights, and separation from a following paragraph. They do not establish glyph visibility.
- Visual comparison caught missing SwiftUI background colors. A targeted assertion failed before
  the fix and passed afterward. All 50 changed iOS references were reviewed at readable scale,
  then recorded for native typography, wrapping, and paragraph direction. Custom badges remain
  visible. Image-only references were not changed.
- The final full iOS snapshot target passed **87/87 twice**. Reference hashes stayed unchanged
  during both comparison runs.
- `swift test --skip Snapshot` passed **170 tests in 19 suites**, with the existing known LoaderSpy
  issue. The full `swift test` run selected **252 tests in 32 suites** and failed on snapshot
  comparisons (42 reported issues, including the known issue); it was not a green package run.
- The macOS demo compiled. Its snapshot target passed 52 tests and failed 30. Of 38 mismatching
  captures, 35 had no differing pixels at ImageMagick fuzz 0.5%. The other three
  (`retainedPolicyTransitions.custom`, `retainedPolicyTransitions.changedCustom`, `rtlNestedQuote`)
  remain unqualified. No macOS references were recorded.
- Running iOS demo inspection at its fixed 240-point column showed complete wrapping, visible
  styled text, and separation from following blocks in the inspected recipe regions. It did not
  establish wide-column layout or consecutive blank-line appearance.

### Remaining checks

Live native text-link activation is unverified. The existing controlled demo opener returns handled,
but the available automation exposes no tappable native text-link targets. No image-link or task
activation was substituted for text-link evidence. Source inspection confirms the primary-action
delegate uses the current inherited `openURL`; handled/rejected/default and omitted callbacks were
not exercised through UIKit gestures. Rendering and measurement are not interaction evidence.

Selection gestures, VoiceOver, live system Dynamic Type changes, minimum-OS behavior, and visual
wide-column/blank-line checks remain unperformed. Retained-update qualification belongs to #28;
integrated live accessibility and selection belong to #29. Earlier results below are historical,
not qualification of the new paragraph path.

## Unsupported-content replacement contract (#18 chunk 1, tickets #19–#21)

`.custom` now takes a `(String) -> AttributedString` inline closure and an optional
`(String) -> AnyView` block override. Inline replacements compose with supported text as native
text. A replacement run inherits the enclosing Markdown presentation intent and link when the host
omits it; an explicit host value wins on its run, and an explicitly empty intent set suppresses
inheritance. Arbitrary views remain available only through the block override. Extraction,
`.literal`, and recursive `.omit` behavior are unchanged.

### Automated results

Environment: Xcode 27.0 (27A266a), Swift 6.4, macOS 27.0.1 (26A434), arm64. This is not the minimum
toolchain (Xcode 26.0+ / Swift 6.2, iOS 17+ / macOS 14+), so these runs do not establish
minimum-platform support.

- `swift test` after all three tickets: 252 tests in 32 suites. No non-snapshot test failed, plus the
  one intentional known `LoaderSpy` issue.
- Focused custom-content and navigation selection: 62 tests in 4 suites passed.
- Mounted native exports establish composed wording at narrow width, separate parser-node positions,
  unchanged extractions, bold inheritance, italic precedence, empty-intent suppression, per-run link
  destinations, and ambient heading fonts.
- Isolated macOS interaction tests establish that inherited and explicit replacement links activate
  through the existing host routing path, with handled, rejected, default, and omitted callbacks, and
  that adjacent supported links stay independent.

### macOS snapshot lane is currently unreliable

The exact-pixel lane fails about 35 captures in this environment, including ImagePhase, TaskMarker,
Typography, EmptyStructure, RecipeIntegration, LinkedImage, PolicyTransition, and UnsupportedPolicy
captures. The differences are sub-perceptual: `magick compare -fuzz 0.5% -metric AE` reports zero
differing pixels. SnapshotTesting demands exact pixels (`precision: 1`), so they fail.

This is machine state, not code. A pristine `git worktree` of the pre-ticket commit fails the same
captures, and no reference failed that was not already failing there. The qualified environment in
this file records a 2x macOS hosting display; these runs used only the built-in display. Treat these
failures as unverified, not as regressions, and do not re-record references to silence them.

### References re-recorded deliberately

The contract change alters the rendered output of the same 16 captures on each platform: 5 InlineFlow,
3 NestedContainers (including `rtlNestedQuote`, whose capture hosts the custom policy), 4
PolicyTransitions, and 4 UnsupportedPolicies. All 32 were re-recorded and inspected. The custom
captures use an attributed `BADGE` and attributed OPEN/CLOSE markers instead of the earlier arbitrary
inline views; the enabled/disabled captures now carry one block control each.

macOS: re-recorded through the package lane with `FLATMARK_SNAPSHOT_RECORD=all`, then confirmed by
plain comparison. The other ~35 captures still fail for the environment reason above and were left
alone.

iOS: re-recorded with the `FlatMarkSnapshots-iOS-Record` scheme on iPhone 18 Pro (iOS 27.0),
restricted with `-only-testing` to those four suites. Only the expected 16 references changed on
disk. Two separate `FlatMarkSnapshots-iOS` runs then passed **82/82** with no reference drift, and
the hash of every reference was unchanged by those runs.

Two review concerns on the new iOS captures are **pre-existing, not introduced here**: the
consecutive-hard-break capture shows no blank row, and the RTL mixed-flow marker sits at the line
end. A reviewer compared each new capture against its pre-change reference and found both behaviors
already present beforehand. The first is open as issue #5; the second is mixed-flow line behavior
related to open issue #17. These captures record current behavior rather than endorse it.

### Running-app observations

Performed in the shared fixture host on both platforms. Launch it with `scripts/run-fixture-host.sh
ios|macos`; `Replace tags` in Settings selects the `.custom` policy.

- iOS, iPhone 18 Pro simulator on iOS 27.0, scheme `FlatMarkDemo-iOS`: the block override rendered as
  a host button with no border or placeholder, and tapping it reported
  "The recipe: Dimpling tip: oil your fingertips, then press gently into the risen dough." in the
  activity strip. With the override off, the block rendered as plain native text. With "Replace with
  nothing" on, the block and inline labels disappeared, surrounding wording stayed intact, and no
  placeholder or synthetic space appeared. In the narrow column and in right-to-left layout, inline
  replacements composed with supported text, wrapped completely, and took heading and emphasis styling.
  Touching replacement text inside a linked note reported
  "The recipe: Tin note: use a 23 × 33 cm tin and oil the base and corners generously."; a separate
  supported image link reported its own "Rosemary note" activity. No browser opened.
- macOS 27.0.1, scheme `FlatMarkDemo-macOS`: the same block override, default native-text block,
  empty-output, narrow right-to-left composition, and both link activations reproduced, with the same
  activity-strip wording.

Joined wording such as "tipthe water" is the agreed flat rule: FlatMark adds no synthetic spaces.

### Not verified

Minimum-OS and minimum-toolchain behavior. Live VoiceOver and focus order. Selection gestures and
copy across replacements. System Dynamic Type (the fixture's size switch is not system settings).
A supported **text-only** link was not activated in the running app; only the supported image link
was. The macOS exact-pixel lane above is unverified rather than passing. No capture in this chunk
places a replacement inside a Markdown heading, so heading-style inheritance rests on the mounted
attribute checks and the running-app observation, not on a snapshot.

## Issue #4 verification in progress

List nesting now reserves its indentation inside the offered width and follows
layout direction. Row labels retain their full vertical size. Visual inspection
caught an ellipsis in the iOS narrow RTL list's `Final child bullet.` label;
the corrected reference shows the complete wording. The existing
`rtlNarrowListContinuations` snapshot guards that result.

The suites now include RTL narrow/wide list continuations, a nested quote, and
default/custom/enlarged task markers on both platforms. There are **218 PNGs**
under `Tests/References`, including manual assets. This is not completed
qualification:

- iPhone 18 Pro on iOS 27.0: the full snapshot lane passed **82/82 twice** after
  the label fix. Only the narrow RTL list reference changed during its recording;
  the other seven references in that suite stayed byte-identical.
- macOS: after the authorized pre-draw sRGB reference migration, the full
  non-recording lane passed **82/82 twice**. Verification left references unchanged.
  Early visual review covered all 13 suite contact sheets and selected full-resolution
  content crops; it found no obvious new rendering defect. See
  [the reference migration](#macos-srgb-reference-migration-and-early-review).
- Non-snapshot package selection: **163 tests in 19 suites passed**, with one
  known LoaderSpy issue.
- Recording changed all 109 macOS PNG files. iOS and manual reference files stayed
  byte-identical. Verification did not change the post-record hashes.
  `git diff --check` passed.
- Static reference inspection is not running-demo verification. Detailed LTR
  reference review and running-demo observations remain incomplete. Do not treat the
  historical qualifications below as approval of this change.

## Integrated qualification (ticket 14)

This section is the historical integrated result before issue #4. The ticket sections below retain
historical baseline-review and mutation evidence; their old package counts are not
current totals. The ticket sections below retain the replacement evidence;
the former work ledger has been removed.

### Current commands and environments

Run from the repository root. Discover destinations with `sweetpad devices`.
The qualified environment is Xcode 27 RC, Swift 6.4, macOS 27.0.1 (26A434),
a 2x macOS hosting display, and iPhone 18 Pro simulator on iOS 27.0
(`674C04A9-8792-4995-A6A9-66F80E5F96AA`). macOS capture pins sRGB;
second-Mac and minimum-OS execution remain unverified.

```sh
swift test
swift test --list-tests
mkdir -p /tmp/flatmark-14
find Tests/References -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-14/before.sha
for platform in macOS iOS; do
  dest=mac
  [ "$platform" = iOS ] && dest=674C04A9-8792-4995-A6A9-66F80E5F96AA
  for n in 1 2; do
    sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --non-interactive --result-bundle /tmp/flatmark-14/$platform-verify$n.xcresult
  done
done
find Tests/References -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-14/after.sha
diff -u /tmp/flatmark-14/before.sha /tmp/flatmark-14/after.sha
git diff --check
```

Use fresh result-bundle paths when repeating these commands. Serialize capture
processes, including package tests, because they share native display resources.
Normal schemes use `FLATMARK_SNAPSHOT_RECORD=never`. To record an intended change,
use the corresponding `-Record` scheme with `--only-testing
FlatMarkSnapshots-<platform>/<suite>`. Recording assertions are expected, not a
passing verification run. Review every changed image at readable scale, reject
unintended output, then run the normal scheme separately twice. Never record to
hide a mismatch. Ticket 14 did not record or change any reference.

Automated results: `swift test` passed **239 tests in 32 suites**, with the one
existing known LoaderSpy issue (before retirement: 245 tests in 33 suites).
`swift test --list-tests` exited 0 and selected-survivor inspection confirmed URL,
accessibility, configuration, cancellation, aspect-fit, linked-width, non-breaking
space, source-byte, payload, and task-editing checks remain registered. The package
run also executed them. Both full snapshot lanes passed **76/76 twice** (all four
commands exit 0). All **206 PNG hashes** stayed identical, including manual assets.
These are automated tests, not new visual baseline review or running-app observations.

Missing-reference probe (automated negative test):

```sh
ref=Tests/References/Snapshots/LinkedImage/macOS/linkedImagePresentationMatchesReviewedBaseline.linked-240col-20inset-320x300-2x-light-en_US-ltr-body.png
mv "$ref" /tmp/flatmark-14/held-reference.png
# Always restore the original, even if the verification command fails.
trap 'mv /tmp/flatmark-14/held-reference.png "$ref"' EXIT
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac --non-interactive --result-bundle /tmp/flatmark-14/mac-missing.xcresult
test ! -e "$ref"
mv /tmp/flatmark-14/held-reference.png "$ref"
trap - EXIT
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac --non-interactive --result-bundle /tmp/flatmark-14/mac-restored.xcresult
```

The missing run exited 3: 75 passed, one failed. It reported the LinkedImage
`linked` case, attached the expected PNG filename, and said: “No reference was
found on disk. New snapshot was not recorded because recording is disabled”.
The file remained absent (`test ! -e` exit 0). After restoration the full lane
passed 76/76, exit 0, and the hash guard passed. **Diagnostic limitation:** neither
the summary nor `sweetpad test output --project Demo/FlatMarkDemo.xcodeproj
--result-bundle /tmp/flatmark-14/mac-missing.xcresult --full` printed the full
expected reference path. The command above identifies that path; automatic
full-path missing-reference diagnostics remain unqualified. Shared assertion
support was outside this ticket's edit scope.

### Coverage mapping (AC-18)

Reference paths below are relative to `Tests/References/Snapshots`; each applies
to both `macOS` and `iOS`. Test stems identify the reviewed PNGs despite their
long environment suffixes.

| Retired proxy | Reviewed replacement ticket / namespace / test stems | Coverage retained outside pixels |
| --- | --- | --- |
| Mixed linked-image arbitrary PNG inequality | 01 — `LinkedImage`: `linkedImagePresentationMatchesReviewedBaseline`, `unlinkedImagePresentationMatchesReviewedBaseline` | Link destinations and rendering-mode tests remain. |
| Ordinary-image native wrapping fitted-size comparisons | 10 — `NativePlaceholderFlow`: narrow/wide × standard/enlarged `Wrapping` | Native inline-text mode and exact-attribute tests remain. No separate public exact fitted-size contract was found. |
| Ordinary-image hard-break fitted-size comparisons | 10 — `NativePlaceholderFlow`: narrow/wide × standard/enlarged `HardBreaks` | Hard-break projection and native inline-text mode remain; both authored-break mutation probes were reviewed in 10. |
| Linked-flow positive size and row-count scaffolding | 02 — `InlineFlow`: narrow, wide, enlarged captures | Drawn left/right width bounds, capture margin, effective-size controls, and non-breaking spaces remain. |
| Image description policy PNG equalities/inequalities | 11 — `PolicyTransitions`: `imageDescriptionRestoresWithoutLoader`, `loadedImageDescriptionDoesNotReload` | Same retained mount still traverses literal→omit→literal with exact request counts and policy wording assertions. Snapshot 11 proves mounted restoration; policy wording alone does not. |
| Configuration lifecycle phase PNG comparisons | 06 — `ImagePhases`: placeholder, loaded raster, failure cases | Original no-loader→first configuration→unrelated update→new configuration→no-loader sequence and exact requests remain. Static phase captures do not replace that lifecycle test. |
| Generic throwing-loader anonymous PNG comparison | 06 — `ImagePhases`: `throwingFailure`, `emptyAltFailure`, `darkFailure`, plus independent controls | Package test retains real held request, release, confirmed throwing completion, and exact URL. Failure-state appearance is established by ticket 06, not by callback completion alone. |
| Empty custom-host wording and literal-export control | 08 — `UnsupportedPolicies`: `emptyLiteral`, `emptyCustom`, `emptyOmit` | Compact mounted exact block-payload dispatch remains, so silent omission cannot pass the package dispatch check. |
| Inline/block custom replacement exported-order and `showsContent` proxies | 08 — `UnsupportedPolicies`: `custom`, `literal`, `omit` | Mounted exact payload set and projected block/component addresses remain, as do extraction-input tests. |
| Custom-policy repeated exported-output matrix and task-row `showsContent` | 11 — `PolicyTransitions`: `retainedPolicyTransitions`, `bothInitializerPaths` | Six directed transitions, source, image request counts, task-update counts, and host payload/label dispatch remain. |
| Omission live-update `showsContent` | 03 — `OmissionSpacing`; 11 — `PolicyTransitions` | Exact native exported wording on the larger omission fixture stays as semantic restoration coverage, along with same-mount source/request/task checks. This is not retained as layout evidence. |
| Custom task-marker exported labels | 07 — `TaskMarkers`: default/custom, read-only/interactive/disabled, retained-initializer and enlarged cases | Compact exact checked/unchecked host-input test through both initializers remains; editing-policy and exact-source tests are untouched. |
| Header-only / empty-table eligibility booleans | 05 — `Tables`: `headerOnly`, `emptyInternalTableBetweenNeighbors`, `visiblePublicTableBetweenNeighbors` | Located in `FlatMarkDocumentViewTests.swift` (`FlatMarkTableViewTests`), not a separate table file. Internal eligibility has no independent predicate contract; table projection tests remain. |

Both private `renderedPNG` overloads and the now-unused unwrapped-width constant
were removed; searching the image-loading file finds no `renderedPNG` callers.
No whole test file was deleted, so project regeneration was unnecessary.
The font-override control remains because the surviving drawn-width test still
uses enlarged effective text. This is not macOS system Dynamic Type verification.
Native observation helpers remain for exact attributes, semantic initializer
parity, and helper contracts. URL policy, loader identity/cancellation, callback
counts, accessibility labels, extraction, projection identity, mention grammar,
links, source mutations, and numeric raster aspect-fit checks were not retired.

### Boundaries and remaining manual work

Snapshots prove reviewed appearance in these environments, not activation,
selection gestures, live VoiceOver, keyboard behavior, contrast/WCAG, minimum-OS
support, or general cancellation. Package tests own their semantic/lifecycle and
numeric contracts; neither lane substitutes for the other. Existing ticket
review evidence is retained below; no new baseline review was needed here.

At ticket 14 qualification, list content could draw outside the offered column,
and RTL task indentation ran outward. Issue #4 addresses these defects; see the
verification-in-progress section above for the remaining approval limits. Recipe
iOS lower-scroll was observed in ticket 13; macOS running-app lower-scroll remains
unperformed. Constrained quote hosts, task hit targets, real selection gestures,
live accessibility, and running-demo interaction still need manual qualification.
Recipe Lab captures are manual artifacts, not this automated baseline suite.

## Automated tests

Run from the package repository root with a toolchain meeting the [requirements](../README.md#requirements):

```sh
swift test
```

Model-level tests cover projection, source-preserving task updates, and unsupported-content policy.
macOS-mounted tests exercise selectable native content, host replacements, tasks, image loading,
and navigation. They do not replace visual, gesture, or live accessibility checks.

### Snapshot baselines

SnapshotTesting 1.19.6 compares exact images. Support stays in
`Tests/FlatMarkTests/Snapshots`; it is not part of the library product.

Use the [SweetPad CLI](https://sweetpad.hyzyla.dev/docs/cli/getting-started/)
from the repository root. Neither `swift test` nor Xcode MCP is needed for these
snapshot commands. Swift Testing remains the test framework.

```sh
# Discover destinations. Replace booted with a simulator name or UDID if needed.
sweetpad devices

# Verify committed references.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS --on booted

# Record deliberately. These commands report assertion failures by design.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS-Record --on mac
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS-Record --on booted
```

The normal schemes explicitly set `FLATMARK_SNAPSHOT_RECORD=never`; the `-Record`
schemes set it to `all`. No shell environment setup is needed. After reviewing
recorded images, run the normal schemes again. SweetPad prints the retained
xcresult path; use `--result-bundle <unique-path>` to keep multiple runs separately.
Use `--non-interactive` for automation. These shared schemes also work in the
SweetPad VS Code Testing panel.

The iOS target uses the existing demo as its test host. The macOS target runs
without an app test host so AppKit snapshot setup owns application initialization.
`Demo/project.yml` owns both targets and all four schemes. After editing it,
regenerate with `cd Demo && xcodegen generate`.
SnapshotTesting reports reference/actual/diff paths on mismatches; runner logs
and xcresult bundles retain failure diagnostics. A missing reference fails the
run and is never recorded in verify mode; the message names the case and the
expected PNG filename, and verify mode states that recording is disabled. The
message does not print the full reference path (see the ticket 14 qualification
limitations). Do not record a mismatch just to make it pass.

References live in `Tests/References/Snapshots/<suite>/<platform>/`.
Each suite owns one namespace in `FlatMarkSnapshotSuite`. `Recipe` owns shared-demo
presentation captures; focused edge-case suites keep their separate namespaces.
See [current coverage](#shared-demo-snapshot-coverage) before adding a custom fixture.
File names include the test, case, column, inset, capture size, scale, appearance,
locale, direction, and text setting. `FlatMarkSnapshotEnvironment.standard` uses
320×300pt, a 240pt column, 20pt inset, 2x, light appearance, `en_US`, LTR, standard
Dynamic Type, and a 13pt macOS / 17pt iOS font. The background is white.
The macOS lane requires a 2x hosting display. Use the same OS/toolchain/display
settings when verifying; changing them requires deliberate baseline review.

Later suites call `flatMarkSnapshotImage(of:environment:)`, then
`assertFlatMarkSnapshot(_:suite:named:environment:)`. Capture mounts native
hosting views and performs three yield/layout passes, with no polling, sleeps,
pixel classification, or fixture-specific drawing checks. UIKit also waits for
screen updates when drawing. This bounded preparation supports synchronous
fixtures, including these no-loader placeholders. Async fixtures must resolve
their state before capture; this helper does not infer readiness from pixels or
loader callbacks. Native capture failure throws. Empty or incomplete content is
caught by image comparison and baseline review, not a second custom validator.
An optional `prepareMountedView` hook runs after mounting and immediately before
native bitmap capture. Table tests use it to position the horizontal viewport;
callers that omit it get no extra await or layout pass.
Serialize mounted snapshot cases (`@Suite(.serialized)`) and do not run multiple
recording processes against the same namespace.

Review every recorded image before a separate verify run. Check text, placeholder,
link treatment, margins, and clipping. Keep only intended PNGs. Confirm verification
leaves reference hashes unchanged. These images do not verify activation, gestures,
or VoiceOver.

Initial qualification: Xcode 27 RC, Swift 6.4, macOS 27.0.1; iPhone 18 Pro simulator
on iOS 27.0. Both linked/unlinked images were recorded and visually inspected on
both platforms: surrounding text is visible, linked placeholders are blue, unlinked
placeholders use the text color, and content has clear margins. Separate verify
runs passed two tests per platform. Deliberately changed text failed comparison;
removing a reference failed without recreating it on both platforms. Minimum-OS
compatibility and forced native capture failure remain unverified.

SweetPad CLI qualification in the same environment: both normal schemes passed
(two tests each). Both `-Record` schemes reached explicit recording assertions and
wrote byte-identical references. Separate normal-scheme reruns passed afterward.

### Recipe integration qualification (ticket 13)

`FlatMarkRecipeIntegrationSnapshotTests` owns nine PNGs per platform under
`References/Snapshots/Recipe/{macOS,iOS}`. Three tests cover primary light,
dark, and enlarged rendering of the unchanged `FlatMarkRecipeSample.markdown`.
The public `FlatMarkView` initializer sets `.literal`, mention detection on,
default task markers, passive tasks, and a handled no-op link action explicitly.
Inspection of `FlatMarkRecipeCapture.apply(to:)` confirmed daylight, midnight,
and generous select `.literal`; only omission selects `.omit`. Preset names and
the older manual-capture guide do not define these tests' settings.

Primary and dark each mount the whole document once at 640×2400pt, with a
560pt column and 40pt inset. Four fixed top-origin crops of that single loaded
capture cover `upperTitleImage`, `tasksQuotes`, `tableCode`, and `lowerNotes`.
Crop (y, height) in points: macOS (0, 600), (600, 470), (1070, 425),
(1495, 425); iOS (0, 650), (650, 540), (1190, 505), (1695, 550).
The suite checks that the entire document fits before cropping. All captures
use 2x, `en_US`, LTR, and the existing environment's platform body text sizes.
Dark uses the environment's black background and dark appearance.

The enlarged representative uses `TextSize.enlarged` (28pt macOS override;
iOS accessibility3 Dynamic Type), a 1120pt column, and a 1200×1100pt viewport.
It mounts the full recipe in a vertical ScrollView with hidden indicators and
asserts the achieved native vertical offset is zero. Its upper crop is 750pt
high on macOS and 900pt on iOS. This uses the sanctioned scroll-framing
alternative: UIKit's shared capture helper returned `.unavailable` for tall
3200pt and enlarged 4500pt windows. The final enlarged capture does not claim
a full-document bitmap or lower enlarged coverage. Primary and dark retain
full-layout section coverage. No shared capture support or fixtures changed.
RTL remains excluded rather than blessing the known-defect area.

The suite-local controlled loader serves the bundled focaccia raster only for
`https://example.com/focaccia.jpeg`. Each capture waits for loader completion,
then five identical mounted-geometry samples within 100 attempts at 20ms.
Each test also mounts an identical leaf.fill-loader control, waits by the same
rule, and asserts its upper section differs from the raster section. Both
loaders receive exactly one request. These assertions passed for all three
configurations on both platforms. Completion alone is not drawing evidence;
contrast plus reviewed photo pixels establish the loaded output.

All eighteen final PNGs were opened with the image reader. Each upper section
shows a recognizable focaccia photo, not a leaf glyph. Primary/dark show nested
checked and unchecked tasks, quote bars, all table rows, fenced hydration code,
and the complete lower notes through `@jane: save a slice`. Dark code backgrounds
remain visible; enlarged upper text and photo are legible. Crop boundaries do
not cut glyphs. Literal HTML is intentional. No settings, counters, activity
strip, clocks, navigation chrome, or source controls enter the references.
These checks do not establish gestures, link activation, or VoiceOver behavior.

Commands used `sweetpad test --project Demo/FlatMarkDemo.xcodeproj`,
`--non-interactive`, and destination `mac` or
`674C04A9-8792-4995-A6A9-66F80E5F96AA` (iPhone 18 Pro, iOS 27.0),
with Xcode 27 RC / Swift 6.4 and macOS 27.0.1:

- `cd Demo && xcodegen generate`: exit 0; generated project includes the suite
  in both snapshot targets. Both targets compiled in the recording lanes.
- `--scheme FlatMarkSnapshots-<platform>-Record --only-testing
  FlatMarkSnapshots-<platform>/FlatMarkRecipeIntegrationSnapshotTests`:
  final recordings exited 3 on each platform with nine expected recording
  assertions, not readiness/capture failures. Earlier framing probes were
  discarded before the final references were recorded.
- Two consecutive full runs of `--scheme FlatMarkSnapshots-<platform>`:
  all four commands exited 0, each with 76 tests and no failures.
- Temporary test-only Markdown mutation `Sunday focaccia` → `Monday focaccia`:
  namespace-only normal lanes exited 3 on both platforms, with genuine image
  mismatches in all three upper references. The shared source stayed untouched;
  the test mutation was restored. Restored namespace lanes exited 0, three
  tests each. No probe used recording.
- `swift test`: initial compilation exposed a missing conditional fixture-module
  import. After adding it, exit 0: 245 tests in 33 suites, one known issue,
  no failures.
- SHA-256 checks against `/tmp/flatmark-13/references-before.txt` and the final
  post-record Recipe list passed. Every pre-existing reference is byte-identical,
  and verification/probes did not change the new references. `git diff --check`
  passed. Logs are under `/tmp/flatmark-13/`.

Running-app check: launched the iOS demo with `--capture daylight` using
MobileBuildMCP, performed six upward swipes in the recipe scroll view, and opened
the resulting screenshot. Lower notes, nested quote/task content, ordered notes,
contact text, and final code block were visible. The live capture includes host
chrome and is not a baseline. macOS demo launch succeeded, but lower scrolling
and screenshot inspection were **NOT PERFORMED** on macOS. Minimum-OS,
minimum-toolchain, live accessibility, and lower enlarged rendering remain
unverified.

### Typography qualification (ticket 12)

`FlatMarkTypographySnapshotTests` owns six references per platform under
`References/Snapshots/Typography/{macOS,iOS}`: light/dark samplers, identical
mention Markdown with detection enabled/disabled, narrow wrapping, and enlarged
wrapping. Existing exact mention and attributed-string tests are unchanged.

All twelve PNGs were opened individually with the image reader. Headings 1–3
have distinct sizes; 4–6 share headline styling. Bold, italic, strikethrough,
monospaced inline code, fenced code, divider, and hard/soft breaks are visible.
Enabled mentions gain bold styling, including split emphasis and whole-token
emphasis/strike. Email, code, and link-label exclusions remain visually distinct
and unchanged between detection settings. Narrow and enlarged text wraps without
edge clipping. iOS enlarged fenced code wraps and hyphenates the long identifier.

Inline code renders monospaced via `inlinePresentationIntent = .code` with no
background. This is the reviewed renderer contract, not a defect. Fenced code
shows a secondary background; dark shows that background and secondary styling.
The divider and dark fenced background are faint but visible. This review makes
no WCAG or contrast-conformance claim. A distinct inline-code background would
need a separate bounded production change, outside this ticket.

Qualification used the existing Xcode 27.0 / macOS 27.0.1 capture environment and
iPhone 18 Pro iOS 27.0 simulator. This round ran `cd Demo && xcodegen generate`
(exit 0), then the namespace-only `FlatMarkSnapshots-macOS-Record` and
`FlatMarkSnapshots-iOS-Record` schemes with
`--only-testing FlatMarkSnapshots-<platform>/FlatMarkTypographySnapshotTests`.
Both recordings exited 3 with six expected recording assertions, not capture
failures. Two consecutive full non-recording runs of each corresponding scheme
all exited 0. The destination was `mac` or simulator
`674C04A9-8792-4995-A6A9-66F80E5F96AA`; all runs used `--non-interactive`.
Logs and result bundles are under `/tmp/flatmark-12/` (`mac-record`, `ios-record`,
`mac-verify1`, `mac-verify2`, `ios-verify1`, `ios-verify2`).

Three temporary fixture mutations ran the selected macOS suite in verify mode.
Changing heading one from level 1 to 2 and removing the sampler inline-code span
each caused genuine comparison mismatches in `lightSampler` and `darkSampler`.
Disabling detection in `mentionsEnabled` mismatched only that reference.
Each probe exited 3; all mutations were restored without recording.
`swift test` then exited 0: 242 tests in 32 suites, one known issue, no failures.
SHA-256 comparison against `references-before.txt` confirmed every reference
outside Typography stayed unchanged. All references also matched the post-record
hash list after verification and mutation probes. `git diff --check` passed.
No production or shared capture/environment code changed.

### Live policy-transition qualification (ticket 11)

`FlatMarkPolicyTransitionSnapshotTests` owns sixteen PNGs per platform under
`References/Snapshots/PolicyTransitions/{macOS,iOS}`. Five Swift Testing tests
include two argument cases for the initializer check. The shared capture support
now offers a test-only retained host. Mounting and native capture code were moved
into private helpers without changing the three passes, mounted callback, native
capture errors, macOS flatten/sRGB conversion, or UIKit renderer. The ordinary
`flatMarkSnapshotImage` still mounts and closes once per call. Comparison is unchanged.

Qualified with Xcode 27.0 (27A266a), Swift 6.4, macOS 27.0.1 (26A434) on the
2x hosting display, and the iPhone 18 Pro simulator on iOS 27.0. The suite uses
640×650pt captures, a 400pt column, 80pt insets, 2x, light, en_US, LTR, and
13pt macOS / 17pt iOS body overrides. These are selected variants, not a matrix.

#### States and visual review

Every one of the 32 final PNGs was opened individually with the image reader.
All text, checkboxes, and raster edges are complete with clear outside margins.
Omitted HTML blocks leave no stale block slot. Inline replacement labels adjoin
the supported middle text, matching replacement of adjacent tags, not inserted spaces.
The changed label wraps on iOS without clipping. Literal restoration compares to
the initial literal reference in verify mode even during an explicit recording run.

Each row names PNG stems on **both** platforms. Every filename ends with
`-400col-80inset-640x650-2x-light-en_US-ltr-body.png`.

| PNG stems | Reviewed result |
| --- | --- |
| `retainedPolicyTransitions.heldLoading` | Literal tags/block, unchanged task, clock plus description, no raster. |
| `retainedPolicyTransitions.literal` | Same content with the complete four-color local raster. |
| `retainedPolicyTransitions.custom` | Three indigo Replacement labels; task and raster survive. |
| `retainedPolicyTransitions.changedCustom` | Three Changed replacement labels on the same mount; task and raster survive. |
| `retainedPolicyTransitions.omit` | Tags/block disappear; supported middle text, task, raster, and after paragraph remain. |
| `imageDescriptionRestoresWithoutLoader.literal`, `.omit` | Photo placeholder wording changes from literal `<u>local</u>` to `local`, then restores. |
| `loadedImageDescriptionDoesNotReload.loaded` | Inline raster remains between Before and after; no alt wording leaks. |
| `freshMountsStartNewRequests.mount1`, `.mount2` | Complete matching rasters from two independent mounts. |
| `bothInitializerPaths.sourceLiteral`, `.sourceCustom`, `.sourceOmit` | Source initializer: literal tags/block, replacements, then omitted content; task intact. |
| `bothInitializerPaths.documentLiteral`, `.documentCustom`, `.documentOmit` | Retained-document initializer: same focused transitions and task. |

The first recording was rejected because the description fixture contained no
unsupported tags and therefore could not demonstrate a wording change. The fixture
now includes `<u>local</u>`. Initial captures remain outside the repository under
`/tmp/flatmark-11/initial-unaccepted/`; only corrected references are accepted.

#### Readiness and lifecycle evidence

The controlled loader has no cache. It counts requests under a lock, waits for
explicit release, then delays one second before returning a local 120×60 raster.
Its completion defer runs without suspension. Readiness requires the intended
request count and completion, then five identical native-frame observations,
20ms apart, within 100 attempts. Request-only readiness is used intentionally for
the held-loading reference. Geometry bounds settling; it does not identify phases.
Readiness errors throw before comparison or recording. Tests close retained hosts
in defer; unmounting cancels view tasks, and held delivery is released on teardown.

On both platforms, the complete unrelated-policy transition sequence kept the
request count at **1** while the reviewed raster stayed drawn. Loaded-description
literal → omit → literal also kept exactly **1** request and matched the same loaded
reference after each change. Unchanged-source assertions accompany both cases.
Two calls to `flatMarkSnapshotImage` with the same model and loader produced counts
**1, then 2**. Thus retention, not loader caching, prevents the extra request.

With the one-second completion delay and full readiness, all five tests passed on
each platform (`*-delay-gated`). A verify-only probe changed only the initial loaded
capture to request-start readiness, keeping geometry checks and the same delay.
Each platform then reported exactly one genuine mismatch, `retainedPolicyTransitions.literal`,
with the other four tests passing (`*-delay-start-only`). The initial loaded frame
was premature; completion readiness is necessary. The probe was restored.
A separate verify-only label mutation changed Replacement to MUTATION replacement.
Exactly `retainedPolicyTransitions.custom` mismatched on each platform; the other
four tests passed. No probe recorded references.

#### Commands and results

Commands ran from the repository root, one capture process at a time. Logs,
xcresults, hash manifests, and review sheets remain under `/tmp/flatmark-11/`.

```sh
find Tests/References -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-11/references-before.txt
(cd Demo && xcodegen generate)
# platform=macOS: dest=mac
# platform=iOS: dest=674C04A9-8792-4995-A6A9-66F80E5F96AA
# Initial verify compiled both targets and failed only on missing references.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkPolicyTransitionSnapshotTests --non-interactive --result-bundle /tmp/flatmark-11/$platform-initial.xcresult
# Explicit namespace-only recordings: exit 3, expected recording assertions.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform-Record --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkPolicyTransitionSnapshotTests --non-interactive --result-bundle /tmp/flatmark-11/$platform-final-record.xcresult
# After review: two full runs per platform; then gated, weak-readiness and label
# probes with the suite filter above. All probe edits were restored before final1.
for phase in final1 final2; do
  sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --non-interactive --result-bundle /tmp/flatmark-11/$platform-$phase.xcresult
done
swift test
find Tests/References -name '*.png' ! -path '*/PolicyTransitions/*' | sort | xargs shasum -a 256 > /tmp/flatmark-11/existing-after.txt
diff -u /tmp/flatmark-11/references-before.txt /tmp/flatmark-11/existing-after.txt
shasum -a 256 -c /tmp/flatmark-11/accepted.txt
git diff --check
```

Both consecutive final full lanes exited 0: **67 tests passed per platform per run**.
Earlier full verify1/verify2 runs also passed 67 each. `swift test` exited 0 with
**236 tests in 31 suites**, one existing intentional LoaderSpy known issue, no
unexpected failures. All **144 existing PNGs** remain byte-identical; all **32 new
PNGs** remain byte-identical through verification and probes. Hash comparison and
`git diff --check` exited 0. The first macOS compile attempt failed on an unconditional
fixture-module import; the corrected conditional import supports both target layouts.

This qualifies mounted appearance, live policy updates, and the stated loader
counts only. It does not verify gestures, task activation/source acceptance,
VoiceOver, minimum OS versions, dark/RTL/enlarged transitions, general cancellation
behavior, or running-demo interaction. Existing semantic and interaction tests remain.

### macOS sRGB reference migration and early review

The owner authorized re-recording after the cross-display investigation below.
The macOS recording scheme executed all **82 tests** and wrote **109 references**.
Its recording assertions failed as expected; this was not a verification pass.
Two consecutive runs of `FlatMarkSnapshots-macOS` then passed **82/82**, without
recording or temporary placement/export code. Reference SHA-256 manifests were
identical before and after both verification runs.

All 109 macOS PNG files changed. iOS and manual captures stayed byte-identical.
Exact comparison remains unchanged. The environment was macOS 27.0.1 (26A434),
Swift 6.4, and the current two-display setup. Before migration, all 109 captures
were byte-identical across the LG and built-in displays with pre-draw sRGB.
The post-record verification runs did not explicitly place hosts on each display.

Early visual review covered contact sheets for all 13 suites. It checked visible
wording, wrapping, task markers, custom replacements, image states, table endpoints,
and light/dark backgrounds. Full-resolution content crops additionally covered:

- narrow RTL list continuations, including the complete `Final child bullet.`;
- enlarged default task markers and complete wrapped labels in LTR and RTL;
- the primary recipe header, styled mentions, and loaded image.

No obvious new rendering defect was found in this pass. Table leading/trailing
captures intentionally show different scroll endpoints. Cropped and scaled contact
sheets do not establish original outer margins or pixel-level correctness. This
is early static review, not a full before/after visual audit, running-demo testing,
VoiceOver, or selection/interaction qualification.

Local evidence is under `/tmp/flatmark-capture-rerecord/`: `record.log`,
`verify1.log`, `verify2.log`, before/recorded/verified SHA-256 manifests, the saved
old references, and `sheets/`. Temporary artifacts may disappear. No iOS lane was
rerun for this macOS-only reference migration.

### macOS pre-draw color-space investigation

The macOS helper now sets `NSWindow.colorSpace` to `.sRGB` before attaching the
hosting view. It still converts the flattened bitmap to sRGB afterward. Setting
only the output profile did not prevent display-dependent pixels during drawing.
Comparison remains exact; references and recording policy are unchanged.

The owner confirmed that references were recorded on both the LG ULTRAFINE and
built-in MacBook display. Controlled runs used macOS 27.0.1 (26A434), Swift 6.4
(swiftlang-6.4.0.34.1), Dark system appearance, and both displays online at 2x.
Temporary test-only code placed each unordered hosting window 40 points inside
one display and exported every capture outside the repository. Diagnostics
confirmed the selected screen, backing scale, and window color space. No global
settings changed. Wake/lock state was not independently established.

- With display-default window color spaces, LinkedImage output differed between
  displays. Neither display exactly reproduced its linked-image reference.
- With pre-draw sRGB, the full macOS lane ran on each display: **82 tests executed
  per run, all failing against the existing references**.
- All **109 exported captures were byte-identical between displays**. This
  establishes cross-display consistency for these runs, not compatibility with
  the old references or other OS/toolchain/display environments.
- Temporary placement, logging, and export code was removed. A final run without
  that instrumentation executed **82 tests, all failing** against the references.
  Only the pre-draw sRGB setting remains in the helper. No iOS capture code changed.
- Reference SHA-256 manifests stayed unchanged, and `git diff --check` passed.

Local evidence is under `/tmp/flatmark-capture-investigation/`: `full-lg-complete.log`,
`full-builtin-complete.log`, `full-final.log`, the corresponding capture directories, and
`full-cross-display.txt`. These files may disappear when temporary storage clears.
Visual review has covered only the linked-image example, not all changed outputs.
At this stage, the macOS lane was **not qualified**. The subsequent authorized
[reference migration](#macos-srgb-reference-migration-and-early-review) records
verification under the new capture contract. Comparison precision was not loosened.

### macOS color-space qualification (ticket 10b)

The macOS capture helper converts the flattened native bitmap to named
`NSColorSpace.sRGB` (embedded profile `sRGB IEC61966-2.1`) before returning an
`NSImage` with an explicit bitmap representation. sRGB is standard and independent
of a particular monitor. The old references embedded the disconnected display's
`LG ULTRAFINE` profile; captures on the replacement display embedded `Display P3`.
The conversion changes encoding, not comparison: exact SnapshotTesting comparison
and `assertFlatMarkSnapshot` are unchanged. No tolerance was added.

Only the macOS branch changed. The three layout passes, mounted-view hook, native
capture failure, background flattening, and point size remain intact. Conversion
failure also throws `FlatMarkSnapshotCaptureError.unavailable`.

Qualified on Xcode 27 / Swift 6.4, macOS 27.0.1 with a 2x hosting display. Logs,
reference hashes, review contact sheets, and result bundles are retained locally
under `/tmp/flatmark-10b/`, not in the repository.

```sh
# Authorized full macOS re-record. Exit 3: 62 expected recording assertions,
# producing all 72 references across the ten suites.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS-Record --on mac --non-interactive --result-bundle /tmp/flatmark-10b/mac-record.xcresult

# Consecutive non-recording runs. Each exited 0: 62 tests passed.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac --non-interactive --result-bundle /tmp/flatmark-10b/mac-verify1.xcresult
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac --non-interactive --result-bundle /tmp/flatmark-10b/mac-verify2.xcresult

# Profile inspection: 72 entries, all sRGB IEC61966-2.1.
for f in $(find Tests/References/Snapshots -path '*/macOS/*' -name '*.png'); do sips -g profile "$f"; done | grep 'profile:' | sort | uniq -c

# iOS guard: exit 0, no differences across all 72 iOS PNGs.
find Tests/References/Snapshots -path '*/iOS/*' -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-10b/ios-after.txt
diff /tmp/flatmark-10b/ios-baseline.txt /tmp/flatmark-10b/ios-after.txt

# Mutation probe: exit 3, two genuine snapshot mismatches with reference/actual
# paths and xcresult comparison attachments. No reference was recorded.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac --only-testing FlatMarkSnapshots-macOS/FlatMarkLinkedImageSnapshotTests --non-interactive --result-bundle /tmp/flatmark-10b/mac-mutation.xcresult

# After restoring the mutation and reviewing the images: exit 0, 62 passed.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac --non-interactive --result-bundle /tmp/flatmark-10b/mac-final.xcresult

# Exit 0: 231 tests in 30 suites, one known issue, no snapshot failures.
swift test

# Build only; both exited 0. The iOS destination is this run's simulator.
sweetpad build --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkDemo-macOS --on mac --non-interactive
sweetpad build --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkDemo-iOS --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --non-interactive

git diff --check
```

The mutation temporarily wrapped the mounted macOS fixture in
`view.overlay(Text("MUTATION PROBE"))` in the capture helper. It was restored before
package tests, builds, and the final normal-scheme run. SHA-256 hashes of all 72
macOS references stayed unchanged through verification and mutation.

Visual review covered all 72 re-recorded images in per-suite contact sheets:
EmptyStructures, ImagePhases, InlineFlow, LinkedImage, NativePlaceholderFlow,
NestedContainers, OmissionSpacing, Tables, TaskMarkers, and UnsupportedPolicies.
Checked text and placeholders, blue links, purple custom replacements and task
markers, colored rasters, table rules and both scroll positions, outside margins,
and clipping. No new missing content or layout changes were found. A supplementary
foreground-mask comparison against the committed images found identical masks in
71 images; `customDisabled` differed by eight threshold-edge pixels after color
conversion. This inspection aid is not part of snapshot comparison.

The known NestedContainers list overflow outside the offered column remains;
this re-record does not fix or approve it as correct behavior. TaskMarkers still
has no RTL reference on either platform. No iOS recording ran. Cross-display
execution, minimum-OS behavior, forced native/conversion failure, live gestures,
and accessibility were not verified by this qualification.

### Inline-flow qualification (ticket 02)

`FlatMarkInlineFlowSnapshotTests` owns ten references: narrow, wide, enlarged, RTL,
and consecutive-break captures on each platform. All use public `FlatMarkView` and
local fixture Markdown. Absolute image/link URLs resolve a linked placeholder;
no image loader or external navigation is used.

Qualified with Xcode 27.0 (27A266a), Swift 6.4, macOS 27.0.1 on a 2x display,
and the iPhone 18 Pro simulator on iOS 27.0. iOS enlarged text uses
`.accessibility3`; macOS uses a 28pt effective font override, not system Dynamic Type.

Commands below ran from the repository root through SweetPad. Results and logs
were retained locally under `/tmp/flatmark-ticket02/` (not repository artifacts).

```sh
# Explicit recording: each run selected five tests and reported five expected
# recording assertions, with no native capture failures.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS-Record --on mac --only-testing FlatMarkSnapshots-macOS/FlatMarkInlineFlowSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket02/mac-record.xcresult
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS-Record --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --only-testing FlatMarkSnapshots-iOS/FlatMarkInlineFlowSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket02/ios-record.xcresult

# Separate non-recording runs: seven passed per platform (five inline-flow,
# two existing linked-image tests).
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac --non-interactive --result-bundle /tmp/flatmark-ticket02/mac-verify.xcresult
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --non-interactive --result-bundle /tmp/flatmark-ticket02/ios-verify.xcresult
```

Discover your own simulator with `sweetpad devices`; the identifier above records
the actual run, not a required destination.

Visual review covered all ten references. Narrow and wide captures wrap differently;
the indigo 44×30pt replacement changes row baselines; supported bold/link text and
separated hard breaks remain visible. Enlarged and RTL captures retain their content
and clear outside margins. No visible overflow or clipping was found.

**Known renderer defect retained at the user's request:** consecutive hard breaks in
mixed flow do not preserve a blank row. The dedicated fixture contains both the
linked image and custom replacement, so it enters `FlatMarkInlineFlowLayout`.
`consecutiveBreaksRetainCurrentRendering` records that current output, not a claim
that its break semantics are correct. A later renderer fix must deliberately update
these two references. The older text-only images under
`AI-docs/prds/ui-snapshot-testing/evidence/` do not establish mixed-flow behavior.

Mutation check: temporarily replaced `beforeText` with
`MUTATION CHECK changes wrapping before the diagram inside the narrow reading column`.
Ran each normal scheme with the same suite-only filter used above and result bundles
`mac-mutation.xcresult` / `ios-mutation.xcresult`. Each run reported four genuine
snapshot mismatches and one passing consecutive-break case. Restored the fixture,
then reran both full normal schemes with result bundles `mac-final.xcresult` /
`ios-final.xcresult`: seven passed per platform. SHA-256 hashes of all ten inline-flow
references were identical before verification and after the mutation/restoration runs.
Existing numeric drawn-width and non-breaking-space tests were not changed or retired;
those rendering tests were not rerun in this focused snapshot check.

These are mounted-rendering snapshot checks, not running-demo interaction,
VoiceOver, selection-gesture, or minimum-OS qualification.

### Omission-spacing qualification (ticket 03)

`FlatMarkOmissionSpacingSnapshotTests` owns twelve PNGs in `OmissionSpacing`:
three cases, each with an omitted document and a hand-authored supported-only
control, on both platforms. All use public `FlatMarkView` with `.omit` and local
Markdown. Exact comparison uses the shared support without tolerances.

Qualified with Xcode 27.0 (27A266a), Swift 6.4, macOS 27.0.1 on a 2x display,
and iPhone 18 Pro on iOS 27.0. Enlarged text uses real `.accessibility3` on iOS
and a 28pt font override on macOS, not macOS system Dynamic Type.

These exact commands ran from the repository root. Each loop ran serially.
Logs and xcresults remain local under `/tmp/flatmark-ticket03/`.

```sh
(cd Demo && xcodegen generate)

# Initial recordings: three tests / six expected recording assertions per platform.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS-Record --on mac --only-testing FlatMarkSnapshots-macOS/FlatMarkOmissionSpacingSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket03/mac-record.xcresult
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS-Record --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --only-testing FlatMarkSnapshots-iOS/FlatMarkOmissionSpacingSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket03/ios-record.xcresult

# Reviewed fixture correction, then separate verification, probe, and restoration.
# Run this loop once per phase, with the fixture state described below.
for phase in intrinsic-record verify mutation final; do
  for platform in macOS iOS; do
    if [ "$platform" = macOS ]; then
      dest=mac
    else
      dest=674C04A9-8792-4995-A6A9-66F80E5F96AA
    fi
    scheme=FlatMarkSnapshots-$platform
    if [ "$phase" = intrinsic-record ]; then scheme=$scheme-Record; fi
    sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme "$scheme" --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkOmissionSpacingSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket03/$platform-$phase.xcresult
  done
  # Pause between phases for visual review, hash capture, or fixture edits.
done

# Before verify, and again after final (substitute after.sha256):
find Tests/References/Snapshots/OmissionSpacing -name '*.png' -exec shasum -a 256 {} \; | sort > /tmp/flatmark-ticket03/before.sha256
diff -u /tmp/flatmark-ticket03/before.sha256 /tmp/flatmark-ticket03/after.sha256
swift test
git status --short
git diff --check
```

The initial flexible quote filled the offered height and clipped the iOS after
paragraph. Those captures were rejected and retained locally in
`initial-unaccepted/`. The fixture now requests intrinsic vertical size with
`.fixedSize(horizontal: false, vertical: true)`; the capture remains fixed at
320×300pt or 320×1100pt, never fitted to the result. This does not qualify the
renderer under a vertically constrained host.

The implementation worker visually reviewed every final PNG with the image reader:

| PNG stem (both omitted and control, on each platform) | Review and verdict |
| --- | --- |
| `emptiedBlocksLeaveNoSlotsOrRules` | Both paragraphs intact; ordinary neighbor gap; no HTML-only paragraph/heading slot or single/nested quote rule; clear margins. Accepted all four PNGs. |
| `supportedListKeepsItsQuote` | Bullet and supported wording remain inside one visible quote rule; no removed child slot or nested rule; after paragraph fully visible. Accepted all four PNGs. |
| `enlargedNarrowNeighborsKeepTheirSpacing` | Both neighbors wrap with complete wording; ordinary paragraph spacing; no removed slots/rules; ample bottom/right margins and no clipping. Accepted all four PNGs. |

Each omitted/control pair has the same intended appearance. The final recordings
reported six expected recording assertions per platform with no native capture
failures. Separate `verify` runs passed three tests per platform.

For `mutation`, the first HTML-only paragraph and single quote changed from
`<u></u>` to `<u> </u>`. The supported spaces retain a blank block slot and an
otherwise empty quote rule. Both normal schemes reported two genuine image
mismatches (standard and enlarged omitted captures) and one passing retained-list
case; controls did not mismatch. The macOS actual image was also inspected: the
extra gap and orphan rule were visible. Restored both strings before `final`:
three tests passed per platform. All twelve reference SHA-256 hashes stayed
unchanged across verify, mutation, and restoration.

`swift test` passed 179 tests in 23 suites with zero unexpected failures and one
intentional known issue in LoaderSpyTests (`reports an expectation dropped by a
later arm`). Existing rendering/identity/whitespace/source-update tests remain
unchanged. `git diff --check` passed. The unrelated untracked work ledger remains.

These snapshots qualify the listed omission fixtures only. They do not establish
live policy transitions, VoiceOver, gestures, selection, constrained-host quote
sizing, minimum-OS support, or running-demo behavior. Discover a local simulator
with `sweetpad devices`; the identifier above records this run only.

### Nested-container qualification (ticket 04)

`FlatMarkNestedContainerSnapshotTests` owns ten PNGs in `NestedContainers`:
narrow/wide nested quotes, narrow/wide mixed lists, and an enlarged list on each
platform. Public `FlatMarkView` renders local Markdown and a synchronous indigo
44×30pt inline replacement. No loader or navigation is involved.

Qualified with Xcode 27.0 / Swift 6.4, macOS 27.0.1 on a 2x display, and iPhone
18 Pro on iOS 27.0. Enlarged text uses `.accessibility3` on iOS and a 28pt font
override on macOS, not macOS system Dynamic Type. All captures have a fixed size
larger than their content. Intrinsic vertical sizing keeps flexible quote rules
from consuming the offered capture height; constrained-host sizing is excluded.

Exact commands ran from the repository root, serially. Logs, rejected initial
captures, hashes, and xcresults remain local under `/tmp/flatmark-ticket04/`.

```sh
(cd Demo && xcodegen generate)

# Initial recording used the smaller-margin fixture and an RTL list variant.
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS-Record --on mac --only-testing FlatMarkSnapshots-macOS/FlatMarkNestedContainerSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket04/mac-record.xcresult
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS-Record --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --only-testing FlatMarkSnapshots-iOS/FlatMarkNestedContainerSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket04/ios-record.xcresult

# Run each phase separately; pause for review, hashing, or mutation between phases.
for phase in margin-record verify mutation final; do
  for platform in macOS iOS; do
    dest=mac
    [ "$platform" = iOS ] && dest=674C04A9-8792-4995-A6A9-66F80E5F96AA
    scheme=FlatMarkSnapshots-$platform
    [ "$phase" = margin-record ] && scheme=$scheme-Record
    sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme "$scheme" --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkNestedContainerSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket04/$platform-$phase.xcresult
  done
done

# Before verify, then again after final (substitute after.sha256):
find Tests/References/Snapshots/NestedContainers -name '*.png' -exec shasum -a 256 {} \; | sort > /tmp/flatmark-ticket04/before.sha256
diff -u /tmp/flatmark-ticket04/before.sha256 /tmp/flatmark-ticket04/after.sha256
swift test
git status --short
git diff --check
```

Initial macOS review rejected a narrow list background reaching the capture edge
and an RTL capture losing text at the left edge. Those images are not accepted
references. The final fixture provides 100pt insets and wider capture bounds,
and selects the permitted enlarged variant instead of RTL. The bounded RTL
investigation below demonstrates list overflow; it is not an accepted baseline.
Constrained-host overflow remains unqualified. Rejected initial images remain in
`initial-unaccepted/` outside the repository. The final references preserve
FlatMark's flattened list layout.

The implementation worker opened every final PNG with the image reader:

| PNG test stem | macOS review | iOS review |
| --- | --- | --- |
| `narrowNestedQuote` | All numbered lines, inner/outer endings, replacement and after paragraph visible; rules end with content; clear margins. Accepted. | Same checks; more wrapping, no lost lines or clipping. Accepted. |
| `wideNestedQuote` | Wider wrapping; all quote wording and both rules complete; clear margins. Accepted. | Wider wrapping; complete numbered lines and endings; rules not stretched; clear margins. Accepted. |
| `narrowListContinuations` | Three nesting levels visible; paragraph, quote and code follow final child and align with parent content; next parent and after text intact; clear margins. Accepted. | Same order/alignment; all wrapped wording and code visible; clear margins. Accepted. |
| `wideListContinuations` | Less wrapping; continuation origins align with parent content; quote rule and code complete; clear margins. Accepted. | Same order/alignment; both code lines and after paragraph visible; clear margins. Accepted. |
| `enlargedListContinuations` | Larger text wraps; nested indentation visible; continuations align with parent, not child; rule ends with quote; clear margins. Accepted. | Real enlarged Dynamic Type; deeper rows and wrapped code intact; continuation order/alignment retained; clear margins. Accepted. |

Both final recording runs selected five tests and reported five expected recording
assertions, with no native capture failures. Separate `verify` runs passed five
tests per platform. Mutation removed `Line four must remain visible too.` and its
hard break from the quote. Both normal schemes reported two genuine image
mismatches and three passing list tests. Restored the line before `final`; five
tests passed per platform. All ten reference SHA-256 hashes stayed unchanged
through verification, mutation, and restoration.

#### Bounded RTL investigation and list mutation probes

The generous-bounds captures demonstrate **renderer list overflow**, not merely
capture placement. A red 1pt border marks the offered 240pt document frame.
Both RTL captures show the paragraph and quote text, and the code-block
background, outside its left edge. All wording reappears intact with 400pt outside padding and no ink
touches an image edge. Enlarging the capture recovers ink; it does not make that
ink fit the offered column. The before/after paragraphs stay inside the border.
The LTR controls also overflow, to the right, but lose no wording with these
bounds. Thus a clean inline-flow capture does not establish list correctness.
This establishes an out-of-column drawing defect, not its precise internal
alignment-guide cause. No hosting-view intrinsic-width measurement was taken.

Durable evidence, visually inspected on both platforms, is in
`AI-docs/prds/ui-snapshot-testing/evidence/`:

- `defect-rtl-list-rtl-macOS.png` and `defect-rtl-list-rtl-iOS.png`:
  complete RTL mixed list with visible left overflow.
- `defect-rtl-list-ltr-macOS.png` and `defect-rtl-list-ltr-iOS.png`:
  identical LTR controls with visible right overflow.

Blocked criterion: RTL list content and continuations must fit the offered
reading column without clipping. A **separate bounded production fix is
required**. No production code changed, no RTL baseline was added, and none of
these diagnostic images is an accepted reference. Nesting-depth scaling and
isolated continuation-type causes remain unmeasured.

Exact diagnostic Markdown (three spaces for parent continuations, five before
the grandchild marker):

````markdown
Before the mixed list.

1. Parent opening wraps with enough wording to expose the content alignment.
   - Child bullet wraps across the narrow reading column.
     1. Grandchild numbered row.
   - Final child bullet.

   Parent continuation follows all child rows and wraps onto another line.

   > Parent quote follows the continuation paragraph and keeps its own rule.

   ```swift
   let ready = true
   render(ready)
   ```

2. Next parent row ends the list.

After the mixed list.
````

A temporary `rtlInvestigation()` test captured this exact source in both
`.leftToRight` and `.rightToLeft`. It used `FlatMarkView(markdown: Self.list)`
with `.fixedSize(horizontal: false, vertical: true)`, then
`.frame(width: 240, alignment: .leading).border(.red, width: 1)`.
It called `flatMarkSnapshotImage` directly, not snapshot recording/comparison,
and exported PNG data. Shared capture support was unchanged. Environment:
1240×2100pt capture, 240pt column, 400pt inset, requested pixel scale 2,
light, `en_US`, body (`.large`, 13pt macOS / 17pt iOS font override).
The native macOS diagnostic export is 1240×2100 pixels (1x); the iOS export
is 2480×4200 pixels (2x). These diagnostics establish geometry, not new
scale-qualified baselines. The temporary test was removed after export.

Two separate VERIFY-only list probes then ran:

| Phase | Temporary change | Observed result on each platform |
| --- | --- | --- |
| `list-order` | Move the parent paragraph continuation before `- Final child bullet.`, with blank lines around the paragraph. | `narrowListContinuations`, `wideListContinuations`, and `enlargedListContinuations` mismatched; both quote tests passed. |
| `list-indent` | Restore order, then add two spaces to the parent paragraph continuation (three to five Markdown spaces), nesting it under the final child. | The same three list references mismatched; both quote tests passed. |
| `corrections-final` | Restore the original fixture byte-for-byte. | Five tests passed on each platform. |

Exact commands for the correction runs (each phase ran separately, one capture
process at a time; no Record scheme was used):

```sh
shasum -a 256 Tests/References/Snapshots/NestedContainers/*/*.png > /tmp/flatmark-ticket04/corrections-before.sha256
for phase in rtl-investigation list-order list-indent corrections-final; do
  for platform in macOS iOS; do
    dest=mac
    [ "$platform" = iOS ] && dest=674C04A9-8792-4995-A6A9-66F80E5F96AA
    sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkNestedContainerSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket04/$platform-$phase.xcresult
  done
 done
shasum -a 256 Tests/References/Snapshots/NestedContainers/*/*.png > /tmp/flatmark-ticket04/corrections-after.sha256
diff -u /tmp/flatmark-ticket04/corrections-before.sha256 /tmp/flatmark-ticket04/corrections-after.sha256
```

`rtl-investigation` passed six tests per platform (the five accepted tests plus
the temporary diagnostic). Each mutation reported two passes and three genuine
image mismatches. Restoration passed five per platform. SHA-256 comparison
returned no differences: all ten accepted PNGs remained byte-identical. The
fixture file also matched its pre-investigation copy after restoration.

Historical source was **not recovered with enough evidence to identify the exact
failing fixture**. Searches covered `git log --all` (quote/truncation messages and
wording changes), `Tests/README.md`, Recipe Lab guide history and fixture history,
`AI-docs/prds/ui-snapshot-testing/evidence/`, and `Tests/References/RecipeLab/`.
History mentions truncation of “kneading” and later rewritten wording, but does
not tie an exact original source and host configuration to the failure. The
current evidence directory contains consecutive-break images, not that quote.
These tests use a new long multiline regression fixture. They do not establish
that the historical macOS defect is fixed.

`swift test` passed 184 tests in 24 suites with one intentional known issue in
LoaderSpyTests and no unexpected failures. Existing projector and rendering tests
remain unchanged. `git diff --check` passed; the unrelated untracked work ledger
remains. These mounted snapshots do not qualify running-demo interaction (not
exercised), live VoiceOver, gestures, selection, minimum OS versions, RTL lists,
or vertically constrained quote hosts.

### Table qualification (ticket 05)

`FlatMarkTableSnapshotTests` owns fourteen references in `Tables`: wide long cells,
narrow leading/trailing viewports, enlarged long cells, a public header-only GFM
table, an empty internal table between paragraphs, and a visible public table
between the same paragraphs, on each platform. The empty fixture inserts a
`FlatMarkRenderTable(header: [], rows: [])` into a projected document. It is an
internal fixture, not a claim that public Markdown parses into an empty table.
Existing eligibility, parser span, blank-cell, and uneven-cell tests remain unchanged.

Qualified with Swift 6.4, Xcode 27.0, macOS 27.0.1 on the 2x display, and iPhone
18 Pro on iOS 27.0. iOS enlarged text uses `.accessibility3`; macOS uses a 28pt
font override, not system Dynamic Type. Fixed captures provide 100pt outside
insets and intrinsic vertical document sizing. The initial 1400pt enlarged iOS
capture was too short and was rejected. The final enlarged capture is 1900pt
high on both platforms; every final cell bottom and the bottom rule are visible.
No production defect was established or accepted as a reference.

The suite-local native scroll-view lookup selects the horizontal overflowing
scroll view. Leading is exactly 0pt. Trailing is exactly 400pt on each platform:
four fixed 160pt columns give 640pt of content, minus the 240pt viewport.
The hook computes the target offset from mounted document/content width minus
viewport width, sets it without animation, lays out/displays, then yields once.
After that final yield it reads the achieved native offset back
(`contentView.bounds.origin.x` on macOS, `contentOffset.x` on iOS) and requires an
exact match with 0/400pt, together with the 640pt content and 240pt viewport
geometry. A missing scroll view or a mismatch fails and reports the case, the
intended and achieved offset, and both widths. That read-back proves the native
position at the sampled instant, not completed drawing; pixel review establishes
which content drew. The default capture path has no added awaits or layout passes.

Commands ran serially from the repository root. Logs, rejected initial output,
hashes, and xcresults remain local under `/tmp/flatmark-ticket05/`.

```sh
(cd Demo && xcodegen generate)

# Each phase ran separately, with review or fixture edits between phases.
# Initial mac-record failed compilation; mac-record2 and ios-record recorded
# seven expected assertions each. final-record corrected capture height only.
for phase in final-record verify-Table short-cell fill-blank empty-mutation restored offset-final; do
  for platform in macOS iOS; do
    dest=mac
    [ "$platform" = iOS ] && dest=674C04A9-8792-4995-A6A9-66F80E5F96AA
    scheme=FlatMarkSnapshots-$platform
    [ "$phase" = final-record ] && scheme=$scheme-Record
    sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme "$scheme" --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkTableSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket05/$platform-$phase.xcresult
  done
 done

# Regression guard: all four existing suites, separate filtered verify runs.
for platform in macOS iOS; do
  dest=mac
  [ "$platform" = iOS ] && dest=674C04A9-8792-4995-A6A9-66F80E5F96AA
  for suite in LinkedImage InlineFlow OmissionSpacing NestedContainer; do
    sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMark${suite}SnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket05/$platform-verify-$suite.xcresult
  done
 done

shasum -a 256 -c /tmp/flatmark-ticket05/existing-before.sha256
find Tests/References/Snapshots/Tables -name '*.png' -exec shasum -a 256 {} \; | sort > /tmp/flatmark-ticket05/tables-after.sha256
diff -u /tmp/flatmark-ticket05/tables-before.sha256 /tmp/flatmark-ticket05/tables-after.sha256
swift test
git status --short
git diff --check
```

Every final reference was opened with the image reader. The following rows each
cover two PNGs (one per platform), named by their test stem:

| PNG test stem | macOS review | iOS review |
| --- | --- | --- |
| `wideLongCells` | Four headers, both long endings, blank cells, formatting, and complete outer/row rules visible; clear margins. Accepted. | Same checks with more wrapping; no hidden bottom glyphs. Accepted. |
| `narrowLeading` | Complete first column and left/top/bottom boundaries; partial second column at viewport edge, as expected. Outside margins clear. Accepted. | Same checks; FIRST END visible above the row boundary. Accepted. |
| `narrowTrailing` | Complete last column, LAST END, last body cell, right/top/bottom boundaries; partial third column at viewport edge. Accepted. | Same checks; no missing final glyphs or bottom rule. Accepted. |
| `enlargedLongCells` | Two complete visible columns, FIRST END and formatted second-row content intact; full bottom rule and margins. Accepted. | Larger Dynamic Type wraps and hyphenates; FIRST END and code ending intact; bottom rule and generous bottom margin visible. Accepted. |
| `headerOnly` | Both headers and all four outer boundaries visible; clear margins. Accepted. | Both headers and complete boundary visible; clear margins. Accepted. |
| `emptyInternalTableBetweenNeighbors` | Both paragraphs intact with ordinary neighbor spacing; no table ink or extra slot. Accepted. | Same checks; no unexpected gap or rule. Accepted. |
| `visiblePublicTableBetweenNeighbors` | Same paragraphs surround a visible one-cell header table; boundary complete. Accepted. | Same checks; both neighbor gaps and complete boundary visible. Accepted. |

Final explicit recording reported seven expected recording assertions per
platform, with no native capture/readiness failure. Separate `verify-Table` runs
passed seven tests each. Existing LinkedImage (2), InlineFlow (5), OmissionSpacing
(3), and NestedContainer (5) verify tests all passed on each platform. All 36
existing reference hashes stayed byte-identical. All fourteen new reference
hashes stayed unchanged through verify, mutations, restoration, and final runs.

VERIFY-only mutation probes produced these results on **each** platform:

| Probe | Mismatched references | Passed references |
| --- | --- | --- |
| Shorten both long end-column body cells to FIRST END / LAST END, reducing row height | wide, narrow leading, narrow trailing, enlarged | header-only, empty internal, visible control |
| Restore long cells; fill the authored first-column blank with FILLED BLANK | wide, narrow leading, enlarged | narrow trailing, header-only, empty internal, visible control |
| Restore blank; replace empty internal table with a one-cell MUTATED TABLE header | empty internal | all six other references |

Each mutation was removed before the next probe. The full fixture was restored
byte-for-byte before `restored`; seven tests passed per platform. `offset-final`
then added the explicit 0/400pt expectations and again passed seven per platform.
No mutation used recording. `swift test` passed 191 tests in 25 suites, with one
intentional LoaderSpyTests known issue and no unexpected failures.

**Running-app scroll check: NOT PERFORMED on either platform.** Both existing
demo schemes built and launched through `sweetpad run --detach --non-interactive`
with the same project/destinations. iOS runtime UI inspection exposed only the
outer document scroll area, Settings, and Markdown source. A Settings tap reported
success but the next UI inspection still showed the same targets; no table
horizontal scroll gesture or trailing-cell observation was obtained within the
bounded attempt. No macOS gesture-driven observation was obtained; the available
UI automation lane was simulator-based. Launch success and deterministic
snapshot offsets do not verify actual gesture reachability. That ticket criterion
remains unverified. Minimum-OS behavior, VoiceOver, selection, and vertically
constrained hosts are also outside this qualification.

### Image-phase qualification (ticket 06)

`FlatMarkImagePhaseSnapshotTests.swift` adds ten public-view cases per platform,
with 17 references each under `References/Snapshots/ImagePhases/{macOS,iOS}`.
The seven symbol cases each have a same-run hand-authored SwiftUI `control`.
Controls are independent plain SwiftUI contract fixtures; image captures exercise
the public renderer, `FlatMarkView`, and its real loading path.
No production or shared capture support changed. All loaders are local; the
`.invalid` Markdown URL is an identifier, not a network request.

Qualification used macOS 27.0.1 (26A434), Swift 6.4, and the iPhone 18 Pro
simulator on iOS 27.0. Captures offer a 200pt column inside 600×500pt bounds,
with 100pt insets, 2× scale, en_US, left-to-right, and body text. Body overrides
are 13pt on macOS and 17pt on iOS. This is not minimum-OS qualification.

Readiness has two gates. Loader bookkeeping must report completion for loaded
and failed cases. Then document size and mounted native descendant frames must
remain identical for five consecutive comparisons. The loop allows 100 attempts,
20ms apart. It records the fixture, environment, attempts, consecutive-stable
count, and all observed geometry on timeout. A failed gate prevents the
renderer-image assertion/recording. Controls are asserted before mounting the
renderer (suite lines 86–91); the readiness guard precedes the renderer-image
assertion (lines 125–129). A later timeout cannot undo a control recording.
Placeholder needs no loader. Held loading waits for request
start but deliberately keeps the operation outstanding. Geometry does not identify
phases, and completion does not prove drawing. Exact comparison against reviewed,
phase-specific references is the protection against premature captures.

The held loader polls its lock-protected release flag with cancellation-aware sleep.
A synchronous loader-exit `defer` marks completion without an intervening suspension.
Capture teardown cancels its task. Both the normal and throwing capture exits
also call `release()`; a readiness failure takes the throwing exit. Controls run
before any loader is mounted. Thus no early assertion, timeout, or capture error
can strand suspended work. This cleanup is not a new cancellation-behavior test.

#### Visual review

Every one of the 34 PNGs was opened with `read`. Rows below name both the `image`
and `control` PNG where present; each control was cross-checked against its image
in that platform's recording run. All content has clear capture-edge margins.
No URL text is shown. Loaded rasters replace the alt label rather than printing it.

| Case / PNGs on each platform | macOS review | iOS review | Coverage |
| --- | --- | --- | --- |
| `placeholder.image`, `.control` | Photo symbol, complete “Striped local diagram”; agrees with control | Same symbol and complete label; agrees with control | AC-10, no loader |
| `emptyAltPlaceholder.image`, `.control` | Photo plus “Image”; agrees with control | Photo plus “Image”; agrees with control | Generic fallback |
| `heldLoading.image`, `.control` | Clock plus descriptive label; agrees with control | Clock plus descriptive label; agrees with control | AC-10, outstanding request |
| `throwingFailure.image`, `.control` | Warning triangle, complete descriptive label; agrees with control | Warning triangle, complete descriptive label; agrees with control | AC-10, real thrown error |
| `emptyAltFailure.image`, `.control` | Warning triangle plus “Image”; agrees with control | Warning triangle plus “Image”; agrees with control | Failure generic fallback |
| `smallIntrinsicRaster.image` | Four-color 120×60pt raster, 2:1, below 200pt column width | Same intrinsic size and aspect | Intrinsic-size output |
| `oversizedRaster.image` | Complete four-color 200×100pt raster from 1000×500 source | Same fitted size and aspect | Narrow-proposal fit; outside margins expose overflow, not clipping into a fit |
| `mixedLoadedText.image` | 120×60pt raster below “Before the diagram”; trailing sentence below raster on one line | Same raster; trailing text wraps across two lines below it | Loaded responsive flow, no hidden overflow |
| `darkPlaceholder.image`, `.control` | Light photo symbol and complete label visible on black; agrees with control | White photo symbol and label visible on black; agrees with control | Dark symbol visibility |
| `darkFailure.image`, `.control` | Light triangle and complete label visible on black; agrees with control | White triangle and label visible on black; agrees with control | Dark failure visibility |

#### Runs and probes

Logs, mismatch attachments in xcresults, and hash manifests are retained locally
under `/tmp/flatmark-ticket06/`. Files prefixed `revised-` are this qualification;
earlier experiments and `unaccepted/` are not baselines. Explicit recording
failed the ten tests on each platform only because recording assertions are
expected. There were no readiness failures in those recording runs. A first
compile attempt failed because the shared mounted callback is nonthrowing; the
suite now records the diagnostic there and throws after capture instead.

Separate verify runs passed all ten tests on both platforms. After restoring all
probes, both platforms passed ten again. SHA-256 checks kept all 34 new and all
50 existing references byte-identical. Existing suite guards passed on both
platforms: LinkedImage 2, InlineFlow 5, OmissionSpacing 3, NestedContainer 5,
Tables 7. No reference was re-recorded for a probe.

The held-loader probe deliberately held all loaded/failure requests and bypassed
the completion gate to force comparison of a stable premature frame. On each
platform, all six loaded/failure image references mismatched, while the other
four cases and all controls passed. The probe released held work on exit. With
the hold removed and completion restored, all ten cases passed separately.
Evidence: `revised-{macOS,iOS}-held-probe.{log,xcresult}` and
`revised-{macOS,iOS}-released-probe.{log,xcresult}`. This proves that a stable
loading frame cannot pass the loaded/failure reference; it does not claim that
geometry recognized a phase.

A second, controlled delayed-success probe used the existing
`smallIntrinsicRaster.image` reference, in verify mode only. This was a temporary
change, not a new permanent case or reference. Immediately after `delivery.start()`
and the completion `defer`, its loader executed
`try await Task.sleep(for: .seconds(1))`, then returned the unchanged raster.
The condition was `phase == .loaded && !oversized && !mixed`; no other fixture
was delayed. One second is ten times the five 20ms stable-comparison intervals.
With both completion and quiescence gates unchanged and enabled, all ten tests
passed on each platform. The delayed small-raster test took 1.231s on macOS and
1.236s on iOS and matched its accepted loaded reference.

For the contrasting run, the same fixture and one-second delay stayed in place.
Only that fixture's completion predicate changed from `completed` to `started`;
the five-comparison quiescence gate remained enabled. On both platforms, exactly
`smallIntrinsicRaster.image` failed its loaded reference; the other nine tests
passed. Both commands exited 3 for the expected mismatch, not a readiness timeout.
Thus the same delayed fixture passes with completion readiness and fails without
it: request start plus stable geometry is not sufficient. Normal and throwing
exits still called `delivery.release()`, and capture teardown still cancelled its
task; the sleep was cancellation-aware. No cleanup path was bypassed.

The temporary delay, predicate change, and diagnostic print were removed.
`cmp` confirmed the suite matched its pre-probe copy at
`/tmp/flatmark-ticket06/correction-accepted.swift` byte-for-byte. No reference was
recorded or changed. Final `shasum -a 256 -c` checks passed for all 34 accepted
and all 50 existing references. Exact commands from the repository root:

```sh
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac --non-interactive --result-bundle /tmp/flatmark-ticket06/correction-macOS-delay-gated.xcresult --only-testing FlatMarkSnapshots-macOS/FlatMarkImagePhaseSnapshotTests
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --non-interactive --result-bundle /tmp/flatmark-ticket06/correction-iOS-delay-gated.xcresult --only-testing FlatMarkSnapshots-iOS/FlatMarkImagePhaseSnapshotTests
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac --non-interactive --result-bundle /tmp/flatmark-ticket06/correction-macOS-delay-start-only.xcresult --only-testing FlatMarkSnapshots-macOS/FlatMarkImagePhaseSnapshotTests
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --non-interactive --result-bundle /tmp/flatmark-ticket06/correction-iOS-delay-start-only.xcresult --only-testing FlatMarkSnapshots-iOS/FlatMarkImagePhaseSnapshotTests
```

Logs use the same stems with `.log` instead of `.xcresult`.

Verify-only mutations had identical results on both platforms:

| Mutation | Mismatched references | Unchanged references |
| --- | --- | --- |
| Change raster blue channel and small-raster aspect to 120×90 | Three loaded images: small, oversized, mixed | All 14 symbol/control references |
| Change descriptive alt to “Changed description” | Images and controls for placeholder, loading, failure, dark placeholder, dark failure (10) | Empty-alt images/controls and three loaded images (7) |
| Make the throwing loader succeed | Three failure images | Failure controls and every other reference (14) |

`swift test --filter FlatMarkImageLoadingTests` passed 17 tests in one suite.
`swift test` passed 201 tests in 26 suites with the existing intentional
LoaderSpyTests known issue. `swift test --list-tests` listed all 17 loading tests
and all ten new snapshot tests. Existing loading, numeric fitting, accessibility
phase-label, URL-policy, and loader-configuration tests remain unchanged.

Commands (one capture process at a time, from the repository root):

```sh
(cd Demo && xcodegen generate)
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS-Record --on mac --non-interactive --result-bundle /tmp/flatmark-ticket06/revised-mac-record2.xcresult --only-testing FlatMarkSnapshots-macOS/FlatMarkImagePhaseSnapshotTests
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS-Record --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --non-interactive --result-bundle /tmp/flatmark-ticket06/revised-ios-record.xcresult --only-testing FlatMarkSnapshots-iOS/FlatMarkImagePhaseSnapshotTests
# platform=macOS: dest=mac; platform=iOS:
# dest=674C04A9-8792-4995-A6A9-66F80E5F96AA
# suite=LinkedImage, InlineFlow, OmissionSpacing, NestedContainer, Table, ImagePhase
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --non-interactive --result-bundle /tmp/flatmark-ticket06/revised-$platform-verify-$suite.xcresult --only-testing FlatMarkSnapshots-$platform/FlatMark${suite}SnapshotTests
# Same command with suite=ImagePhase and result stem revised-$platform-$phase:
# phase=held-probe, released-probe, mutation-raster, mutation-alt,
# mutation-success, final-verify, gated-final-verify
shasum -a 256 -c /tmp/flatmark-ticket06/existing-before.sha256
shasum -a 256 -c /tmp/flatmark-ticket06/accepted.sha256
swift test --filter FlatMarkImageLoadingTests
swift test
swift test --list-tests
git status --short
git diff --check
```

These captures qualify fixture appearance and exact repeatability only. They do
not prove cancellation behavior, accessibility labelling, URL policy, live
VoiceOver, interaction, system Dynamic Type, or general running-app behavior.
Those claims stay with the existing test families and manual checks.

### Task-marker qualification (ticket 07)

`FlatMarkTaskMarkerSnapshotTests` owns nine public-view cases and eighteen PNGs
in `TaskMarkers/{macOS,iOS}`. Swift Testing serializes mounted cases. Shared
support performs exact comparison with no pixel tolerances. No production,
fixture, interaction, or source-preservation test changed.

Qualified with Xcode 27.0 (27A266a), Swift 6.4, macOS 27.0.1 (26A434) on the
2x display, and iPhone 18 Pro on iOS 27.0. Body captures offer a 280pt column
inside 700×650pt bounds with 150pt insets. Enlarged captures are 700×1500pt.
All use 2x, light, en_US, LTR, and intrinsic vertical document sizing.
iOS enlarged uses real `.accessibility3`; macOS uses a 28pt absolute font
override, not system Dynamic Type. Explicit `.body` marker fonts remain small
on macOS while the label enlarges; marker baselines still meet the first line.

The shared `FlatMarkFixtureTaskMark` is not reachable from these targets:
`Demo/project.yml` compiles only the Snapshots folder into each snapshot target.
The demo compiles fixture sources directly; it does not export a fixture module.
The local passive custom drawing uses purple filled checkmark circles / empty
circle outlines, instead of the default green checked squares / gray square
outlines. It adds no actions, gestures, or accessibility semantics.

#### Baseline review

The implementation worker opened **each of the eighteen PNGs with `read`**.
Each row names two individual PNGs, one in each platform directory. The filename
suffix records the environment above; every capture has clear image-edge margins.
All four states (checked/unchecked parent and checked/unchecked nested) remain
visible. The long unchecked nested label wraps below its first line without
moving its marker down. Nesting shifts the children inward in these LTR cases.

| PNG test stem | macOS review | iOS review |
| --- | --- | --- |
| `defaultInteractive` | Green filled checked squares and gray empty squares; first-line alignment, three-line child, indentation, margins intact. Accepted. | Same states/alignment; three-line child and indentation intact. Accepted. |
| `defaultReadOnly` | All squares retained; same appearance as interactive; baseline/wrap/margins intact. Accepted. | Same checks and appearance as interactive. Accepted. |
| `defaultDisabled` | All squares retained, visibly paler; text unchanged; baseline/wrap/indent/margins intact. Accepted. | All squares retained and paler; baseline/wrap/indent/margins intact. Accepted. |
| `customInteractive` | Purple filled checked circles and empty outlines; baseline/wrap/indent/margins intact. Accepted. | Same distinct circles and states; baseline/wrap/indent/margins intact. Accepted. |
| `customReadOnly` | All circles retained; same appearance as interactive; baseline/wrap/indent/margins intact. Accepted. | Same checks and appearance as interactive. Accepted. |
| `customDisabled` | All circles retained but paler purple; baseline/wrap/indent/margins intact. Accepted. | All circles retained but paler purple; baseline/wrap/indent/margins intact. Accepted. |
| `customRetainedDocument` | Intended purple drawings, identical to source-initializer custom capture; baseline/wrap/indent/margins intact. Accepted. | Same initializer equivalence and visible checks. Accepted. |
| `enlargedDefault` | Small body squares beside larger labels; markers stay on first baseline, complete five-line child and inward indentation; clear margins. Accepted. | Squares scale with Dynamic Type; parent/child labels wrap, complete eight-line long child, first-line markers and indentation retained. Accepted. |
| `enlargedCustom` | Small body purple circles beside larger labels; correct states, complete five-line child, first-line markers, inward indent and clear margins. Accepted. | Purple circles scale; correct states, complete eight-line long child, first-line markers, inward indent and clear margins. Accepted. |

Disabled appearance is an observation of the native plain-button environment,
not a new styling contract or proof of edit prevention. Read-only does not need
a distinct style. No special disabled styling was invented in the custom drawing.
`cmp` found source and retained custom PNGs byte-identical on each platform.
Default/custom interactive PNGs have equal 1400×1300 dimensions but different
bytes (first difference at byte 2941 on macOS, 604 on iOS). Visual review confirms
square/green-gray versus circle/purple; the difference is not merely metadata.

#### RTL diagnostic — blocked directional indentation

No RTL defect was blessed as a reference. A temporary `rtlInvestigation()` test
captured the exact suite Markdown, read-only default markers, with a red 1pt
border around the offered 280pt frame. It compared LTR/RTL environments with
1200×800pt bounds, 400pt inset, body text, light, en_US, requested 2x scale.
It exported directly after `flatMarkSnapshotImage`, without recording assertions.
Both normal schemes passed ten tests (nine accepted cases plus diagnostic).
The temporary test was removed; its source remains locally in
`/tmp/flatmark-ticket07/rtl-investigation.swift`.

All four diagnostic PNGs were opened with `read` and retained in
`AI-docs/prds/ui-snapshot-testing/evidence/` as
`defect-task-list-{leftToRight,rightToLeft}-{macOS,iOS}.png`.
**These are diagnostic evidence, not baselines.** macOS direct export is
1200×800 pixels (1x); iOS is 2400×1600 (2x). They establish geometry only.
All wording and all four square states are intact, first-line markers are visible,
and no ink touches the capture edges. This compact fixture does not reproduce
ticket 04's out-of-column continuation drawing. It exposes a different problem:
LTR child markers move right (inward), but RTL child markers also move right
(outward, toward the red right boundary), instead of left/inward. This happens
on both platforms. RTL directional indentation remains blocked and needs a
**separate bounded production fix** before accepting RTL task references.

#### Runs, regression guard, and mutation probes

All capture commands ran serially from the repository root. Logs, xcresults,
source copies, and SHA-256 manifests remain local under `/tmp/flatmark-ticket07/`.
Explicit recordings selected nine tests per platform and failed only with nine
expected recording assertions; no capture failures. Separate normal `verify`
and restored `final` runs each passed nine tests on each platform.

Before any recording, `existing-before.sha256` recorded all 84 existing PNGs.
The six existing suite guards passed on each platform: LinkedImage 2, InlineFlow 5,
OmissionSpacing 3, NestedContainer 5, Table 7, ImagePhase 10 tests.
`shasum -a 256 -c` kept all 84 byte-identical. All eighteen task PNG hashes stayed
unchanged through verification, diagnostics, mutations, restoration, and full tests.

VERIFY-only probes had the same results on both platforms:

| Probe | Temporary change | Mismatched references | Passed references |
| --- | --- | --- | --- |
| `state` | Flip checked parent from `[x]` to `[ ]` | All nine | None |
| `custom` | Replace purple circles with orange diamonds | customInteractive, customReadOnly, customDisabled, customRetainedDocument, enlargedCustom | defaultInteractive, defaultReadOnly, defaultDisabled, enlargedDefault |
| `indent` | Add two Markdown spaces before checked nested task, making it a grandchild | All nine (all include nesting) | None |

Each probe exited 3 for genuine comparison mismatches, not recording assertions.
Each previous change was removed before the next probe. `cmp` confirmed final
suite source matched `/tmp/flatmark-ticket07/accepted.swift` byte-for-byte.
No probe used a recording scheme.

Exact command patterns (each phase ran separately, with review or fixture edits
between phases; `platform=macOS` uses `dest=mac`, `platform=iOS` uses
`dest=674C04A9-8792-4995-A6A9-66F80E5F96AA`):

```sh
(cd Demo && xcodegen generate)
sweetpad devices
sw_vers
swift --version
xcodebuild -version
find Tests/References/Snapshots -name '*.png' -exec shasum -a 256 {} \; | sort > /tmp/flatmark-ticket07/existing-before.sha256
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS-Record --on mac --only-testing FlatMarkSnapshots-macOS/FlatMarkTaskMarkerSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket07/mac-record.xcresult
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS-Record --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --only-testing FlatMarkSnapshots-iOS/FlatMarkTaskMarkerSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket07/ios-record.xcresult
# phase=verify, rtl, state, custom, indent, final; both platforms, one at a time:
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkTaskMarkerSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket07/$platform-$phase.xcresult
# suite=LinkedImage, InlineFlow, OmissionSpacing, NestedContainer, Table, ImagePhase:
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMark${suite}SnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket07/$platform-guard-$suite.xcresult
find Tests/References/Snapshots/TaskMarkers -name '*.png' -exec shasum -a 256 {} \; | sort > /tmp/flatmark-ticket07/accepted.sha256
shasum -a 256 -c /tmp/flatmark-ticket07/existing-before.sha256
shasum -a 256 -c /tmp/flatmark-ticket07/accepted.sha256
swift test --list-tests
swift test --filter FlatMarkTaskMarkerTests
swift test --filter FlatMarkTaskMarkerToggle
swift test --filter FlatMarkListRowViewTests
swift test --filter FlatMarkCustomUnsupportedContentTests
swift test --filter FlatMarkOmissionLiveUpdateTests
swift test
git status --short
git diff --check
```

The listed package filters passed respectively 2 tests (6 argument cases),
11 tests in 4 suites, 4 tests, 20 tests in 2 suites, and 2 tests.
Full `swift test` passed 210 tests in 27 suites, with the existing intentional
LoaderSpyTests known issue and no unexpected failures. Existing marker/editing
and source-byte coverage remains unedited. Demo project regeneration included
the new suite; no target configuration or dependencies changed.

**Shared running-demo marker observation: NOT PERFORMED on either platform.**
Both demo schemes built and launched with the `hostMarkers` preset through
SweetPad. The simulator screenshot showed the top Recipe Lab controls and
recipe introduction, not tasks. The desktop screenshot showed the macOS demo
at the same introduction, partly behind the simulator. The bounded attempt did
not navigate to task content or operate marker variant controls. Thus launch
and initial-viewport observation succeeded, but marker observation remains
unverified rather than inferred from mounted captures. Local screenshots and
launch logs are under `/tmp/flatmark-ticket07/`.

```sh
sweetpad run --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkDemo-macOS --on mac --arg --capture --arg hostMarkers --detach --non-interactive
sweetpad run --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkDemo-iOS --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --arg --capture --arg hostMarkers --detach --non-interactive
xcrun simctl io 674C04A9-8792-4995-A6A9-66F80E5F96AA screenshot /tmp/flatmark-ticket07/ios-demo.png
screencapture -x /tmp/flatmark-ticket07/mac-demo.png
```
Snapshots do not establish hit-target size, keyboard activation, VoiceOver focus
order, edit prevention, minimum-OS behavior, or general running-app behavior.

### Unsupported-policy qualification (ticket 08)

`FlatMarkUnsupportedPolicySnapshotTests` owns eight cases and eight references per
platform in `UnsupportedPolicies/{macOS,iOS}`. Public views exercise literal,
custom, and omit policies; empty custom output; and ambient enabled/disabled
host controls. A set-based assertion requires the empty host to receive exact
opening, closing, and whole-block payloads. Re-evaluation counts are not asserted.
Existing payload, independent-action, enabled-environment, and no-HTML-fetch
coverage remains unchanged.

Qualified with Xcode 27 RC / Swift 6.4, macOS 27.0.1 on the 2x display, and
booted iPhone 18 Pro on iOS 27.0 (674C04A9-8792-4995-A6A9-66F80E5F96AA).
Captures use a 400pt column, 80pt inset, 640×550pt bounds, 2x, light, en_US,
LTR, body text (13pt macOS / 17pt iOS overrides), and intrinsic vertical sizing.
No production code or capture behavior changed. Project regeneration registers
the suite in both snapshot targets; the only shared-support edit adds its approved
namespace enum case.

#### Visual review

The implementation worker opened every recorded PNG with `read` at readable
scale. The table names both platform PNGs by test stem; every file has suffix
`.document-400col-80inset-640x550-2x-light-en_US-ltr-body.png`.

| Stem (macOS and iOS) | Observed checks |
| --- | --- |
| `literal` | Inert inline and whole-block HTML source visible; bold, italic neighbor, blue link, before/after wording intact. |
| `custom` | Indigo OPEN precedes middle/label, orange CLOSE follows each; one BLOCK drawing replaces the whole block. White monospaced host styling remains distinct from blue link text. Bold and italic neighbors survive. |
| `omit` | Tags and whole block absent; supported bold/italic and blue link wording retained. |
| `emptyLiteral` | `a<u></u>b`, HTML-only paragraph, and whole-block source all visible. |
| `emptyCustom` | Contiguous `ab`, no fallback, synthetic wording, or minimum host box; empty HTML-only paragraph retains a parent gap before the after paragraph. |
| `emptyOmit` | Contiguous `ab`; the HTML-only paragraph is recursively removed, so the after paragraph is closer than in empty custom. |
| `enabledHost` | Two white-on-indigo ENABLED controls occupy separate inline positions amid bold supported text. |
| `disabledHost` | Both controls read DISABLED with gray presentation; surrounding supported wording remains. |

All sixteen PNGs have clear outside margins and complete wording. No clipping
or known rendering defect was accepted. The initial fixture did not include the
HTML-only paragraph; it was added before final recording to distinguish retained
parent spacing from recursive omission. A whole-block EmptyView alone collapses
in these hosts; the contract does not require it to leave a gap.

#### Commands and outcomes

Runs were serial, from the repository root. Logs, source copy, manifests, and
xcresults remain under `/tmp/flatmark-ticket08/`. These command patterns describe
all phases (each phase ran separately, with review/edits between phases):

```sh
(cd Demo && xcodegen generate)
# platform=macOS: dest=mac; platform=iOS: dest=booted
# Explicit initial recording used mac-record / ios-record result stems.
# Final recording after the HTML-only paragraph was added:
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform-Record --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkUnsupportedPolicySnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket08/$platform-record-final.xcresult
# phase=verify, fallback, positions; normal schemes only:
find Tests/References/Snapshots -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-ticket08/$platform-$phase-before.sha256
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkUnsupportedPolicySnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket08/$platform-$phase.xcresult
find Tests/References/Snapshots -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-ticket08/$platform-$phase-after.sha256
diff -u /tmp/flatmark-ticket08/$platform-$phase-{before,after}.sha256
# final: same manifest guard, no --only-testing (all eight namespaces):
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --non-interactive --result-bundle /tmp/flatmark-ticket08/$platform-final.xcresult
shasum -a 256 -c /tmp/flatmark-ticket08/existing.sha256
cmp /tmp/flatmark-ticket08/accepted.swift Tests/FlatMarkTests/Snapshots/FlatMarkUnsupportedPolicySnapshotTests.swift
swift test
git diff --check
```

Both initial and final recordings reported eight expected recording assertions
per platform, with no capture failures. Separate `verify` runs passed eight each.
VERIFY-only fallback probes replaced EmptyView with `Text("FALLBACK WORDING")`:
only `emptyCustom` mismatched on each platform (seven passed). Restoring EmptyView
and exchanging OPEN/CLOSE labels caused only `custom` to mismatch (seven passed).
Both probes exited 3 for real image mismatches, not recording assertions. Source
restoration matched the saved copy byte-for-byte. Final full normal schemes passed
49 tests per platform: eight new and 41 across the seven existing namespaces.

Before/after manifests for every verify/probe/final run matched exactly. All 102
existing reference hashes and sixteen new reference hashes stayed unchanged.
Normal schemes never wrote references. Missing-reference behavior relies on the
unchanged ticket 01 support contract; this ticket did not repeat that probe.
Full `swift test` passed 218 tests in 28 suites with one existing intentional
LoaderSpyTests known issue and no unexpected failures. `git diff --check` passed.

These are mounted appearance and repeatability checks, not running-demo or
callback observations. No new iOS action activation, live VoiceOver, keyboard,
selection, minimum-OS, or general running-app behavior was verified. Exact
payload and independent activation claims remain with existing behavioral tests;
full package testing runs their macOS lane, not iOS interaction.

### Empty-structure qualification (ticket 09)

`FlatMarkEmptyStructureSnapshotTests` owns five public-view cases and five PNGs
per platform in `EmptyStructures/{macOS,iOS}`. All use local Markdown with `.omit`,
serialized Swift Testing, and exact comparison. No production or existing test
changed. The only shared-support change adds the approved namespace case;
XcodeGen registers the new file in both targets.

Qualified in the established Xcode 27 RC / Swift 6.4 lane: macOS 27.0.1 on the
2x display and booted iPhone 18 Pro on iOS 27.0. Captures offer a 340pt column,
100pt inset, 560×450pt bounds (560×950pt enlarged), 2x, light, en_US, LTR, and
intrinsic vertical sizing. iOS enlarged uses `.accessibility3`; macOS uses a
28pt font override, not system Dynamic Type.

The implementation worker opened every one of the ten recorded PNGs with `read`.
Each row below names both platform references by test stem:

| Stem | Visual review on macOS and iOS |
| --- | --- |
| `emptyTaskInteractive` | Empty gray square visibly retained above green checked neighbor; no synthetic label or HTML ink. |
| `emptyTaskReadOnly` | Same visible empty square and checked neighbor without a callback. |
| `authoredOrderedRows` | `7.` remains in its empty first row; `8.` precedes `keep` in the next row. |
| `omittedTableCells` | A/B columns retained; `keep` stays right, `left` stays left; fully empty third body row remains above last/end; outer boundary and horizontal row rules complete. No internal vertical rules are promised. |
| `enlargedEmptyTask` | Empty square retained; checked neighboring wording wraps into three lines on macOS and five on iOS; all wording and both markers intact. |

All references have clear outside margins. These compact LTR fixtures do not
include the known overflowing list continuations or RTL indentation defects.
No new clipping or rendering defect was accepted.

Commands ran serially from the repository root. Logs, xcresults, accepted source
copy, and manifests remain local under `/tmp/flatmark-ticket09/`:

```sh
(cd Demo && xcodegen generate)
find Tests/References/Snapshots -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-ticket09/existing.sha256
# platform=macOS: dest=mac; platform=iOS: dest=booted
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform-Record --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkEmptyStructureSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket09/$platform-record.xcresult
# Run each phase separately, with the probe edit/restoration between phases.
# phase=verify, probe: filter shown below. phase=final: omit --only-testing.
find Tests/References/Snapshots -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-ticket09/$platform-$phase-before.sha256
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkEmptyStructureSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket09/$platform-$phase.xcresult
find Tests/References/Snapshots -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-ticket09/$platform-$phase-after.sha256
diff -u /tmp/flatmark-ticket09/$platform-$phase-{before,after}.sha256
shasum -a 256 -c /tmp/flatmark-ticket09/existing.sha256
cmp /tmp/flatmark-ticket09/accepted.swift Tests/FlatMarkTests/Snapshots/FlatMarkEmptyStructureSnapshotTests.swift
swift test
git diff --check
```

An initial macOS compile attempt (`mac-record`) caught initializer argument order;
no references were written by that attempt. Corrected explicit recordings
(`macOS-record`, `iOS-record`) each reported five expected recording assertions,
with no capture failures. Separate `verify` runs passed five tests per platform.
The VERIFY-only probe changed the ordered source to `9.` / `10.`. Each platform
reported one genuine ordered-row mismatch and four passes, not recording failures.
Restoration matched the saved source byte-for-byte. Full normal `final` runs
passed 54 tests per platform: five new and 49 across the eight existing namespaces.
Every verify/probe/final before/after manifest matched. All 118 existing PNGs and
ten new PNGs stayed byte-identical; verify mode wrote no references.
Missing-reference behavior relies on the unchanged ticket 01 contract, not a
repeated probe here.

Full `swift test` passed 223 tests in 29 suites with one existing intentional
LoaderSpyTests known issue and no unexpected failures. Existing byte-exact task
updates, omitted-label activation, and list/table projection assertions remain
intact. `git diff --check` passed.

All ticket 09 appearance criteria pass for these reviewed fixtures. These are
mounted appearance and repeatability checks, not live callback, running-demo,
VoiceOver, keyboard, selection, minimum-OS, or general overflow qualification.
No new iOS activation or macOS system Dynamic Type observation was performed.

### Native-placeholder qualification (ticket 10)

`FlatMarkNativePlaceholderFlowSnapshotTests` adds eight public-view cases and
sixteen PNGs in `NativePlaceholderFlow/{macOS,iOS}`. Each fixture runs at 160pt
and 320pt columns, with standard and enlarged text: four wrapping cases and four
hard-break cases. Swift Testing serializes the suite. The unlinked relative image
and absent loader/custom policy keep `renderingMode` in `inlineText`: no linked
image or custom-flow branch applies, and no loaded phase can arise. Inspection
traced `inlineText` through `labeledImageText` (photo symbol plus alt label).
The two existing native fitted-size proxy tests remain unchanged.

Qualified with Xcode 27 RC / Swift 6.4, macOS 27.0.1 on the 2x display, and
booted iPhone 18 Pro on iOS 27.0. All captures are fixed 520×1500pt, 80pt inset,
2x, light, en_US, LTR, with intrinsic vertical document sizing. macOS standard
uses a 13pt absolute font override; enlarged uses 28pt, not system Dynamic Type.
iOS standard uses a 17pt override at `.large`; enlarged removes the absolute
font override and uses real `.accessibility3` Dynamic Type.

The implementation worker opened every recorded PNG with `read` at readable
scale. These stems identify all eight files in **each** platform directory:

| Stems | Review on both platforms |
| --- | --- |
| `narrowStandardWrapping`, `wideStandardWrapping` | Photo symbol, complete Diagram label, introduction, and final “after it.” visible; narrower column wraps more. |
| `narrowEnlargedWrapping`, `wideEnlargedWrapping` | Visibly larger glyphs and more rows; all wording and symbol intact. Native wrapping can separate symbol and label across rows. |
| `narrowStandardHardBreaks`, `wideStandardHardBreaks` | Short “A” line above photo symbol and D label; “A diagram explanation continues to its final words.” starts below; all wording intact. |
| `narrowEnlargedHardBreaks`, `wideEnlargedHardBreaks` | Same three-part break structure at larger effective text; symbol and D stay together; complete trailing sentence. |

All sixteen references have clear outside margins, nonempty drawn wording and
symbols, and no clipping. No defect baseline was accepted. All PNGs have identical
1040×3000 pixel dimensions; SHA-256 comparison found eight distinct hashes per
platform. Thus narrow/wide and standard/enlarged differences are not explained
by different canvas sizes. Exact comparison to these reviewed nonempty references
rejects collapsed output; this suite does not compare two potentially empty views.

Commands ran serially from the repository root. Logs, xcresults, source copy, and
before/after manifests remain locally under `/tmp/flatmark-ticket10/`:

```sh
(cd Demo && xcodegen generate)
find Tests/References/Snapshots -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-ticket10/existing.sha256
# platform=macOS: dest=mac; platform=iOS: dest=booted
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform-Record --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkNativePlaceholderFlowSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket10/$platform-record.xcresult
# phase=verify, break-probe, label-probe; each phase ran separately after edits/review:
find Tests/References/Snapshots -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-ticket10/$platform-$phase-before.sha256
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --only-testing FlatMarkSnapshots-$platform/FlatMarkNativePlaceholderFlowSnapshotTests --non-interactive --result-bundle /tmp/flatmark-ticket10/$platform-$phase.xcresult
find Tests/References/Snapshots -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-ticket10/$platform-$phase-after.sha256
diff -u /tmp/flatmark-ticket10/$platform-$phase-{before,after}.sha256
# final uses the same manifest guard, without --only-testing:
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-$platform --on "$dest" --non-interactive --result-bundle /tmp/flatmark-ticket10/$platform-final.xcresult
shasum -a 256 -c /tmp/flatmark-ticket10/existing.sha256
cmp /tmp/flatmark-ticket10/accepted.swift Tests/FlatMarkTests/Snapshots/FlatMarkNativePlaceholderFlowSnapshotTests.swift
swift test
git diff --check
```

Explicit recordings each selected eight tests and reported eight expected recording
assertions, with no native capture failures. Separate normal verify runs passed
eight per platform. VERIFY-only `break-probe` replaced the first hard break with
a space: macOS wide enlarged mismatched (seven passed); all four iOS hard-break
cases mismatched (four passed). At the other macOS settings natural wrapping
masked the removed break. After restoring that break, `label-probe` changed both
fixtures' alt label to Changed label: eight genuine mismatches per platform.
Both probes exited 3, not recording assertions. Restored source matched the saved
copy byte-for-byte. Full normal final runs passed 62 tests per platform: eight
new and 54 across all nine existing namespaces. Every before/after verification
manifest matched; all 128 existing and sixteen new reference hashes stayed
unchanged. No probe used recording or updated references.

Full `swift test` passed 231 tests in 30 suites, with one existing intentional
LoaderSpyTests known issue and no unexpected failures. `git diff --check` passed.
Round 1 did not qualify independent sensitivity to both authored hard breaks. The round-2 evidence below supersedes its hard-break probe and acceptance conclusion. These mounted images
do not establish selection gestures, semantic selectability, VoiceOver, keyboard,
minimum-OS behavior, running-demo behavior, or macOS system Dynamic Type.
Existing link, alt-policy, whitespace, and semantic tests remain intact.

#### Round 2: independent hard-break qualification

The repaired hard-break fixture is:

```markdown
A\
![D](image.png)\
A diagram explanation continues to its final words.
```

Short boundary wording leaves room for content to join when either break is removed.
The wrapping fixture, native no-loader `inlineText` path, and fixed 520×1500pt
capture remain unchanged. Only the eight `HardBreaks` references were re-recorded.
The worker opened each changed PNG with `read`: the first A, photo symbol, D,
second A, and complete final sentence are visible, with both authored boundaries
and ample outside margins. No clipping or defect baseline was accepted.

Evidence and the executable command wrapper are in
`/tmp/flatmark-ticket10/round2/` (`run.sh`, `accepted.swift`, platform-phase logs,
unique xcresults, and full before/after SHA-256 manifests). Commands used the
same lanes above. Recording selected each `HardBreaks()` method explicitly;
verify and probes selected the whole suite; final runs were unfiltered.
An initial recording filter without `()` selected zero tests and changed nothing;
it is not verification evidence. Corrected explicit recordings each selected four
tests and produced four expected recording assertions (exit 3), not comparison
failures.

Each probe replaced only one authored break with a space. The other break remained
intact. All entries below are genuine non-recording reference mismatches (exit 3):

| Reference stem | macOS before removal | macOS after removal | iOS before removal | iOS after removal |
| --- | --- | --- | --- | --- |
| `narrowStandardHardBreaks` | mismatch | mismatch | mismatch | mismatch |
| `wideStandardHardBreaks` | mismatch | mismatch | mismatch | mismatch |
| `narrowEnlargedHardBreaks` | mismatch | mismatch | mismatch | mismatch |
| `wideEnlargedHardBreaks` | mismatch | mismatch | mismatch | mismatch |

These are the corresponding `document-…png` references in
`Tests/References/Snapshots/NativePlaceholderFlow/<platform>/`. Each of the four
probe runs had four genuine mismatches and four wrapping passes. No probe recorded
or changed references. Restored source matches `round2/accepted.swift` byte-for-byte.
Separate restored non-recording verify runs passed eight tests on each platform.
Subsequent full unfiltered lanes passed 62 tests each. All before/after manifests
for probes, verifies, and final runs matched exactly. The original 128 references
remain byte-identical, as do the eight wrapping references from round 1. The final
sixteen hashes are retained in `round2/final-native.sha256`; each platform still
has eight distinct references on the same 1040×3000 pixel canvas.

Full round-2 `swift test` passed 231 tests in 30 suites with one existing intentional
LoaderSpyTests known issue and no unexpected failures. Its reference manifests
also matched. `git diff --check` passed.

**Acceptance:** PASS for independent drawn sensitivity to each authored break at
all four captured settings on both platforms, complete visible placeholder content,
and the reviewed fixed-canvas appearance at those settings. This is not a claim
that all possible appearance or interaction criteria pass. Selection gestures,
semantic selectability, VoiceOver, keyboard, minimum-OS behavior, running-demo
behavior, and macOS system Dynamic Type remain unverified by these captures.

### Shared-fixture reachability (ticket 10a)

Qualified environment: Xcode 27.0 (27A266a), Swift 6.4, macOS destination
`mac`, and iPhone 18 Pro simulator on iOS 27.0.

**Mechanism (inspection):** `Demo/project.yml` adds
`- path: ../Support/FlatMarkFixtures` to both snapshot targets. XcodeGen places
these sources and the existing `focaccia.jpeg` in both test bundles. Outside
SwiftPM, `FlatMarkFixtureResources.bundle` now tries a private class token's
`Bundle(for:)` before falling back to `Bundle.main`. The sources compile into
the bundle that embeds the raster. `Bundle.module` is unchanged. There is no
new raster, dependency, public product, or production-source change. Publishing
a `FlatMarkFixtures` product would change `Package.swift`'s public build surface;
that larger option was not taken.

**Compilation and automated test:** An identical temporary probe used
`@testable import FlatMark` on both lanes and referenced `FlatMarkRecipeSample`,
`FlatMarkCustomFixtureModel`, and `FlatMarkCustomDocumentFixture`. It required a
non-nil raster URL, a `.xctest` bundle path, and a decoded native image with
positive width and height. Both probes passed one test (exit 0). The probe was
then deleted and XcodeGen rerun. No probe remains in the generated project.

Raw output (automated test):

```text
FIXTURE_PROBE bundle=/Users/noemirozpara/Library/Developer/Xcode/DerivedData/FlatMarkDemo-dykqjaewytgiccajucmwhqwmhyty/Build/Products/Debug/FlatMarkSnapshots-macOS.xctest raster=/Users/noemirozpara/Library/Developer/Xcode/DerivedData/FlatMarkDemo-dykqjaewytgiccajucmwhqwmhyty/Build/Products/Debug/FlatMarkSnapshots-macOS.xctest/Contents/Resources/focaccia.jpeg
FIXTURE_PROBE bundle=/Users/noemirozpara/Library/Developer/CoreSimulator/Devices/674C04A9-8792-4995-A6A9-66F80E5F96AA/data/Containers/Bundle/Application/87F4CC16-5263-44C8-A246-1BFBB7EDCA40/FlatMarkDemo.app/PlugIns/FlatMarkSnapshots-iOS.xctest raster=/Users/noemirozpara/Library/Developer/CoreSimulator/Devices/674C04A9-8792-4995-A6A9-66F80E5F96AA/data/Containers/Bundle/Application/87F4CC16-5263-44C8-A246-1BFBB7EDCA40/FlatMarkDemo.app/PlugIns/FlatMarkSnapshots-iOS.xctest/focaccia.jpeg
```

**Final verification:** After ticket 10b committed the sRGB macOS capture pin,
both non-recording lanes passed all 62 tests each (exit 0). `swift test` passed
231 tests in 30 suites with one known issue and no snapshot failures (exit 0).
The earlier 27 macOS snapshot mismatches were Blocker 4: captures inherited the
recording display's ICC profile. Ticket 10b resolved that blocker. Both demo
builds passed (exit 0, build-only evidence). The token's code is compiled into
the app bundle for each demo, which embeds the raster (inspection). Demo raster
resolution has not been observed in a running app. All 144 accepted reference
hashes are identical (diff exit 0). `git diff --check` passed. No Record scheme ran.

Exact continuation commands, from the repository root:

```sh
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac --non-interactive --result-bundle /tmp/flatmark-10a/mac-verify.xcresult
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --non-interactive --result-bundle /tmp/flatmark-10a/ios-verify.xcresult
sweetpad build --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkDemo-macOS --on mac --non-interactive
sweetpad build --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkDemo-iOS --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --non-interactive
swift test
find Tests/References -name '*.png' | sort | xargs shasum -a 256 > /tmp/flatmark-10a/references-after.txt
diff /tmp/flatmark-10a/references-baseline.txt /tmp/flatmark-10a/references-after.txt
git diff --check
# After adding the temporary probe:
(cd Demo && xcodegen generate)
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-macOS --on mac --non-interactive --only-testing FlatMarkSnapshots-macOS/FlatMarkFixtureReachabilityProbe --result-bundle /tmp/flatmark-10a/mac-probe.xcresult
sweetpad test --project Demo/FlatMarkDemo.xcodeproj --scheme FlatMarkSnapshots-iOS --on 674C04A9-8792-4995-A6A9-66F80E5F96AA --non-interactive --only-testing FlatMarkSnapshots-iOS/FlatMarkFixtureReachabilityProbe --result-bundle /tmp/flatmark-10a/ios-probe.xcresult
sweetpad test output --project Demo/FlatMarkDemo.xcodeproj --result-bundle /tmp/flatmark-10a/mac-probe.xcresult --full
sweetpad test output --project Demo/FlatMarkDemo.xcodeproj --result-bundle /tmp/flatmark-10a/ios-probe.xcresult --full
rm Tests/FlatMarkTests/Snapshots/FlatMarkFixtureReachabilityProbe.swift
(cd Demo && xcodegen generate)
git status --short
```

### Observation boundaries

- **Structure:** `visibleDocument(_:policy:)` records surviving literal/omitted blocks and nesting.
  `customHosts(in:)` records replacement positions, not what host views draw. Helpers live in
  `FlatMarkRenderObservation.swift`.
- **Native content:** `MountedView.visibleText` / `visibleAttributedText` export native selection
  through public `NSServicesMenuRequestor` APIs into a temporary pasteboard. Assertions cover
  wording and exported bold, italic, strikethrough, and link attributes. The general pasteboard
  is not used. A region with no wording at all reads as blank, for example an emptied row,
  item, or cell. A region that takes space and still cannot export fails instead of returning
  empty content. `visibleText(showing:)` waits for wording to appear. `visibleText(matching:)`
  waits for the exact wording a reader gets, so a mounted view that keeps its earlier answer
  after a state change fails. `FlatMarkOmissionSample.swift` pairs one Markdown source with the
  wording each built-in policy is expected to display, so the mounted and projection checks read
  one document.
- **Interaction:** isolated AppKit event-loop hosts activate links and task markers and inspect
  callbacks. Navigation hosts use hidden windows, local events, and a controlled opener: no global
  input, Accessibility permission, browser, or external handler is required. Reports and timeouts
  prevent treating process exit alone as successful activation.
- **Loader callbacks:** `LoaderSpy` retains every recorded loader callback until an expectation of
  that kind consumes it, so a test may arm before or after the operation that triggers the loader.
  One callback satisfies exactly one expectation, and a wait that ends at its deadline leaves the
  callback missing to be reported by the unmet confirmation rather than by a polling bound. Checks
  of that waiting contract live in `LoaderSpyTests` and are not evidence about the renderer.
- **Drawn image geometry:** the aspect-fitting check mounts a painted solid-color raster, waits for
  its own pixels to appear in the mounted view's drawing, and measures their bounding box in points
  inside a capture deliberately larger than any correct result. Missing or collapsed output, a wrong
  aspect ratio, and a measurement clipped into looking correct therefore all fail; an `NSImage(size:)`
  that only reports a size cannot pass. This is a bounded pixel readback of one fixture, not a
  screenshot review: it establishes that the loaded image drew at the fitted size, not its appearance,
  on-screen clipping, or placement.
- **Effective text size:** mounted layout cases vary an explicit font-size override, because macOS body
  text does not scale from `dynamicTypeSize` alone (the Recipe Lab fixture does the same). A control
  case asserts the override really changes rendered size, and every case requires positive geometry and
  strictly larger output once enlarged, so two variants that rendered identically cannot pass. A font
  override is not system Dynamic Type, VoiceOver, or readability verification.
- **Drawn flow placement:** the linked-image flow case mounts the shared inline flow in a capture wider
  than its column and measures where the view's own ink landed, so a flow that drew nothing, drew one
  unbroken line, or drew past the column fails. The case also asserts the fixture really is in that
  flow, since an image whose link did not resolve falls back to native text unnoticed.

Native-content inspection requires selectable views and is qualified on the current toolchain only;
see the floor lane for minimum-version coverage. SwiftUI descendant capabilities/order are not a stable
inspection contract; requalify after OS/toolchain changes. Accessibility text is a separate representation and is not a substitute for
visible-content inspection.

These tests do **not** prove glyph visibility, layout gaps, exact on-screen fonts, minimum
hit-target size, selection gestures, external URL-opening success, or iOS interaction. A nonzero
mounted size proves neither readability nor correct geometry. Only the linked-image flow above has an
automated hosting-independent width guard; table, quote, and cell overflow remain manual checks.

## Recipe Lab

The backend-free host renders one focaccia recipe shared with the mounted suite. It includes tasks,
mentions, links, a block photo, an inline leaf image inside a paragraph, tables, code, nested content,
and unsupported HTML.
Source: [FlatMarkCustomFixture.swift](../Support/FlatMarkFixtures/FlatMarkCustomFixture.swift) and
[FlatMarkRecipeSample.swift](../Support/FlatMarkFixtures/FlatMarkRecipeSample.swift).

Open [the demo Xcode project](../Demo/FlatMarkDemo.xcodeproj) and choose its iOS or macOS
scheme (see [demo setup](../Demo/README.md)). It references these shared sources directly.
Alternatively, with an iPhone simulator booted for iOS, run:

```sh
scripts/run-fixture-host.sh ios
scripts/run-fixture-host.sh macos
```

The default `daylight` preset uses custom replacements and standard text. Pass
`--capture generous` after the platform for enlarged text. iOS uses a 240-point reading column;
macOS follows window width. No login or backend data is needed. See the
[capture guide](References/RecipeLab/README.md) for all presets.

### Controls to exercise

| Area | Checks |
| --- | --- |
| HTML | **Show HTML / Replace tags / Hide HTML** correspond to literal/custom/omit |
| Replacements | Edit the label; toggle **Make replacements tappable** and **Replace with nothing** |
| Appearance | **Larger recipe text**, **Right-to-left recipe layout** |
| Tasks | **Use custom checkmarks** and **Allow ticking tasks** independently control drawing/editing |
| Snapshot reuse | **Use retained document**, **Re-render without editing**, **Add a tasting note** |

Refresh counters count host requests, not renderer evaluations or parser calls. Source edits
replace the snapshot; unchanged refreshes retain it. Both initializers
should agree on wording, attributes, links, and task behavior.

## Manual checklist

Run on both iOS and macOS; record OS, build, actions, observed results, and unavailable checks.

- **Policy changes:** exercise literal → custom → omit → literal → omit → custom → literal without
  source edits. Unsupported content should refresh, surviving tasks keep their addresses, and
  unaffected image loads should not restart. Empty paragraphs/headings/quotes removed by omission
  should leave no layout slot or quote rule. Supported list/table structure remains.
- **Custom content:** opening/closing tags create separate replacements. Empty custom views add no
  fallback or synthetic spaces, but parent spacing may remain. Supported neighboring text retains
  formatting and navigation.
- **Independent actions:** activate a host replacement, adjacent Markdown link, and task separately.
  Only the matching feedback/counter should change. HTML attributes must not cause navigation or
  fetching; supported Markdown images remain subject to the loader policy.
- **Task markers:** compare default/custom, checked/unchecked, nested, interactive/read-only, enlarged
  text, and RTL. One activation changes only its source marker. Read-only tasks offer no toggle
  action; marker drawings are not extra accessibility elements.
- **Mentions:** `@ja*ne*` bolds only `@ja`; whole-token emphasis/strikethrough remains. Code and link
  labels are excluded. Text nodes are scanned independently: `*email*@example.com` can bold
  `@example.com`, while plain `email@example.com` remains unchanged.
- **Layout:** inspect headings, tables, nested blocks, multiline text, images, and custom views at
  narrow/wide widths and enlarged text. Check RTL, clipping, overflow, and table-cell reachability.
- **Selection:** try selecting within and across native regions; record fragmentation rather than
  assuming continuous selection across mixed views.
- **Accessibility and keyboard:** use live VoiceOver to check labels, checked state, nesting, focus
  order, and independent actions. Check read-only semantics, disabled interactive tasks, and keyboard
  activation where supported. Confirm state is distinguishable without color alone.

Empty-label tasks, ordered rows, and table cells are covered by the focused omission tests rather
than the readable recipe. Preserve their markers, numbering, structure, and source-update behavior.

## Verification status

Earlier iOS simulator and macOS runs observed policy changes, source-preserving task updates,
independent custom/link actions, marker appearance, and selected layout cases. Mounted tests cover
initializer parity and mention attributes. These observations predate the current compact recipe
and do not verify its current UI.

Screenshot artifacts are not included; earlier captures predate the compact recipe. New captures
need visual review. See the [reference guide](References/RecipeLab/README.md) for limitations.
Outstanding work:

- Current-fixture visual and interaction passes on both platforms, including lower scroll content.
- Live VoiceOver announcements, focus order, and actions on both platforms.
- Actual selection gestures, complete adjacent link/custom-marker interaction, and enlarged system
  text on macOS; a fixture font-size override is not system accessibility verification.
- Rechecking previously observed macOS quote truncation and narrow-table clipping with the original
  failing content. Changing fixture wording does not establish a renderer fix.

Automated native exports, semantic trees, and successful compilation are not substitutes for these
running-app observations.
