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
