# FlatMark

FlatMark is **a native SwiftUI GFM preview renderer with optional interactive task lists**.

It turns Markdown into native SwiftUI views for iOS 17+ and macOS 14+.

## Use

Add FlatMark as a Swift Package dependency, then render a Markdown string:

```swift
import FlatMark
import SwiftUI

struct ReadmePreview: View {
    let markdown: String

    var body: some View {
        FlatMarkView(markdown: markdown)
    }
}
```

To allow task-list checkboxes to change, provide `taskToggleAction`. The closure receives the complete updated source string; your app decides whether and where to persist it.

```swift
struct InteractivePreview: View {
    @State private var markdown = "- [ ] Review the pull request"

    var body: some View {
        FlatMarkView(markdown: markdown) { updatedMarkdown in
            markdown = updatedMarkdown
        }
    }
}
```

The toggle is source-preserving: only the selected marker's state character changes (`[ ]` ↔
`[x]`, always the lowercase `x`). LF, CRLF, standalone CR, and mixed line endings are retained as
written, and every other byte — Unicode included — stays identical. Each task marker carries the
editing address of its state byte in the unchanged Markdown snapshot that was projected.
`FlatMarkView` projects the same immutable source value captured by its toggle action, keeping
addresses and mutations paired with that snapshot rather than applying old coordinates to newer
Markdown. The internal toggle operation does not validate snapshot freshness; applying an address
to a different snapshot is unsupported and can toggle an unrelated marker rather than fail.
A task the parser could not give an address to renders as static content that keeps its checked
state and never invokes the closure.

The callback receives the complete updated source, not an address to apply to the host's current
source. Hosts that defer accepting or persisting callback results are responsible for ensuring an
older result does not overwrite newer Markdown.

## Images and relative URLs

FlatMark does not fetch images by default. Without an image loader, each Markdown image is a
native placeholder showing its alt text, or `Image` when the alt text is empty. This keeps the
default renderer deterministic and network-free.

Hosts can opt in by providing an asynchronous `FlatMarkImageLoader`. The host owns fetching,
decoding, authentication, caching, and any other image-pipeline policy; FlatMark only manages the
SwiftUI loading, success, failure, and cancellation states.

```swift
let imageLoaderID = UUID()
let imageLoader = FlatMarkImageLoader(configurationID: imageLoaderID) { url in
    try await imageService.image(for: url)
}

FlatMarkView(
    markdown: markdown,
    baseURL: URL(string: "https://example.com/docs/readme.md"),
    imageLoader: imageLoader
)
```

Keep the configuration ID stable when reconstructing an equivalent loader, including when a
SwiftUI parent redraws. Replace it only when the loader configuration changes and current image
requests should restart.

`baseURL` resolves relative link and image destinations with Foundation's standard URL rules.
Before an image URL reaches the loader, `FlatMarkImageURLPolicy.webOnly` accepts only `http` and
`https` schemes. Supply a policy with a different explicit `allowedSchemes` set when the host
supports another scheme. Rejected or unresolvable image sources use the native unavailable state
and never invoke the loader.

## Text selection around linked images

When a paragraph contains a linked image, FlatMark renders the text before and after it as
separate selectable text regions so the image remains an independently actionable link.
Selection is continuous within either text region, but cannot cross the linked image. Because
SwiftUI lays out each region as one view, an image following multiline text can move to the next
row even when the final internal text line has unused space; native inline text may fit it there.

## Task-list accessibility

Without `taskToggleAction`, task-list rows are static content: their checked or unchecked
symbol and VoiceOver value communicate state, but they are not exposed as disabled controls. A
task the parser gave no editing address to is static content the same way, even when an action is
supplied. When an action is supplied, each addressable task is a native toggle, styled as a
checkbox on macOS. Its accessible label includes the task's nesting level, and the control exposes
its state and action. An interactive document that inherits `isEnabled == false` keeps those
controls disabled.

### Manual VoiceOver checklist

Verify this on macOS and iPadOS with a document containing checked, unchecked, and nested tasks:

- With no `taskToggleAction`, VoiceOver announces each task's label, checked/unchecked state,
  and level without calling it a button, toggle, or disabled control.
- With `taskToggleAction`, VoiceOver announces the task label, its state, and a toggle action;
  activate it and confirm the action receives updated Markdown.
- Disable the surrounding document and confirm interactive tasks are announced as disabled while
  still identifying their label and state; read-only tasks remain static content.
- On macOS, move keyboard focus to an interactive task and press Space; on iPadOS, use a hardware
  keyboard to focus the task and activate it. Confirm only the intended task changes.
- Confirm nested tasks retain a distinct spoken level and visual indentation, and that state
  remains visually distinguishable by the symbol or control position rather than color alone.

## GFM support matrix

FlatMark uses [swift-markdown](https://github.com/swiftlang/swift-markdown) to parse the [GitHub Flavored Markdown (GFM) specification](https://github.github.com/gfm/), then projects the parsed document into native SwiftUI views. This matrix covers every CommonMark block and inline construct plus GFM's table, task-list, strikethrough, extended-autolink, and disallowed-raw-HTML extensions.

Status meanings:

- **Fully rendered** — projected as its Markdown meaning without an intentional loss of semantic content.
- **Rendered with documented policy** — visible in the preview, with the policy in the Notes column.
- **Parsed but omitted** — accepted because it supplies structure or metadata, but has no separate visible output.
- **Unsupported** — not projected as that construct.
- **Not applicable** — a source-processing or GitHub-web behavior, rather than a native-preview construct.

### Block constructs

| Construct | Status | Notes and semantic projection test |
| --- | --- | --- |
| Paragraphs | Fully rendered | Native `Text`. [Basic block projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L9-L36). |
| ATX headings (`#`) | Fully rendered | Native heading text with level-specific font and header accessibility trait. [Basic block projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L9-L36). |
| Setext headings (`===` / `---`) | Fully rendered | Parsed as the same heading node as ATX headings and given the same native treatment. [Heading projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L379-L392). |
| Thematic breaks | Fully rendered | Native `Divider`. [Basic block projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L9-L36). |
| Indented code blocks | Rendered with documented policy | Code is rendered in a monospaced native block; the source indentation is not reproduced. [Indented-code projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L379-L392). |
| Fenced code blocks | Rendered with documented policy | Code is rendered in a monospaced native block; fence characters and the optional info string are omitted. [Basic block projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L9-L36). |
| HTML blocks | Rendered with documented policy | Displayed as literal, secondary-styled fallback text; HTML is never executed or fetched. [Raw-HTML fallback test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L302-L307). |
| Link reference definitions | Parsed but omitted | Definitions have no standalone output, but provide destinations for reference links. |
| Blank lines | Parsed but omitted | They delimit block structure and have no native view of their own. |
| Block quotes | Fully rendered | Nested native block list with a leading rule. [Basic block projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L9-L36). |
| List items | Fully rendered | Each item becomes a native row or an ordered child block within its list. [List projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L133-L151). |
| Bullet lists | Fully rendered | Native rows preserve list nesting through indentation. [List projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L133-L151). |
| Ordered lists, including start number | Fully rendered | Native rows retain their authored starting number. [List projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L133-L151). |
| List items with continuation blocks | Fully rendered | Paragraphs, quotes, code blocks, and nested lists following an item remain ordered child content. [Nested-container projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L154-L193). |
| Nested containers (quotes, lists, and blocks within list items) | Fully rendered | Containers are recursively projected; list rows use a flat rendering sequence with indentation. [Nested-container projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L154-L193). |
| GFM tables | Rendered with documented policy | Header and body cells render in a horizontally scrollable native grid. [Table projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L196-L214). |
| GFM table column alignment | Parsed but omitted | Alignment delimiters are parsed as table metadata but do not affect native cell alignment. |
| GFM task-list items | Fully rendered | Checked and unchecked markers render as task rows; supplying `taskToggleAction` makes an addressable marker interactive, and an unaddressable task stays static content that keeps its state. [Task-list projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L133-L151). |

### Inline constructs

| Construct | Status | Notes and semantic projection test |
| --- | --- | --- |
| Text, including punctuation | Fully rendered | Native attributed text. [Inline projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L310-L325). |
| Backslash escapes | Fully rendered | The parser resolves escapes before the text projection. [Inline projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L310-L325). |
| Character references (named, decimal, hexadecimal) | Fully rendered | The parser resolves references before the text projection. [Inline projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L310-L325). |
| Soft line breaks | Fully rendered | Projected as a newline in native text. [Break projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L310-L325). |
| Hard line breaks (two spaces or backslash) | Fully rendered | Projected as a newline in native text. [Break projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L310-L325). |
| Emphasis | Fully rendered | Native emphasized attributed run. [Inline projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L310-L325). |
| Strong emphasis | Fully rendered | Native strongly emphasized attributed run. [Inline projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L310-L325). |
| Nested emphasis and strong emphasis | Fully rendered | Both presentation intents are retained on the same run. [Inline projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L310-L325). |
| GFM strikethrough | Fully rendered | Native strikethrough attributed run. [Inline projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L310-L325). |
| Code spans | Fully rendered | Native code attributed run. [Inline projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L310-L325). |
| Inline links | Rendered with documented policy | Link labels are native attributed text. Absolute destinations become tappable links; relative destinations do so when `baseURL` can resolve them. Titles are parsed but omitted. [Link projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L310-L325). |
| Full, collapsed, and shortcut reference links | Rendered with documented policy | Definitions resolve these forms; they use the same absolute-or-`baseURL` policy as inline links. [Link projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L310-L325). |
| CommonMark angle-bracket URI and email autolinks | Rendered with documented policy | Parsed as links and use the same absolute-URL policy. [Link projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L310-L325). |
| GFM extended autolinks (`www.` and bare email forms) | Unsupported | The parser is not configured with GFM's extended-autolink extension, so these forms remain text rather than link nodes. |
| Images | Rendered with documented policy | The network-free default is a native alt-text placeholder. Hosts can supply an async loader; relative sources use `baseURL`, and the image scheme policy is applied before loading. Loading failures use a native unavailable placeholder, cancellation is not presented as failure, and titles are omitted. [Image loading tests](Tests/FlatMarkTests/Rendering/FlatMarkImageLoadingTests.swift). |
| Inline raw HTML | Rendered with documented policy | Rendered as literal `HTML: <source>` text; HTML is never executed or fetched. [Fallback-content projection test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L253-L288). |

### Parsing and GitHub-web behaviors

| Item | Status | Notes |
| --- | --- | --- |
| LF, CRLF, and CR source line endings | Not applicable | They are normalized by Markdown parsing; line ending style is not a rendered construct or preserved source format. |
| GFM disallowed-raw-HTML tag filtering | Not applicable | FlatMark does not create an HTML DOM. Raw HTML is shown literally under the HTML policies above, so it has nothing to sanitize or execute. |
| GitHub sanitization and post-processing | Not applicable | FlatMark does not reproduce GitHub's repository-context links, issue/reference expansion, web UI, server-side transformations, or sanitization pipeline. |
| Parsed node types without a native structural view | Rendered with documented policy | FlatMark displays a labeled, readable fallback where possible rather than silently dropping the node. [Unsupported-node fallback test](Tests/FlatMarkTests/Rendering/FlatMarkProjectorTests.swift#L279-L299). |

No construct in this matrix is silently omitted: any omission is identified above as metadata, source normalization, or an explicit rendering policy.

## Deliberate non-goals

FlatMark is not:

- a Markdown editor and does not provide editing controls;
- a general Markdown serializer. Its only source mutation is the selected task marker's state byte (`[ ]` / `[x]`) for an interacted-with task, preserving every other byte;
- an HTML renderer or browser;
- a fully conforming GitHub clone, including GitHub-specific post-processing such as GitHub’s web UI, repository-context link handling, issue/reference expansion, or other server-side enhancements.

If you need any of those behaviors, keep them in the part of your app that owns editing, serialization, or HTML handling.
