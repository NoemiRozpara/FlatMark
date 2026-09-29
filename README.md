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

## Task-list accessibility

Without `taskToggleAction`, task-list rows are static content: their checked or unchecked
symbol and VoiceOver value communicate state, but they are not exposed as disabled controls.
When an action is supplied, each task is a native toggle, styled as a checkbox on macOS. Its
accessible label includes the task's nesting level, and the control exposes its state and action.
An interactive document that inherits `isEnabled == false` keeps those controls disabled.

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
| Paragraphs | Fully rendered | Native `Text`. [Basic block projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L9-L35). |
| ATX headings (`#`) | Fully rendered | Native heading text with level-specific font and header accessibility trait. [Basic block projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L9-L35). |
| Setext headings (`===` / `---`) | Fully rendered | Parsed as the same heading node as ATX headings and given the same native treatment. [Heading projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L252-L271). |
| Thematic breaks | Fully rendered | Native `Divider`. [Basic block projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L9-L35). |
| Indented code blocks | Rendered with documented policy | Code is rendered in a monospaced native block; the source indentation is not reproduced. [Indented-code projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L252-L271). |
| Fenced code blocks | Rendered with documented policy | Code is rendered in a monospaced native block; fence characters and the optional info string are omitted. [Basic block projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L9-L35). |
| HTML blocks | Rendered with documented policy | Displayed as literal, secondary-styled fallback text; HTML is never executed or fetched. [Raw-HTML fallback test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L219-L224). |
| Link reference definitions | Parsed but omitted | Definitions have no standalone output, but provide destinations for reference links. |
| Blank lines | Parsed but omitted | They delimit block structure and have no native view of their own. |
| Block quotes | Fully rendered | Nested native block list with a leading rule. [Basic block projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L9-L35). |
| List items | Fully rendered | Each item becomes a native row or an ordered child block within its list. [List projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L52-L70). |
| Bullet lists | Fully rendered | Native rows preserve list nesting through indentation. [List projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L52-L70). |
| Ordered lists, including start number | Fully rendered | Native rows retain their authored starting number. [List projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L52-L70). |
| List items with continuation blocks | Fully rendered | Paragraphs, quotes, code blocks, and nested lists following an item remain ordered child content. [Nested-container projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L73-L112). |
| Nested containers (quotes, lists, and blocks within list items) | Fully rendered | Containers are recursively projected; list rows use a flat rendering sequence with indentation. [Nested-container projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L73-L112). |
| GFM tables | Rendered with documented policy | Header and body cells render in a horizontally scrollable native grid. [Table projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L115-L133). |
| GFM table column alignment | Parsed but omitted | Alignment delimiters are parsed as table metadata but do not affect native cell alignment. |
| GFM task-list items | Fully rendered | Checked and unchecked markers render as task rows; supplying `taskToggleAction` makes the marker interactive. [Task-list projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L52-L70). |

### Inline constructs

| Construct | Status | Notes and semantic projection test |
| --- | --- | --- |
| Text, including punctuation | Fully rendered | Native attributed text. [Inline projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L227-L243). |
| Backslash escapes | Fully rendered | The parser resolves escapes before the text projection. [Inline projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L227-L243). |
| Character references (named, decimal, hexadecimal) | Fully rendered | The parser resolves references before the text projection. [Inline projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L227-L243). |
| Soft line breaks | Fully rendered | Projected as a newline in native text. [Break projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L227-L243). |
| Hard line breaks (two spaces or backslash) | Fully rendered | Projected as a newline in native text. [Break projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L227-L243). |
| Emphasis | Fully rendered | Native emphasized attributed run. [Inline projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L227-L243). |
| Strong emphasis | Fully rendered | Native strongly emphasized attributed run. [Inline projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L227-L243). |
| Nested emphasis and strong emphasis | Fully rendered | Both presentation intents are retained on the same run. [Inline projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L227-L243). |
| GFM strikethrough | Fully rendered | Native strikethrough attributed run. [Inline projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L227-L243). |
| Code spans | Fully rendered | Native code attributed run. [Inline projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L227-L243). |
| Inline links | Rendered with documented policy | Link labels are native attributed text. A destination becomes a tappable link only when Foundation accepts it as an absolute URL; titles are parsed but omitted. [Link projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L227-L243). |
| Full, collapsed, and shortcut reference links | Rendered with documented policy | Definitions resolve these forms; they use the same absolute-URL policy as inline links. [Link projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L227-L243). |
| CommonMark angle-bracket URI and email autolinks | Rendered with documented policy | Parsed as links and use the same absolute-URL policy. [Link projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L227-L243). |
| GFM extended autolinks (`www.` and bare email forms) | Unsupported | The parser is not configured with GFM's extended-autolink extension, so these forms remain text rather than link nodes. |
| Images | Rendered with documented policy | Rendered as `Image: <alt text> (<source>)`; FlatMark does not fetch or display image resources, and image titles are omitted. [Image projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L245-L249). |
| Inline raw HTML | Rendered with documented policy | Rendered as literal `HTML: <source>` text; HTML is never executed or fetched. [Fallback-content projection test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L186-L199). |

### Parsing and GitHub-web behaviors

| Item | Status | Notes |
| --- | --- | --- |
| LF, CRLF, and CR source line endings | Not applicable | They are normalized by Markdown parsing; line ending style is not a rendered construct or preserved source format. |
| GFM disallowed-raw-HTML tag filtering | Not applicable | FlatMark does not create an HTML DOM. Raw HTML is shown literally under the HTML policies above, so it has nothing to sanitize or execute. |
| GitHub sanitization and post-processing | Not applicable | FlatMark does not reproduce GitHub's repository-context links, issue/reference expansion, web UI, server-side transformations, or sanitization pipeline. |
| Parsed node types without a native structural view | Rendered with documented policy | FlatMark displays a labeled, readable fallback where possible rather than silently dropping the node. [Unsupported-node fallback test](Tests/FlatMarkTests/Rendering/TodoMarkdownProjectorTests.swift#L202-L216). |

No construct in this matrix is silently omitted: any omission is identified above as metadata, source normalization, or an explicit rendering policy.

## Deliberate non-goals

FlatMark is not:

- a Markdown editor and does not provide editing controls;
- a general Markdown serializer. Its only source mutation is changing the `[ ]` / `[x]` marker for an interacted-with task;
- an HTML renderer or browser;
- a fully conforming GitHub clone, including GitHub-specific post-processing such as GitHub’s web UI, repository-context link handling, issue/reference expansion, or other server-side enhancements.

If you need any of those behaviors, keep them in the part of your app that owns editing, serialization, or HTML handling.
