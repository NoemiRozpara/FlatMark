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
`FlatMarkView` applies each address to the Markdown snapshot of the `FlatMarkDocument` it renders,
keeping addresses and mutations paired with that snapshot rather than applying old coordinates to
newer Markdown. The internal toggle operation does not validate snapshot freshness; applying an address
to a different snapshot is unsupported and can toggle an unrelated marker rather than fail.
A task the parser could not give an address to renders as static content that keeps its checked
state and never invokes the closure.

The callback receives the complete updated source, not an address to apply to the host's current
source. Hosts that defer accepting or persisting callback results are responsible for ensuring an
older result does not overwrite newer Markdown.

### Host task-marker appearance

Both initializers accept `taskMarker`, independently of `taskToggleAction`:

```swift
FlatMarkView(
    markdown: markdown,
    taskToggleAction: { markdown = $0 },
    taskMarker: .custom { isChecked in
        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(.purple)
    }
)
```

The builder receives only checked state. Supply a **passive drawing**, not another button, toggle,
or gesture. FlatMark owns the control, accessibility label and checked state, and minimum hit target;
the drawing does not become a separate accessibility element. It inherits SwiftUI environment values
such as `isEnabled`. Omitting the callback still renders read-only markers with the same drawing;
`.disabled(...)` still disables editing when a callback is supplied.

The `.default` appearance uses the same square marker and control appearance on iOS and macOS.
A custom drawing replaces the marker for interactive, read-only, and nested tasks. No ToDoo theme
or interaction dependency is required.

## Reusing one parsed value

`FlatMarkView(markdown:)` parses when the host builds the view, so a preview whose parent
re-creates it on every render parses again each time. When the same Markdown is presented more than
once — a composer preview that mounts two copies of the same view, a live preview that re-renders
while its host re-evaluates, or a long document on a screen SwiftUI redraws — build one
`FlatMarkDocument` and render that instead:

```swift
let document = FlatMarkDocument(
    markdown: todo.description,
    baseURL: URL(string: "https://example.com/docs/readme.md"),
    detectMentions: true
)

struct DescriptionPreview: View {
    let document: FlatMarkDocument

    var body: some View {
        FlatMarkView(document: document)
    }
}
```

Parsing and projection happen in `FlatMarkDocument.init(markdown:baseURL:detectMentions:)` and
nowhere else. `FlatMarkView(document:)` never calls the parser or the projector while `body` is
evaluated, so every render of one retained value reuses the same projected content. Retain a single
value per snapshot: building a new document for each render reproduces the string-based behavior.
Two documents are equal when they carry the same source and the same projection inputs, which is
what makes comparing them useful.

`baseURL` and `detectMentions` are projection inputs, not render-time inputs: relative
destinations are resolved and mention spans projected when the document is built, so changing
either means building a new document. `imageLoader`, `imageURLPolicy`,
`unsupportedContentPolicy`, `linkActivationAction`, `taskToggleAction`, and `taskMarker` remain render-time host
authorities on `FlatMarkView(document:)`: switching them re-renders the retained content without
re-parsing.

A retained document also pins task editing. `FlatMarkView(document:)` applies a task's editing
address to `document.markdown` — the same value the address was projected from — rather than to a
string captured separately when the view was created.

## Links and document bases

FlatMark passes swift-markdown's parsed destinations to Foundation's standard URL resolver.
A nonempty destination becomes actionable only when Foundation constructs an absolute result
(with a scheme). HTTP(S), `mailto`, file URLs, and custom schemes are eligible; navigation has
no scheme allowlist, handler-availability probe, or same-origin restriction.

Supply `baseURL` to resolve path-relative, parent-path, root-relative, query-only, fragment-only,
and network-path destinations. Foundation preserves file/directory base semantics: `intro`
against `https://example.com/docs/page` resolves to `https://example.com/docs/intro`, whereas
against `https://example.com/docs/page/` it resolves to `https://example.com/docs/page/intro`.
Network-path references can change hosts. Percent-encoded destinations are not manually decoded
or re-encoded. Bases need not use HTTP(S), but a still-relative result is never actionable.
An independently absolute destination remains usable even with a relative base.

Empty destinations, Foundation construction failures, and unresolved relative results retain
their labels and inline formatting without link accessibility semantics. Linked images retain
their image or existing placeholder without a surrounding navigation action. This contract is
shared by inline and reference links, parser-supported autolinks, tables, and nested blocks.

Activation uses native SwiftUI URL opening by default, including for non-HTTP schemes. Rendering
never opens a URL. Opening is an attempt, not a guarantee of an installed handler, trusted content,
or success; FlatMark adds no failure UI or alternate opening route. Resolved fragment references
open normally rather than scrolling within the document. Available handlers and opening success
vary by platform.

### Host link activation

Provide the optional synchronous `linkActivationAction` to route or reject a resolved absolute
URL at activation time. It is shared by native attributed text, independently actionable images,
tables, nested blocks, and accessibility activation. Projection and rendering never call it;
inert destinations never call it either.

```swift
FlatMarkView(
    markdown: markdown,
    baseURL: URL(string: "https://example.com/docs/readme.md"),
    linkActivationAction: { url in
        if url.scheme == "myapp" {
            router.navigate(to: url) // Host-owned synchronous navigation.
            return .handled
        }
        if url.scheme == "blocked" {
            return .rejected
        }
        return .useDefaultOpening
    }
)
```

- `.handled`: the host handled navigation; no default opening follows.
- `.rejected`: no opening occurs, with no fallback or error UI.
- `.useDefaultOpening`: delegate exactly once to the inherited SwiftUI `openURL` action,
  including any opener supplied by the host with `.environment(\.openURL, ...)`.

Omitting the callback preserves default navigation. The callback is not an asynchronous approval,
pre-render eligibility check, or handler probe. Rejected links may retain native actionable
appearance and accessibility semantics before activation. FlatMark intentionally performs no
navigation scheme filtering; hosts can reject custom schemes in this callback. This decision does
not grant permission to fetch an image: image sources still require the independent image policy
and loader below.

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
and never invoke the loader. Image-fetching permission is separate from navigation: a linked image
can navigate to any resolved absolute scheme, even when its image source is rejected by the image
policy. Allowing navigation does not authorize image fetching.

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

## Unsupported content

`unsupportedContentPolicy` controls raw HTML and other parser nodes without
a native renderer:

```swift
FlatMarkView(markdown: markdown) // .literal by default
FlatMarkView(markdown: markdown, unsupportedContentPolicy: .omit)
```

- **`.literal`** displays inert text: HTML uses the parser's raw HTML;
  other unsupported nodes use their original source slice, falling back
  to readable descendants or empty text.
- **`.omit`** removes the unsupported node without replacement text,
  spaces, placeholders, or accessibility wording. Paragraphs, headings,
  and recursively empty blockquotes emptied by omission also lose their
  layout slots and quote rules.
- **`.custom`** replaces each unsupported inline or block node with a host-owned native view,
  including nested quotes, headings, lists/task rows, and table cells.

Omission follows parser boundaries, not HTML element boundaries.
`before <u>important</u> after` becomes `before important after`, while
an HTML block such as `<div>hide</div>` disappears whole. Authored spaces
and breaks remain unchanged; escaped tags, code, and ordinary text keep
their Markdown meaning.

Supported structure remains, including list markers and numbering,
task controls, table rows/columns and cell padding, images, code blocks,
and dividers. Pre-existing empty constructs are not globally removed.
Unsupported wording in image descriptions follows the text policy: literal under `.literal`,
absent under `.omit`/`.custom`; image descriptions are accessibility metadata, not view positions.

Switching policies on unchanged Markdown preserves surviving node IDs, task editing addresses,
and unaffected image-loading state, including images in task rows with unsupported inline nodes.
Those rows keep their task control and inline content as siblings under every policy, so switching
policies does not replace the image-owning inline view. State inside removed views is not preserved.

Neither built-in policy interprets HTML attributes, fetches HTML resources, or
executes HTML. Supported Markdown links and images retain their normal
navigation and loading policies. Omission is not sanitization or browser
rendering.

### Custom native replacements

`.custom(render: (String) -> AnyView)` is a presentation closure, not an event callback:

```swift
FlatMarkView(
    markdown: markdown,
    unsupportedContentPolicy: .custom { source in
        AnyView(Button("Inspect") { inspect(source) })
    }
)
```

Each unsupported inline or block node supplies the same extracted string as `.literal`:
HTML supplies parser `rawHTML` unchanged (including trailing newlines); unknown nodes use valid
UTF-8 original-source coordinates, then readable descendants, then `""`. Empty extraction still
reaches the closure, with no diagnostic wording. Tags are not paired into synthetic elements:
`before <u>important</u> after` dispatches separate `<u>` and `</u>` arguments, with supported
`important` between their replacements. Known containers recurse; escaped tags, code, and
parser-classified ordinary text never invoke the closure.

The native result occupies the original structural position with its ambient environment,
interaction, and accessibility. FlatMark adds no literal fallback, diagnostic, link wrapper,
secondary styling, border, placeholder, or minimum-size box. `AnyView(EmptyView())` is allowed;
FlatMark does not inspect erased views for emptiness. Ordinary parent-stack spacing may remain:
use `.omit` for recursive shell/gap collapse.

Inline replacements reuse the native mixed image/text flow in source order, including its RTL
layout behavior. Host views inherit ambient SwiftUI styles, including heading fonts. Inline
presentation intents on adjacent attributed text (such as strong emphasis) are not copied onto
opaque host views, and explicit host styles are not overridden. An enclosing Markdown link is
never wrapped around a custom view or installed as its control action; supported neighboring
text retains its own link/emphasis attributes. Host controls retain their native accessibility,
not a duplicate or hiding text-only proxy. Task controls remain separate operable siblings.

No spaces are synthesized: `a<u></u>b` with erased empty replacements shows `ab`. FlatMark does
not introspect `AnyView` to infer omission or collapse its containing paragraph/heading/quote.
Wrapping is run-based, not character-level typesetting: a supported text run may move as a
whole, and a long run may wrap inside its own native view. Selection remains available for
supported text but can be fragmented across runs/views; continuous selection across arbitrary
views is not promised. See the runtime guide for platform observations and outstanding checks.

Custom output is host-owned: interpretation, sanitization, resource fetching, and execution are
the host's responsibility, not guaranteed inert or sanitized. SwiftUI may reevaluate presentation;
invocation counts are not lifecycle guarantees.

See the [runtime verification guide](Tests/README.md) for the manual checklist
and backend-free fixture setup with policy switching, tasks, and load counters.

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
| HTML blocks | Rendered with documented policy | Inert literal text under `.literal`, using the parser's raw HTML unchanged with no diagnostic label; removed with its layout slot under `.omit`. `.custom` supplies the same raw HTML to a host-owned native replacement; only the built-in policies guarantee no HTML execution or fetching. [Literal HTML-block test](Tests/FlatMarkTests/Rendering/FlatMarkUnsupportedContentTests.swift), [omission layout test](Tests/FlatMarkTests/Rendering/FlatMarkOmittedContentTests.swift). |
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
| Inline raw HTML | Rendered with documented policy | Inert literal source text under `.literal`, keeping enclosing Markdown styling and links; absent under `.omit`, with authored spaces and surrounding structure retained. Under `.custom`, each parser node is replaced at its inline position by a host-owned native view, without inheriting an enclosing Markdown link action. [Custom replacement tests](Tests/FlatMarkTests/Rendering/FlatMarkCustomUnsupportedContentTests.swift). [Literal inline-HTML tests](Tests/FlatMarkTests/Rendering/FlatMarkUnsupportedContentTests.swift), [omission tests](Tests/FlatMarkTests/Rendering/FlatMarkOmittedContentTests.swift). |

### Parsing and GitHub-web behaviors

| Item | Status | Notes |
| --- | --- | --- |
| LF, CRLF, and CR source line endings | Not applicable | They are normalized by Markdown parsing; line ending style is not a rendered construct or preserved source format. |
| GFM disallowed-raw-HTML tag filtering | Not applicable | FlatMark does not create an HTML DOM. Raw HTML is shown literally or omitted according to `unsupportedContentPolicy`, and GitHub's own filtering is not reproduced. Custom inline/block views are host-owned and may interpret their input. GitHub's tag filtering and sanitization are post-parse stages, not this native projection policy. |
| GitHub sanitization and post-processing | Not applicable | FlatMark does not reproduce GitHub's repository-context links, issue/reference expansion, web UI, server-side transformations, or sanitization pipeline. |
| Parsed node types without a native structural view | Rendered with documented policy | Under `.literal`: the exact source slice the parser addressed, else readable descendant text, else empty text. Under `.omit` the node is removed whole rather than re-presented through its descendants. Under `.custom`, the same extracted string, including `""`, reaches a native replacement with no literal fallback. Known containers recurse under every policy. [Extraction-contract tests](Tests/FlatMarkTests/Rendering/FlatMarkUnsupportedContentTests.swift). |

No construct in this matrix is silently omitted: any omission is identified above as metadata, source normalization, or an explicit rendering policy.

## Native navigation tests

On macOS, the package's Swift Testing navigation tests build and launch
[`FlatMarkNavigationTestHost`](Tests/FlatMarkNavigationTestHost/NavigationTestHost.swift)
as an executable dependency. Each case gets its own AppKit application event loop and
hosts the public `FlatMarkView`. Local mouse events activate rendered text and image
links; tests inspect recorded callback arguments and inherited-opener calls rather
than invoking FlatMark's internal dispatcher.

The host uses hidden windows, does not post global input, and needs no Accessibility
permission. Its controlled opener rejects every platform opening attempt, so tests
never launch browsers or arbitrary scheme handlers. A completed activation report is
required in addition to a successful process exit, and each host has a bounded timeout.
These checks cover macOS activation, not iOS interaction or successful external opening.
Run them with the normal package checks in the repository's
[build and test policy](../docs/BUILD_AND_TEST.md#packages).

## Deliberate non-goals

FlatMark is not:

- a Markdown editor and does not provide editing controls;
- a general Markdown serializer. Its only source mutation is the selected task marker's state byte (`[ ]` / `[x]`) for an interacted-with task, preserving every other byte;
- an HTML renderer or browser;
- an HTML sanitizer or attribute interpreter. Built-in [`unsupportedContentPolicy`](#unsupported-content)
  paths show inert literal text or omit it; custom inline/block views belong to the host, including
  any interpretation, sanitization, resource fetching, navigation, or execution they perform;
- a fully conforming GitHub clone, including GitHub-specific post-processing such as GitHub’s web UI, repository-context link handling, issue/reference expansion, or other server-side enhancements.

If you need any of those behaviors, keep them in the part of your app that owns editing, serialization, or HTML handling.
