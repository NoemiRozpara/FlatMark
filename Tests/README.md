# FlatMark runtime verification

Run package checks using the repository's [build and test policy](../../docs/BUILD_AND_TEST.md#packages).
Automated checks do not replace the platform and accessibility observations below.

## Recipe Lab playground (#228)

The host opens **Recipe Lab**: one compact focaccia recipe, also mounted by the policy-transition
tests. It combines ingredients, nested checked/unchecked tasks, links, one linked illustration,
quotes, a table, code, ordered steps, an explicit break, and inline/block HTML. The former prep,
clipping, mixed-content, and task-marker documents are consolidated into this source.
Mention and omission examples are woven into the recipe itself. **Notebook rendering** switches the
main recipe between string and retained-document initialization. There are no duplicate recipe
copies or separate regression documents on the page.
Exploration controls and **Capture presets & diagnostics** follow the recipe. See the
[reference matrix, reproduction commands, observed defects, and outstanding VoiceOver checks](References/RecipeLab/README.md).
Existing screenshots and runtime observations predate this content reduction; they have not been
refreshed or re-verified for it. No snapshot dependency was added.

**2026-10-28 (single-page merge, before content reduction):** the page menu, the settings sheet, the capture-preset disclosure,
the two regression-sample buttons, and the **Use full available width** switch were removed; the host
no longer takes `--mentions`, `--document`, or `--task-markers`. All sixteen recipe references were
refreshed for the merged page. `mobilebuildmcp swift-package test --package-path FlatMark` and
`sweetpad -C FlatMark test` (155 tests in 19 suites) passed, and the iOS and macOS hosts built and
ran. Runtime observation of the merged page is recorded in the
[reference guide](References/RecipeLab/README.md); the settings switches still could not be operated
by the automation lane, and VoiceOver remains outstanding.

The **Disable all recipe controls** switch and `FlatMarkCustomFixtureModel.disablesTasks` were also
deleted. Setting `.disabled(true)` on the rendered document only suppressed `Button` and `Link`
activation — both created by `FlatMarkListView.swift:138` and `FlatMarkDocumentView.swift:263, 277,
353` — which is platform behavior, and FlatMark itself never reads `isEnabled`. The matching
`marker-disabled` mode in `TaskInteractionTestHost` and its `"disabled"` case in
`FlatMarkTaskMarkerTests` went with it. The automatic check that host views at both inline and
whole-block positions receive the ancestor's enabled state is retained: that one is a fact about the
renderer's own composition, not about `Button`.

## Backend-free fixture setup

One shared fixture covers every observation:
[FlatMarkCustomFixture.swift](FlatMarkFixtures/FlatMarkCustomFixture.swift) renders the shared recipe
on one page and provides the Literal/Custom/Omit picker, editable replacement label, host-button and
empty-output switches, enlarged text (`accessibility2`), RTL control, and counters for image loads,
host activations, link activations, and task updates. The recipe has one Markdown source and one
retained snapshot; the automated suite mounts the same view with either initializer. These files live in the `FlatMarkFixtures` target, shared by the host and the automated
suite, so an observation can never use code the tests do not also compile.

Documents are capped at a 240-point reading column on iOS. macOS has no cap: resize the window to
change the reading width.

To run it, boot an iPhone simulator and execute `scripts/run-fixture-host.sh` (default `ios`) from
the repository root. It builds `FlatMarkFixtureHost` for the simulator, wraps and installs the app,
and launches it. The entry point presets the `daylight` capture: Custom with host buttons, the label
“Baker’s tip”, and standard text. Change the controls directly on the page. Pass `--capture generous`
after the platform argument to start with enlarged text.

The historical checklists below use former control labels. Current equivalents are **Larger recipe
text**, **Right-to-left recipe layout**, **Use custom checkmarks**, **Allow ticking tasks**,
**Make replacements tappable**, and **Replace with nothing**.
Literal / Custom / Omit are presented as **Show HTML / Replace tags / Hide HTML**. No login,
backend data, network access, or host-app code is involved. Pass `macos` to run the same fixture
as a desktop window (`scripts/run-fixture-host.sh macos`); the app bundle is left under `/tmp` so it
survives the script exiting. The host initializes the model before passing it to
`State(initialValue:)` for a deterministic initial state.

## Mention rendering (#200)

The shared [recipe](FlatMarkFixtures/FlatMarkRecipeSample.swift) includes mention examples in prose,
emphasis, a task, a table, code, and a link label. Run `scripts/run-fixture-host.sh`; **Detect mentions**
in Appearance controls the recipe and defaults to on.

Toggle **Detect mentions** to compare enabled/disabled rendering. Check that `@ja*ne*` bolds only
`@ja`, whole-token italic/strikethrough styles are preserved, and code and link labels stay
unchanged. Each Markdown text node is scanned independently: `*email*@example.com` bolds
`@example.com`, while ordinary `email@example.com` stays unbolded. Also inspect list/table content, wrapping, text selection, and
ordinary link activation. Mentions themselves are not links.

`FlatMarkMentionTests` mounts the public `FlatMarkView` and observes native text, font traits,
strikethrough, and link attributes. It covers grammar and disabled behavior, formatting-terminated
tokens and independently checked text-node boundaries, code/link exclusions (including empty and
unresolved links), headings/lists/table cells, whitespace, and surrounding-text order. These macOS-gated checks
exercise real rendering, not an exported grammar or a copied serialization test corpus.

**Observed on macOS:** a fresh mention fixture capture showed formatting-terminated bolding
(`@ja*ne*` bolds only `@ja`), whole-token bolding with retained emphasis/strikethrough, unbolded
plain-email/code/link-label text, list/table mentions, and natural wrapping. The capture also
confirmed the accepted bolding of `@example.com` after italic `email`.
**Outstanding:** iOS runtime observation, live selection gestures, VoiceOver, and interactive
link/toggle checks for this fixture. Mounted font/link assertions do not establish those behaviors.

## Reusing one parsed document (#223)

The main recipe supports both public initializers. In **Notebook rendering**, enable **Use retained
document** to switch the recipe’s initializer without changing its content.

- **Re-render without editing** raises **Refresh requests** without replacing the retained document.
  This counts user requests, not renderer evaluations or parser calls.
- **Add a tasting note** appends a task to the shared source and replaces the snapshot.
- **Detect mentions** replaces the snapshot with the new projection input.
- Toggling any task updates only its checkbox and increments **Task updates** once.
- Switch between initializers: wording, styles, resolved links, table cells, and tasks should agree.
  Automated tests compare separate mounted views; the playground shows only one recipe.

`FlatMarkDocumentTests` checks source/input equality, retained inputs, and defaults through the
public API. `FlatMarkDocumentRenderingTests` checks expected selectable wording and attribute
parity between the document- and string-backed initializers. The no-reparse guarantee is established
structurally: `FlatMarkView.body` reads the retained projection, and the only production call to
`FlatMarkRenderProjector.project(markdown:)` is in `FlatMarkDocument.init`. The string-backed
comparison constructs its own document whenever that view is rebuilt.

**Previously observed on iOS 27 simulator (iPhone 18 Pro), before fixture simplification:**
semantic-tree captures showed matching wording and checkbox values in all three presentations.
Task toggles updated the corresponding marker in every copy and returned the complete source;
refresh requests preserved the content, source edits added a task, and mention detection could be
switched. The fixture's former counters measured host bookkeeping, not parser calls.

**Outstanding:** the simplified fixture has not been re-observed in a running app. The previous
semantic tree did not establish typeface; bolding rests on the mounted suite. VoiceOver and a macOS
runtime pass for this fixture are also outstanding.

## Mounted native-content lane (#225)

The normal package test command runs these checks; no executable host or extra setup is needed:

```sh
mobilebuildmcp swift-package test --package-path FlatMark
```

`MountedView.visibleText` / `visibleAttributedText` read the mounted renderer's **native
selection backing**. After creating `NSApplication.shared` and laying out the view, the reader
walks AppKit descendants in native order, invokes `selectAll:` on selection-capable views, and
uses public `NSServicesMenuRequestor` APIs to export RTF to a unique pasteboard. It decodes that
RTF as `NSAttributedString`, concatenating regions without synthetic separators and without
also reading a requestor's descendants. Each temporary pasteboard is released; the user's
general pasteboard is never used. Reading changes the selection in these disposable test views.

**Requirements:** verified on macOS 27.0.1 with the repository's pinned Xcode 27 RC toolchain.
The content must support native selection: `FlatMarkView` already enables it; a bare SwiftUI
`Text` probe needs `.textSelection(.enabled)`. No accessibility trust, enhanced-accessibility
setting, permission prompt, or separate application event loop is required. The APIs are public,
but SwiftUI's descendant capabilities and traversal order are not a documented inspection
contract. Requalify this lane after toolchain/OS changes.

**Guarantees:** selectable wording and exported bold, italic, strikethrough, and link attributes
for the tested corpus. All existing mention/custom-host assertions remain. Missing selection
capability or failed RTF export throws immediately rather than polling and returning `""`;
a live lane missing requested wording throws a separate bounded-timeout error.

**Limits:** arbitrary nonselectable host controls, glyph visibility, clipping, opacity, geometry,
selection gestures, and exact on-screen typeface identity are not established by RTF export.
This is automated native-content observation, not manual visual verification.

Do not replace this reader with an accessibility-tree reader: ordinary FlatMark inline content
has an independent `accessibilityRepresentation`. That proxy can remain correct when visible
rendering is broken. Qualification of this selection reader included temporary changes to
`inlineText` only, leaving `accessibilityText` intact: substituting `"BROKEN-RENDERER"` failed
content checks, and applying bold/italic/strikethrough to the visible text failed attribute checks.
Both mutations were restored before the full package run.

## Manual checklist

Use the recipe on the page. Its empty nested quotes disappear with **Hide HTML**, while the
supported tasting note survives. Deliberately empty task labels, ordered rows, and table cells are
kept in the independent oracle in `FlatMarkOmissionLiveUpdateTests`, not the readable notebook.
The historical omission observations below refer to that oracle. On iOS and macOS:

- **Policy transitions:** drive Literal → Custom → Omit → Literal → Omit → Custom → Literal
  without editing the Markdown. Nested output must refresh, tasks keep their addresses, and the
  image counter must not increase. With `.omit`, unsupported content and the blocks that only
  carried it vanish, and the gap matches the same document typed without them — not a blank line
  or extra empty region. Nested quotes collapse with their rule; a quote holding a list, table, or
  divider keeps that content.
- **Replacement labels:** change the label while Custom remains selected. Opening/closing tags are
  separate replacements, not paired HTML elements.
- **Empty output:** with the switch on, tags disappear without fallback, placeholder, or synthetic
  space; ordinary parent spacing may remain. This does not request `.omit` collapse.
- **Native controls:** with **Host buttons**, activate a replacement inside linked Markdown, then
  its neighboring supported link separately; the first must increment only **actions**, the second
  only **links**. A button sharing a line with selectable text must not have its taps
  swallowed by the text's hit area. Toggle the task whose tags were omitted: only its marker
  changes. Omitted task rows read with VoiceOver must say nothing about the tags.
- **Links:** supported Markdown links, including one carrying a custom inline, open their Markdown
  destination exactly once; HTML `href` values, including `javascript:`, never reach the handler.
- **Images:** a supported Markdown image beside omitted HTML loads exactly once and is not
  restarted by a policy change; `<img src=...>`, `<script>`, `<iframe>`, and `onclick` never reach
  the image loader or any handler.
- **Layout:** inspect iOS at its fixed 240 points, and macOS at several window widths, with normal
  and enlarged text, including headings, table cells,
  nested content, explicit line breaks, and mixed images. Runs may move as a whole or wrap inside
  their own views. Smoke-check RTL.
- **Selection:** long-press/select supported text and drag across the native regions, recording
  what actually happens; continuous selection across mixed runs/host views is not promised, so
  fragmentation is an observation, not necessarily a bug.
- **Accessibility:** host buttons must be reachable once and operable, not hidden by a text-only
  proxy; task controls and host controls remain separate accessible siblings. Check VoiceOver
  announcements/actions.

The omission sample additionally confirms markers stay `7.`/`8.`, both table columns and the empty
body cell remain, and activating the empty-label task marks only it and increments the task counter
once.

## Task-marker appearance (#224)

In the shared fixture, use the **Bake along** checklist in the recipe. Use **Use custom
checkmarks** to switch the marker appearance and **Allow ticking tasks** to independently select
interactive / read-only. Host marker is a passive square-plus-offset-checkmark drawing,
not another toggle. The recipe includes checked/unchecked and nested tasks, a neighboring tin-note
link, and independently actionable custom content.

Manual checklist on **both iOS and macOS**:

- Compare default and host markers with Task editing on and off. iOS and macOS use the same
  drawn default marker and control appearance. Every nested task uses the selected appearance and
  correct checked state.
- Toggle an unchecked host marker: only that marker changes, and **tasks** increases once.
  With Task editing off there is no task action. Re-enable and toggle again.
- Activate **Details** separately from its marker and a **Go** replacement separately from its
  marker. Only **links**, **actions**, or **tasks**, respectively, should increase.
- Inspect normal and Large text at iOS's fixed 240-point column (on macOS, at several window
  widths), then RTL. Markers must follow
  the leading edge without overlapping wording or hiding the independently actionable content.
- With VoiceOver, check distinguishable task names, checked state, and a single control per task
  (no accessible host drawing); static markers announce label/state but offer no toggle action.
  Confirm links and custom buttons remain independently reachable.

**Automated:** `FlatMarkTaskMarkerTests` mounts both public initializers with interactive/read-only
nested checked/unchecked tasks, observes host builder states, and checks unchanged selectable
wording. Its native event-loop host checks source-preserving custom-marker dispatch and read-only
no-dispatch by clicking the measured marker center. These checks do not
establish a minimum hit-target size. Existing task, navigation, and unsupported-content tests remain in the full package run.
The task interaction host now uses one geometry-recording passive marker in every mode, rather
than relying on native macOS NSButton storage; callback and independent-action checks remain. These are behavioral observations, not private style-storage tests.

**Observed 2026-10-27, before unifying the platform toggle styles:** the fixture built and ran on iPhone 18 Pro (iOS 27 simulator) and macOS.
iOS screenshots showed custom checked/unchecked nested markers at Large text, normal text, and
read-only RTL, plus built-in read-only markers. Runtime snapshots exposed distinguishable task
switches and checked values without separate drawing elements; activating Nested pending changed
its value and incremented tasks once. Turning Task editing off removed task switches while leaving
the host drawing visible. On macOS, screenshots compared native built-in interactive checkboxes
with host interactive markers, and host read-only RTL. The Large text fixture switch was on for
the macOS captures; unlike iOS, it did not visibly enlarge macOS text. A host task activation and
a separate custom-content activation incremented only their respective counters.

Fixture builds used the existing `scripts/run-fixture-host.sh` packaging lane; package tests ran
via MobileBuildMCP. Simulator observations used MobileBuildMCP snapshots/screenshots and taps;
macOS observations used System Events and screen capture.

**After unifying the toggle styles:** fresh iOS and macOS fixture builds succeeded. A macOS
screenshot showed the drawn green checked / secondary unchecked default markers, including nested
tasks, instead of native checkboxes. The iOS runtime snapshot retained distinguishable checked and
unchecked task switches with the Default marker selected. The full package suite passed with the
geometry-based interaction host.

**Outstanding:** live VoiceOver announcements/rotor actions on both platforms, enlarged system
text on macOS, and a complete per-platform interaction matrix (especially disabled iOS controls —
that control has since been removed, see the #228 note above —
and actual link activation beside a custom marker). The macOS Details accessibility press did not
increment the link counter, so link activation is not recorded as verified by that attempt.
The unchanged link implementation and existing automated navigation checks are not a substitute
for completing that live check.

## What the automated checks assert

Automated rendering checks assert **which elements exist**, not how they are laid out. Three
oracles cover it:

- **Inventory** — `visibleDocument(_:policy:)` describes every block that survives `.literal` or
  `.omit`, in order and nesting, with the wording each carries. It deliberately answers nothing
  about `.custom`: what a host view draws is not a render-tree value.
- **Attribution** — `customHosts(in:)` lists every node `.custom` hands to a host view, addressed
  by render-node ID and component index within its span, so "the replacement stayed inside the
  quote" is a tree fact rather than an x coordinate.
- **Live behavior** — what the mounted view did: the payloads the host closure received, the label
  each presentation showed, image-loader counts, task updates, and a mounted view that still lays
  out something (`fittingSize != .zero`). Payload assertions are sets, because a document presented
  more than once hands the same node over repeatedly; ordering a single span can show comes from
  the tree.

The helpers live in `FlatMarkRenderObservation.swift`. Model-level cases need neither AppKit nor a
window and build for iOS as well (`FlatMark/Package.swift` declares iOS 17+ / macOS 14+). Only
host-closure dispatch, the label a presentation showed, and mounted visibility stay in the
macOS-gated mounted suite.

Automated checks do not establish that `.omit` leaves no layout slot, that a host view inherits a
heading's font, that an empty host view leaves no gap or fallback box, or where two replacements
sit relative to one another. Mounted visibility catches a view that collapsed but not text that is
present and unreadable. The invariant that `FlatMarkInlineFlowLayout.sizeThatFits` never reports
more width than the layout places has no automated guard — it survives only as the comment in
`FlatMarkInlineFlowLayout.swift`; `LayoutSubviews` cannot be constructed outside a hosting context.

## Observations recorded and outstanding

**Observed iOS 27 simulator (iPhone 18 Pro):** the temporary app-entry fixture was built and run
without backend data. Captures were inspected at 240 points with normal and `accessibility2` text,
including heading/table/nested/multiline/image cases; RTL was smoke-checked. Whole-run wrapping was
visible; no overlapping or clipped controls were seen. The semantic tree exposed native replacement
buttons and a separate task switch. Tapping an inline button inside a Markdown link incremented
only **actions**; neighboring linked text incremented only **links**. Policy switching and a label
edit left image loads at one. These captures caught a selectable-text hit shape intercepting
adjacent button taps, which was fixed by bounding each text hit shape.

**Outstanding:** live VoiceOver announcements and rotor actions on both platforms, actual selection
gestures, and a complete interactive macOS fixture/capture pass — the macOS fixture compiled and
launched, but that lane was not completed. Every directed policy edge is asserted in the macOS
fixture tests; independent per-state assertions of the full iOS matrix remain outstanding.
Automated mounted and native-host checks are not a substitute for these observations, and recording
them is new verification, not a continuation of the iOS captures above.

Complete the outstanding observations recording the fresh build/runtime, screenshots or semantic
trees, control activations, and any unavailable accessibility lane.
