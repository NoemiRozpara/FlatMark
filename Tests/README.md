# FlatMark runtime verification

Run package checks using the repository's [build and test policy](../../docs/BUILD_AND_TEST.md#packages).
Automated checks do not replace the platform and accessibility observations below.

## Backend-free fixture setup

One fixture covers every policy observation:
[FlatMarkCustomFixture.swift](FlatMarkFixtures/FlatMarkCustomFixture.swift) provides the
Literal/Custom/Omit picker, editable replacement label, host-button and empty-output switches,
enlarged text (`accessibility2`), RTL control, a **Load omission sample** button, and counters for
image loads, host activations, link activations, and task updates. Its document includes inline and
block HTML, strong text, headings, linked text, nested quotes, a task row, table cells, multiline
text, an explicit break, and an unaffected local image. These files live in the `FlatMarkFixtures`
target, shared by the host and the automated suite, so an observation can never use code the tests
do not also compile.

To run it, boot an iPhone simulator and execute `scripts/run-fixture-host.sh` (default `ios`) from
the repository root. It builds `FlatMarkFixtureHost` for the simulator, wraps and installs the app,
and launches it. The entry point presets Custom with host buttons, the label "Go", and enlarged
text; switch them with the fixture's own controls (also try `rightToLeft`/`showsEmpty`). No login,
backend data, network access, or host-app code is involved. Pass `macos` to run the same fixture
as a desktop window (`scripts/run-fixture-host.sh macos`); the app bundle is left under `/tmp` so it
survives the script exiting. The host initializes the model before passing it to
`State(initialValue:)` for a deterministic initial state.

## Mention rendering (#200)

The backend-free [mention fixture](FlatMarkFixtures/FlatMarkMentionFixture.swift) is selected by
launching `FlatMarkFixtureHost` with `--mentions`. For example, from the repository root on macOS:

```sh
mobilebuildmcp swift-package run --json '{"packagePath":"FlatMark","executableName":"FlatMarkFixtureHost","arguments":["--mentions"],"background":true}'
```

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

Use the document above, plus **Load omission sample** for the omission cases. On iOS and macOS:

- **Policy transitions:** drive Literal → Custom → Omit → Literal → Omit → Custom → Literal
  without editing the Markdown. Nested output must refresh, tasks keep their addresses, and the
  image counter must stay at one. With `.omit`, unsupported content and the blocks that only
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
- **Layout:** inspect at 240 points with normal and enlarged text, including headings, table cells,
  nested content, explicit line breaks, and mixed images. Runs may move as a whole or wrap inside
  their own views. Smoke-check RTL.
- **Selection:** long-press/select supported text and drag across the native regions, recording
  what actually happens; continuous selection across mixed runs/host views is not promised, so
  fragmentation is an observation, not necessarily a bug.
- **Accessibility:** host buttons must be reachable once and operable, not hidden by a text-only
  proxy; task controls and host controls remain separate accessible siblings. Check VoiceOver
  announcements/actions and inherited environment (e.g. disabled state).

The omission sample additionally confirms markers stay `7.`/`8.`, both table columns and the empty
body cell remain, and activating the empty-label task marks only it and increments the task counter
once.

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
