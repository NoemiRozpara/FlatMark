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

## What “GFM support” means here

FlatMark parses Markdown with `[swift-markdown](https://github.com/swiftlang/swift-markdown)` and renders the GFM features it supports as native SwiftUI content. That currently includes headings, paragraphs, block quotes, fenced and indented code blocks, ordered and unordered lists, task lists, thematic breaks, tables, emphasis, strong emphasis, strikethrough, inline code, links, and line breaks.

“GFM support” does not mean full GFM conformance or a pixel-accurate GitHub rendering. The output follows FlatMark’s own native-view layout and rendering policies:

- Images are shown as readable text containing their alt text and source URL. FlatMark does not fetch or display image resources.
- Raw inline HTML is displayed as literal text; raw HTML blocks are retained as a literal fallback. FlatMark never executes HTML, JavaScript, CSS, or embedded content.
- Markdown nodes that FlatMark does not render structurally are shown as readable fallback content where possible.

## Deliberate non-goals

FlatMark is not:

- a Markdown editor and does not provide editing controls;
- a general Markdown serializer. Its only source mutation is changing the `[ ]` / `[x]` marker for an interacted-with task;
- an HTML renderer or browser;
- a fully conforming GitHub clone, including GitHub-specific post-processing such as GitHub’s web UI, repository-context link handling, issue/reference expansion, or other server-side enhancements.

If you need any of those behaviors, keep them in the part of your app that owns editing, serialization, or HTML handling.
