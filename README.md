# FlatMark

A native SwiftUI GitHub Flavored Markdown preview renderer for iOS 17+ and macOS 15+, with optional
interactive task lists. Parsing uses [swift-markdown](https://github.com/swiftlang/swift-markdown).

[Markdown support](SUPPORT.md) · [Demo](Demo/README.md) · [Testing and playground](Tests/README.md) · [Benchmarks](Benchmarks/README.md)

## Requirements

- Xcode 26.0+ / Swift 6.2
- iOS 17 / macOS 15
- [swift-markdown](https://github.com/swiftlang/swift-markdown) 0.8.x

FlatMark previously supported macOS 14. Apple stopped patching it: the last Sonoma security release was
14.8.9 on 2026-08-06, and Apple now ships macOS security updates only for macOS 15, 26, and 27
([Apple security releases](https://support.apple.com/en-us/100100)). FlatMark's required toolchain
cannot run on macOS 14 either: Xcode 26 needs macOS 15.6 or later
([Xcode 26 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-26-release-notes)).
FlatMark was therefore never executed on macOS 14, and no supported toolchain can test it there.

The floor stops at 15 rather than rising to 26 because macOS 26 was the last release to support Intel
Macs and macOS 27 requires Apple silicon. macOS 15 is the newest system every Mac that Apple still
patches can run. See [AI-docs/BUILD_AND_TEST.md](AI-docs/BUILD_AND_TEST.md) for the resulting
verification boundary.

## Demo

Open [Demo/FlatMarkDemo.xcodeproj](Demo/FlatMarkDemo.xcodeproj), select **FlatMarkDemo-iOS** or
**FlatMarkDemo-macOS**, and Run. See [demo setup](Demo/README.md) for signing and capture presets.
The demo and shared fixtures are not built or embedded in the `FlatMark` package product.

## Usage

```swift
import FlatMark
import SwiftUI

struct MarkdownPreview: View {
    let markdown: String

    var body: some View {
        FlatMarkView(markdown: markdown)
    }
}
```

### Interactive tasks

`taskToggleAction` receives the complete updated source. The host owns persistence:

```swift
FlatMarkView(
    markdown: markdown,
    taskToggleAction: { markdown = $0 }
)
```

Only the tapped marker's state byte changes (`[ ]` ↔ `[x]`, lowercase `x`); every other byte,
including Unicode and line endings, is preserved. Editing addresses belong to the rendered snapshot,
not to a newer host string, and task updates always derive from that snapshot's source. A host that
defers accepting a callback result must stop an older result from overwriting newer content. Tasks
without a parser-provided address stay static and never invoke the callback.

Without a callback, tasks expose label, state, and nesting level as static accessible content.
Addressable tasks expose a native toggle action, and inherited `.disabled(...)` disables editing.
Live VoiceOver and keyboard behavior still need platform verification.

### Custom task markers

Both initializers accept a passive checked-state drawing:

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

Do not add a button, toggle, or gesture to the drawing: FlatMark owns interaction, hit testing, and
accessibility, and the marker is not a separate accessibility element. Custom markers apply to
interactive, read-only, and nested tasks. The default square marker is shared across platforms.

## Reusing a document

`FlatMarkView(markdown:)` constructs a document on each initialization. Retain a snapshot to skip
repeated parsing and projection:

```swift
let document = FlatMarkDocument(
    markdown: markdown,
    baseURL: URL(string: "https://example.com/docs/")
)

FlatMarkView(document: document)
```

Construction inputs are the source and `baseURL`; build a new document when either changes, and
equality compares those inputs. Image loading, unsupported-content policy, link and task callbacks,
and marker appearance are render-time settings that can change without reparsing. Construction is
synchronous and can be expensive for large documents; see the
[benchmarks](Benchmarks/README.md). Retained reuse avoids construction, not layout or rendering.

Lexical `@username` mentions always render in bold, with no links or actions. Detection scans each
Markdown text node independently and excludes code, link labels, and image descriptions. Handles use
ASCII letters, digits, and underscores, with optional internal dots or hyphens. No user lookup happens.

## Links and document bases

Foundation resolves parsed destinations against `baseURL`, preserving file and directory semantics.
For example, `intro` resolves under `/docs/` when the base ends in `/docs/page`, but under
`/docs/page/` when the base ends in `/docs/page/`. Destinations are not manually decoded or
re-encoded, and network-path references can change hosts.

Only nonempty, resolved absolute URLs are actionable. Empty, invalid, or unresolved destinations keep
their labels and formatting without navigation semantics, for inline and reference links, supported
autolinks, linked images, tables, and nested blocks.

There is **no scheme allowlist or same-origin restriction**. HTTP(S), `mailto`, file, and custom schemes
can reach the inherited SwiftUI `openURL` action. Rendering never opens a URL; activation attempts to open,
with no guarantee of success and no fallback UI. Fragment links open normally rather than scrolling inside
the document.

Route or reject activation with a synchronous callback:

```swift
FlatMarkView(
    markdown: markdown,
    linkActivationAction: { url in
        guard url.scheme == "https" else { return .rejected }
        return .useDefaultOpening
    }
)
```

- `.handled`: the host took the URL; no default opening follows.
- `.rejected`: no opening and no fallback UI.
- `.useDefaultOpening`: delegate once to the inherited `openURL` action.

The callback runs on activation only, never during projection or rendering. A rejected link can still
look actionable before activation. Navigation permission is independent of image-fetching policy.

## Images

By default, images are network-free alt-text placeholders (`Image` when alt text is empty). Provide an
async loader that returns a native image — `UIImage` on iOS, `NSImage` on macOS (`NativeImage`):

```swift
let loaderID = UUID() // Retain this ID while the loader configuration is unchanged.
let loader = FlatMarkImageLoader(configurationID: loaderID) { url in
    try await imageService.image(for: url)
}

FlatMarkView(markdown: markdown, imageLoader: loader)
```

The host owns fetching, decoding, authentication, and caching. FlatMark draws the returned image at
its intrinsic size, scales larger images down to the paragraph's proposed width, and manages loading,
success, failure, and cancellation. Change the configuration ID only when requests should restart.

Relative image sources use `baseURL`. The default `FlatMarkImageURLPolicy.webOnly` permits HTTP(S)
only; custom policies can allow other schemes. Rejected or unresolved sources never reach the loader,
and allowing a linked image to navigate does not authorize fetching its source.

## Unsupported content

Raw HTML and other nodes with no native renderer follow `unsupportedContentPolicy`:

| Policy | Behavior |
| --- | --- |
| `.literal` (default) | Inert source text; HTML uses parser-provided raw HTML |
| `.omit` | Removes unsupported nodes, plus paragraphs, headings, and blockquotes the removal empties |
| `.custom` | Replaces each unsupported node with attributed text, with an optional native block-view override |

Omission follows parser nodes, not HTML element boundaries: `before <u>important</u> after` keeps
`important`, while a whole HTML block can disappear. Authored spaces, supported structures, and
pre-existing empty constructs remain. Image descriptions follow the same text policy. Switching
policies preserves surviving node IDs, task addresses, and unaffected image-loading state; state
inside removed views is not preserved.

```swift
FlatMarkView(
    markdown: markdown,
    unsupportedContentPolicy: .omit
)
```

The inline closure is required and returns `AttributedString`; for text-only replacements use
`.custom { source in AttributedString(source) }`. Inline nodes always use it. Block nodes use the
optional block override when supplied, and otherwise render the inline output as native text. Both
closures receive the same extracted source as `.literal`: raw HTML, otherwise a valid original source
slice, readable descendants, or `""`. Empty extraction still reaches the selected closure. Opening and
closing tags are separate nodes, not paired elements. Known containers recurse; escaped tags, code, and
ordinary text invoke neither closure.

Replacements keep their structural position and ambient environment, and FlatMark adds no literal
fallback or minimum-size box. Block controls stay independently actionable beside tasks and supported
links. For inline replacements:

- They compose with supported neighbors as native text and contribute their wording to paragraph
  accessibility text.
- They use semantic UIKit or AppKit typography for the role — paragraph, heading, list text, or table
  cell — and keep explicit native font and color attributes per run. SwiftUI `Font` attributes use
  semantic native typography instead, and host-supplied fixed fonts stay host-owned.
- Each run inherits enclosing Markdown presentation intents and links when the host omits them. An
  explicit host intent replaces the enclosing intent, including an empty intent set that suppresses
  inheritance. A host link overrides the enclosing destination on its run; a missing link inherits it.
- Replacement links use the same `linkActivationAction` and inherited `openURL` path as supported links.

Empty attributed output and block overrides returning `AnyView(EmptyView())` do not imply recursive
omission: parent spacing may remain. No spaces are synthesized. These are presentation closures;
invocation counts are not lifecycle guarantees.

Built-in policies never execute HTML or fetch HTML resources. **Custom output is host-owned**,
including interpretation, sanitization, navigation, and resource access. FlatMark is not an HTML
sanitizer.

## Layout and selection limits
Paragraphs, headings, list text, and table cells compose supported and custom text in a noneditable,
selectable `UITextView` on iOS or `NSTextView` on macOS.

- Each uses system-preferred semantic typography for its role — body, heading 1–3
  (title/title2/title3), heading 4–6 (headline), or bold table header — with no fixed point size.
  Inline emphasis, strong text, mentions, and inline code derive their traits from the resolved role
  font.
- Each measures at every finite positive offered width, with no fixed reading width; other proposals
  use native sizing behavior. Content, typography, and direction changes refresh layout.
- Paragraph writing direction and leading/trailing alignment stay separate.
- iOS responds to Dynamic Type; macOS uses AppKit's preferred semantic fonts without iOS scaling.
  Ambient SwiftUI font, foreground style, and tint are not styling contracts for this path.
- Selection may reset on any update, including styling and measurement. Selection preservation and
  cross-block selection are not promised.

On both platforms, images share native attributed storage with surrounding text. Loaded images use
inline attachments at intrinsic size, shrinking proportionally to the paragraph width; other phases use
an inline photo, static hourglass, or warning icon with the policy-resolved label. Long non-success
labels wrap without a reserved raster box, and empty alt text uses `Image`. iOS keeps native attachment
accessibility. macOS supplies policy-resolved descriptions and phase wording in the paragraph label,
and destination-first image-link names while preserving ordinary native links. Image-link actions use
the same host navigation path. Live VoiceOver speech and focus behavior still need running-platform
qualification, and exported names are not live speech evidence. Generic attachment announcements remain
an iOS limitation.

Tables scroll horizontally, and parsed column alignment does not change native cell alignment.

See the [support matrix](SUPPORT.md) for construct-specific behavior and the
[testing guide](Tests/README.md) for verification limits.

## Scope

FlatMark is a preview renderer, not a Markdown editor, general serializer, browser, HTML sanitizer, or
GitHub web clone. Its only source mutation is an interacted task marker. Repository-context links, issue
expansion, server-side transformations, and other GitHub-specific post-processing are out of scope.
