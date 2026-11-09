# Markdown support

[Usage and rendering policies](README.md) · [Testing](Tests/README.md)

FlatMark parses GitHub Flavored Markdown with swift-markdown, then projects the parsed document into
native SwiftUI views. This matrix covers every CommonMark block and inline construct plus GFM's table,
task-list, strikethrough, extended-autolink, and disallowed-raw-HTML extensions.

**Fully rendered** preserves Markdown meaning. **Rendered with documented policy** follows the Notes
column. **Parsed but omitted** supplies structure or metadata without separate output. **Unsupported**
is not projected as that construct. **Not applicable** describes source processing or GitHub-web behavior.

Paragraphs, headings, list text, and table cells render in noneditable, selectable `UITextView`
(iOS) or `NSTextView` (macOS), including inline image attachments and semantic system fonts. See
[layout and selection limits](README.md#layout-and-selection-limits) for the authoritative typography,
font-override, and selection contract.

### Block constructs

| Construct | Status | Notes |
| --- | --- | --- |
| Paragraphs | Fully rendered | Native selectable text with inline image attachments. |
| ATX headings (`#`) | Fully rendered | Semantic heading role by level, with the header accessibility trait. |
| Setext headings (`===` / `---`) | Fully rendered | Same heading node and treatment as ATX. |
| Thematic breaks | Fully rendered | Native `Divider`. |
| Indented code blocks | Rendered with documented policy | Monospaced native block; source indentation is not reproduced. |
| Fenced code blocks | Rendered with documented policy | Monospaced native block; fence characters and info string are omitted. |
| HTML blocks | Rendered with documented policy | `.literal`: inert parser raw HTML, no diagnostic label. `.omit`: removed with its layout slot. `.custom`: same raw HTML handed to a host-owned native replacement. Only built-in policies guarantee no HTML execution or fetching. |
| Link reference definitions | Parsed but omitted | No standalone output; they supply reference destinations. |
| Blank lines | Parsed but omitted | They delimit block structure. |
| Block quotes | Fully rendered | Nested native block list with a leading rule. |
| List items | Fully rendered | Native row, or ordered child block within its list. |
| Bullet lists | Fully rendered | Nesting preserved through indentation. |
| Ordered lists, including start number | Fully rendered | Authored starting number retained. |
| List items with continuation blocks | Fully rendered | Following paragraphs, quotes, code, and nested lists stay ordered child content. |
| Nested containers | Fully rendered | Containers recurse; list rows use a flat sequence with indentation. |
| GFM tables | Rendered with documented policy | Horizontally scrollable native grid; cells use native attributed text and headers keep native emphasis. |
| GFM table column alignment | Parsed but omitted | Alignment delimiters are parsed but do not change native cell alignment. |
| GFM task-list items | Fully rendered | Task rows; `taskToggleAction` makes an addressable marker interactive, and an unaddressable task stays static content that keeps its state. |

### Inline constructs

| Construct | Status | Notes |
| --- | --- | --- |
| Text, including punctuation | Fully rendered | Native attributed text. |
| Backslash escapes | Fully rendered | Resolved by the parser before projection. |
| Character references | Fully rendered | Resolved by the parser before projection. |
| Soft line breaks | Fully rendered | Newline in native text. |
| Hard line breaks (two spaces or backslash) | Rendered with documented policy | Newline in native text; consecutive-break snapshots record current output, not qualified break semantics. See [coverage](Tests/README.md#coverage). |
| Emphasis | Fully rendered | Native emphasized run. |
| Strong emphasis | Fully rendered | Native strongly emphasized run. |
| Nested emphasis and strong emphasis | Fully rendered | Both intents retained on the same run. |
| GFM strikethrough | Fully rendered | Native strikethrough run. |
| Code spans | Fully rendered | Native code run. |
| Inline links | Rendered with documented policy | Labels are native attributed text; absolute destinations become tappable, relative ones when `baseURL` resolves them. Titles are parsed but omitted. |
| Reference links (full, collapsed, shortcut) | Rendered with documented policy | Same absolute-or-`baseURL` policy as inline links. |
| CommonMark angle-bracket URI and email autolinks | Rendered with documented policy | Parsed as links with the same absolute-URL policy. |
| GFM extended autolinks (`www.`, bare email) | Unsupported | The extension is not enabled, so these stay text. |
| Images | Rendered with documented policy | Default is a network-free alt-text placeholder. Hosts supply an async loader returning `UIImage` or `NSImage`; relative sources use `baseURL`, and the image scheme policy applies before loading. Loaded images attach inline at intrinsic size or shrink to paragraph width; other phases show a photo, static hourglass, or warning icon with the policy-resolved label and no reserved raster space. Cancellation is not failure, and titles are omitted. macOS exports meaningful descriptions, destination-first image-link names, and phase wording; iOS attachment announcements can be generic. See [image accessibility limits](README.md#layout-and-selection-limits). |
| Inline raw HTML | Rendered with documented policy | `.literal`: inert source text that keeps enclosing Markdown styling and links. `.omit`: absent, with authored spaces and surrounding structure retained. `.custom`: each parser node contributes host-returned attributed text beside supported neighbors, inheriting enclosing intents and links per run where the host omits them, with explicit host values (including an empty intent set) winning on its run. Replacement links use the existing host navigation path. Typography and font-attribute rules follow the [layout contract](README.md#layout-and-selection-limits). |

### Parsing and GitHub-web behaviors

| Item | Status | Notes |
| --- | --- | --- |
| LF, CRLF, and CR line endings | Not applicable | Parsing normalizes rendered breaks; the retained source and task-toggle output preserve original line endings. |
| GFM disallowed-raw-HTML tag filtering | Not applicable | FlatMark builds no HTML DOM. Raw HTML is literal or omitted per `unsupportedContentPolicy`, and GitHub's filtering is not reproduced. Custom output is host-owned and may interpret its input. |
| GitHub sanitization and post-processing | Not applicable | No repository-context links, issue or reference expansion, web UI, server-side transforms, or sanitization pipeline. |
| Parsed nodes with no native structural view | Rendered with documented policy | `.literal`: the exact source slice the parser addressed, else readable descendant text, else empty text. `.omit`: the node is removed whole, not re-presented through descendants. `.custom`: that same string, including `""`, reaches a native replacement with no literal fallback. Known containers recurse under every policy. |

These statuses describe projection, not verified pixels or live accessibility; see
[verification limits](Tests/README.md#verification-status).
