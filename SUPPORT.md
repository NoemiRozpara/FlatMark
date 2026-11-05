# Markdown support

[Usage and rendering policies](README.md) · [Testing](Tests/README.md)

FlatMark uses swift-markdown to parse the GitHub Flavored Markdown (GFM) specification, then projects the parsed document into native SwiftUI views. This matrix covers every CommonMark block and inline construct plus GFM's table, task-list, strikethrough, extended-autolink, and disallowed-raw-HTML extensions.

Status meanings:

- **Fully rendered:** projected as its Markdown meaning without an intentional loss of semantic content.
- **Rendered with documented policy:** visible in the preview, with the policy in the Notes column.
- **Parsed but omitted:** accepted because it supplies structure or metadata, but has no separate visible output.
- **Unsupported:** not projected as that construct.
- **Not applicable:** a source-processing or GitHub-web behavior, rather than a native-preview construct.

Paragraphs, headings, list text, and table cells use noneditable, selectable `UITextView` controls
on iOS, including inline image attachments. Image-free values use `NSTextView` on macOS. System semantic fonts resolve body and heading roles;
table headers use bold body text. Explicit host native fonts and colors win per run. Fixed host
fonts remain host-owned. iOS follows Dynamic Type; macOS uses AppKit's preferred sizes, not iOS
scaling. Arbitrary ambient SwiftUI font, foreground style, and tint are not styling contracts.
Selection may reset on content, styling, or measurement updates; cross-block selection is not
promised. On macOS, values containing Markdown images retain the SwiftUI flow renderer in every phase.
See [layout and selection limits](README.md#layout-and-selection-limits).

### Block constructs

| Construct | Status | Notes |
| --- | --- | --- |
| Paragraphs | Fully rendered | Native selectable text; iOS uses `UITextView` with inline image attachments; macOS image-free content uses `NSTextView`. |
| ATX headings (`#`) | Fully rendered | Native heading text in a semantic level role (levels 1–3 title/title2/title3, 4–6 headline) with header accessibility trait. |
| Setext headings (`===` / `---`) | Fully rendered | Parsed as the same heading node as ATX headings and given the same native treatment. |
| Thematic breaks | Fully rendered | Native `Divider`. |
| Indented code blocks | Rendered with documented policy | Code is rendered in a monospaced native block; the source indentation is not reproduced. |
| Fenced code blocks | Rendered with documented policy | Code is rendered in a monospaced native block; fence characters and the optional info string are omitted. |
| HTML blocks | Rendered with documented policy | Inert literal text under `.literal`, using the parser's raw HTML unchanged with no diagnostic label; removed with its layout slot under `.omit`. `.custom` supplies the same raw HTML to a host-owned native replacement; only the built-in policies guarantee no HTML execution or fetching. |
| Link reference definitions | Parsed but omitted | Definitions have no standalone output, but provide destinations for reference links. |
| Blank lines | Parsed but omitted | They delimit block structure and have no native view of their own. |
| Block quotes | Fully rendered | Nested native block list with a leading rule. |
| List items | Fully rendered | Each item becomes a native row or an ordered child block within its list. |
| Bullet lists | Fully rendered | Native rows preserve list nesting through indentation. |
| Ordered lists, including start number | Fully rendered | Native rows retain their authored starting number. |
| List items with continuation blocks | Fully rendered | Paragraphs, quotes, code blocks, and nested lists following an item remain ordered child content. |
| Nested containers (quotes, lists, and blocks within list items) | Fully rendered | Containers are recursively projected; list rows use a flat rendering sequence with indentation. |
| GFM tables | Rendered with documented policy | Header and body cells render in a horizontally scrollable native grid; iOS cells and macOS image-free cells use native attributed text and headers keep native emphasis. |
| GFM table column alignment | Parsed but omitted | Alignment delimiters are parsed as table metadata but do not affect native cell alignment. |
| GFM task-list items | Fully rendered | Checked and unchecked markers render as task rows; supplying `taskToggleAction` makes an addressable marker interactive, and an unaddressable task stays static content that keeps its state. |

### Inline constructs

| Construct | Status | Notes |
| --- | --- | --- |
| Text, including punctuation | Fully rendered | Native attributed text. |
| Backslash escapes | Fully rendered | The parser resolves escapes before the text projection. |
| Character references (named, decimal, hexadecimal) | Fully rendered | The parser resolves references before the text projection. |
| Soft line breaks | Fully rendered | Projected as a newline in native text. |
| Hard line breaks (two spaces or backslash) | Fully rendered | Projected as a newline in native text. |
| Emphasis | Fully rendered | Native emphasized attributed run. |
| Strong emphasis | Fully rendered | Native strongly emphasized attributed run. |
| Nested emphasis and strong emphasis | Fully rendered | Both presentation intents are retained on the same run. |
| GFM strikethrough | Fully rendered | Native strikethrough attributed run. |
| Code spans | Fully rendered | Native code attributed run. |
| Inline links | Rendered with documented policy | Link labels are native attributed text. Absolute destinations become tappable links; relative destinations do so when `baseURL` can resolve them. Titles are parsed but omitted. |
| Full, collapsed, and shortcut reference links | Rendered with documented policy | Definitions resolve these forms; they use the same absolute-or-`baseURL` policy as inline links. |
| CommonMark angle-bracket URI and email autolinks | Rendered with documented policy | Parsed as links and use the same absolute-URL policy. |
| GFM extended autolinks (`www.` and bare email forms) | Unsupported | The parser is not configured with GFM's extended-autolink extension, so these forms remain text rather than link nodes. |
| Images | Rendered with documented policy | The network-free default is a native alt-text placeholder. Hosts can supply an async loader returning `UIImage` (iOS) or `NSImage` (macOS); relative sources use `baseURL`, and the image scheme policy is applied before loading. Loading failures use a native unavailable placeholder, cancellation is not presented as failure, and titles are omitted. Native accessibility announcements may be generic; spoken alt text, destinations, and phase wording are not guaranteed. See [image accessibility limits](README.md#layout-and-selection-limits). |
| Inline raw HTML | Rendered with documented policy | Inert literal source text under `.literal`, keeping enclosing Markdown styling and links; absent under `.omit`, with authored spaces and surrounding structure retained. Under `.custom`, each parser node contributes host-returned attributed text beside supported neighbors, inheriting enclosing Markdown intents and links per run where the host omits them. Explicit host intents (including an empty set) replace the default; host links override the enclosing destination. Replacement links use the existing host navigation path. iOS paragraphs, headings, list text, and table cells, and their image-free macOS equivalents, use semantic UIKit or AppKit typography for their role, preserve explicit native `UIFont`/`NSFont` and foreground-color attributes, and do not inherit arbitrary ambient SwiftUI styles. SwiftUI `Font` attributes use semantic native typography in that path. On macOS, values containing a Markdown image keep ambient SwiftUI styling. |

### Parsing and GitHub-web behaviors

| Item | Status | Notes |
| --- | --- | --- |
| LF, CRLF, and CR source line endings | Not applicable | They are normalized by Markdown parsing; line ending style is not a rendered construct or preserved source format. |
| GFM disallowed-raw-HTML tag filtering | Not applicable | FlatMark does not create an HTML DOM. Raw HTML is shown literally or omitted according to `unsupportedContentPolicy`, and GitHub's own filtering is not reproduced. Custom attributed text and block views are host-owned and may interpret their input. GitHub's tag filtering and sanitization are post-parse stages, not this native projection policy. |
| GitHub sanitization and post-processing | Not applicable | FlatMark does not reproduce GitHub's repository-context links, issue/reference expansion, web UI, server-side transformations, or sanitization pipeline. |
| Parsed node types without a native structural view | Rendered with documented policy | Under `.literal`: the exact source slice the parser addressed, else readable descendant text, else empty text. Under `.omit` the node is removed whole rather than re-presented through its descendants. Under `.custom`, the same extracted string, including `""`, reaches a native replacement with no literal fallback. Known containers recurse under every policy. |

No construct in this matrix is silently omitted: any omission is identified above as metadata, source normalization, or an explicit rendering policy.
