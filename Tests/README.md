# FlatMark runtime verification

Run package checks using the repository's [build and test policy](../../docs/BUILD_AND_TEST.md#packages).
Automated checks do not replace the platform and accessibility observations below.

## Backend-free fixture setup

One fixture covers every policy observation:
[FlatMarkCustomFixture.swift](FlatMarkTests/Rendering/FlatMarkCustomFixture.swift) provides the
Literal/Custom/Omit picker, editable replacement label, host-button and empty-output switches,
enlarged text (`accessibility2`), RTL control, a **Load omission sample** button, and counters for
image loads, host activations, link activations, and task updates. Its document includes inline and
block HTML, strong text, headings, linked text, nested quotes, a task row, table cells, multiline
text, an explicit break, and an unaffected local image.

To run it, temporarily copy it together with `FlatMarkRecordedImageLoads.swift` (the shared image
recorder) into the existing `ToDoo` app target and replace the app entry point with the following.
This bypasses session restoration and needs no login, backend data, or network access. Restore the
normal app entry afterwards; do not retain either app-target change.

```swift
import SwiftUI

@main
struct ToDooApp: App {
    @State private var model: FlatMarkCustomFixtureModel

    init() {
        let model = FlatMarkCustomFixtureModel()
        model.policyKind = .custom
        model.showsButtons = true
        model.replacementLabel = "Go"
        model.enlargedText = true // repeat with false; also try rightToLeft/showsEmpty
        _model = State(initialValue: model)
    }

    var body: some Scene {
        WindowGroup {
            ScrollView {
                FlatMarkCustomFixture(model: model)
            }
        }
    }
}
```

Initialize the model before passing it to `State(initialValue:)` for a deterministic initial state.

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
