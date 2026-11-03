# FlatMark

A native SwiftUI GitHub Flavored Markdown preview renderer for iOS 17+ and macOS 14+,
with optional interactive task lists. Parsing uses [swift-markdown](https://github.com/swiftlang/swift-markdown).

[Markdown support](SUPPORT.md) · [Demo](Demo/README.md) · [Testing and playground](Tests/README.md) · [Benchmarks](Benchmarks/README.md)

## Requirements

- Xcode 26.0+ / Swift 6.2
- iOS 17 / macOS 14
- [swift-markdown](https://github.com/swiftlang/swift-markdown) 0.8.x

## Demo

After cloning the repository, open [Demo/FlatMarkDemo.xcodeproj](Demo/FlatMarkDemo.xcodeproj),
select **FlatMarkDemo-iOS** (an iOS simulator) or **FlatMarkDemo-macOS** (My Mac), and press Run.

See [demo setup](Demo/README.md) for capture presets and device-signing instructions.
The demo and shared fixtures are not built or embedded when consuming the `FlatMark` package product.

## Usage

Add the FlatMark package to the project and import the library:

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

Provide `taskToggleAction` to receive the complete updated source. The host owns persistence:

```swift
struct InteractivePreview: View {
    @State private var markdown = "- [ ] Review the pull request"

    var body: some View {
        FlatMarkView(
            markdown: markdown,
            taskToggleAction: { markdown = $0 }
        )
    }
}
```

Only the selected marker's state byte changes (`[ ]` ↔ `[x]`, lowercase `x`); all other bytes,
including Unicode and line endings, are preserved. Editing addresses belong to the rendered
snapshot, not a newer host string. Hosts that defer accepting callback results must prevent an
older result from overwriting newer content. Tasks without a parser-provided editing address
remain static and never invoke the callback.

Without a callback, tasks expose their label, state, and nesting level as static accessible content.
Addressable interactive tasks expose a native toggle action; inherited `.disabled(...)` disables
editing. Live VoiceOver and keyboard behavior still require platform verification.

### Custom task markers

Both view initializers accept a passive checked-state drawing:

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

Do not add a button, toggle, or gesture to the drawing. FlatMark owns interaction, hit testing,
and accessibility; the marker is not a separate accessibility element. Custom markers apply to
interactive, read-only, and nested tasks. The default square marker is shared across platforms.

## Reusing a document

`FlatMarkView(markdown:)` constructs a document on each initialization. Retain a snapshot to avoid
repeated parsing and projection:

```swift
let document = FlatMarkDocument(
    markdown: markdown,
    baseURL: URL(string: "https://example.com/docs/"),
    detectMentions: true
)

FlatMarkView(document: document)
```

Construct a new document when the source, `baseURL`, or `detectMentions` changes. Equality compares
those inputs. Image loading, unsupported-content policy, link/task callbacks, and marker appearance
remain render-time settings and can change without reparsing. Task updates always use
`document.markdown`, keeping source coordinates paired with their snapshot.

Construction is synchronous and can be expensive for large documents. See the
[desktop and physical-device benchmarks](Benchmarks/README.md); retained reuse avoids construction,
not layout or rendering.

## Links and document bases

Foundation resolves parsed destinations against `baseURL`, preserving file/directory semantics.
For example, `intro` resolves under `/docs/` with a base ending in `/docs/page`, but under
`/docs/page/` with a base ending in `/docs/page/`. Network-path references can change hosts.
Destinations are not manually decoded or re-encoded.

Only nonempty, resolved absolute URLs are actionable. Empty, invalid, or unresolved destinations
retain their labels and formatting without navigation semantics. This applies to inline/reference
links, supported autolinks, linked images, tables, and nested blocks.

Navigation has **no scheme allowlist or same-origin restriction**. HTTP(S), `mailto`, file, and
custom schemes can reach the inherited SwiftUI `openURL` action. Rendering never opens URLs;
activation attempts opening without guaranteeing success or providing fallback UI. Fragment links
open normally rather than scrolling inside the document.

Use a synchronous callback to route or reject activation:

```swift
FlatMarkView(
    markdown: markdown,
    linkActivationAction: { url in
        guard url.scheme == "https" else { return .rejected }
        return .useDefaultOpening
    }
)
```

- `.handled`: the host handled the URL; no default opening follows.
- `.rejected`: no opening or fallback UI.
- `.useDefaultOpening`: delegate once to the inherited `openURL` action.

The callback runs only on activation, not during projection or rendering. Rejected links can still
appear actionable before activation. Navigation permission is independent of image-fetching policy.

## Images

By default, images are network-free alt-text placeholders (`Image` when alt text is empty).
Provide an asynchronous loader that returns a native image: `UIImage` on iOS, `NSImage` on macOS
(`NativeImage`).

```swift
let loaderID = UUID() // Retain this ID while the loader configuration is unchanged.
let loader = FlatMarkImageLoader(configurationID: loaderID) { url in
    try await imageService.image(for: url) // UIImage on iOS, NSImage on macOS.
}

FlatMarkView(markdown: markdown, imageLoader: loader)
```

The host owns fetching, decoding, authentication, and caching. FlatMark draws the returned image at
its intrinsic size and scales larger images down to the paragraph's proposed width. FlatMark also
manages loading, success, failure, and cancellation states. Change the configuration ID only when
requests should restart.

Relative image sources use `baseURL`. The default `FlatMarkImageURLPolicy.webOnly` permits only
HTTP(S); custom policies can allow other schemes. Rejected or unresolved sources never reach the
loader. Allowing a linked image to navigate does not authorize fetching its image source.

## Unsupported content

Raw HTML and other nodes without a native renderer follow `unsupportedContentPolicy`:

| Policy | Behavior |
| --- | --- |
| `.literal` (default) | Inert source text; HTML uses parser-provided raw HTML |
| `.omit` | Remove unsupported nodes and recursively emptied paragraphs, headings, and blockquotes |
| `.custom` | Replace each unsupported node with attributed text, with an optional native block-view override |

Omission follows parser nodes, not HTML element boundaries: `before <u>important</u> after`
retains `important`, while a whole HTML block may disappear. Authored spaces, supported structures,
and pre-existing empty constructs remain. Image descriptions follow the same text policy.
Switching policies preserves surviving node IDs, task addresses, and unaffected image-loading state;
state inside removed views is not preserved.

```swift
FlatMarkView(
    markdown: markdown,
    unsupportedContentPolicy: .custom(
        inline: { source in AttributedString(source) },
        block: { source in AnyView(Button("Inspect") { inspect(source) }) }
    )
)
```

The inline closure is required and returns `AttributedString`. For text-only replacements, use
`.custom { source in AttributedString(source) }`. Inline nodes always use this closure. Block nodes
use the optional block override when supplied; otherwise they render the inline closure's output
as native text.

Both closures receive the same extracted source as `.literal`: raw HTML, otherwise a valid original
source slice, readable descendants, or an empty string. Empty extraction still reaches the selected
closure. Opening and closing tags are separate nodes, not paired elements. Known containers recurse;
escaped tags, code, and ordinary text do not invoke either closure.

Replacements keep their structural position and ambient environment. FlatMark adds no literal
fallback or minimum-size box. Block controls remain independently actionable beside tasks and
supported links. Inline replacement text outside image-free iOS paragraphs gets ambient SwiftUI
styling, including heading fonts. Image-free iOS paragraphs use semantic UIKit typography.
They preserve explicit `UIFont` and foreground-color attributes per run. SwiftUI `Font` attributes
use semantic native typography instead. Host-supplied fixed `UIFont` values do not scale automatically.
Each run inherits enclosing Markdown presentation intents and links when the host omits those
attributes. An explicit host intent replaces the enclosing intent, including an empty intent set
that suppresses inheritance. A host link overrides the enclosing destination on its run; a missing
link inherits it. Replacement links use the same `linkActivationAction` and inherited `openURL`
path as supported links. Inline replacements compose with
supported neighbors as native text and contribute their wording to paragraph accessibility text.

Empty attributed output and block overrides returning `AnyView(EmptyView())` do not imply recursive
omission: parent spacing may remain. No spaces are synthesized. These are presentation closures;
invocation counts are not lifecycle guarantees.

Built-in policies never execute HTML or fetch HTML resources. **Custom output is host-owned**,
including interpretation, sanitization, navigation, and resource access. FlatMark is not an HTML sanitizer.

## Layout and selection limits

On iOS, image-free paragraphs compose supported and custom text in a noneditable, selectable
`UITextView`. They use system body typography, respond to Dynamic Type, and measure the offered
width without a fixed reading width. Ambient SwiftUI font, foreground style, and tint are not
styling contracts for this path. Selection may reset on updates; selection is not continuous across
blocks. macOS paragraphs, headings, list labels, and table cells retain the existing SwiftUI path.

Any paragraph containing a Markdown image keeps the entire existing renderer in every loading
phase. Mixed text/image content wraps by native runs rather than character-level typesetting. A long text run may wrap
internally or move as a whole. Selection works within supported text
regions but is not continuous across arbitrary views. Linked images deliberately separate adjacent
selectable text regions so the image remains independently actionable. Tables scroll horizontally;
parsed column alignment does not change native cell alignment.

See the [support matrix](SUPPORT.md) for construct-specific behavior and the
[runtime guide](Tests/README.md) for verification limits.

## Scope

FlatMark is a preview renderer, not a Markdown editor, general serializer, browser, HTML sanitizer,
or GitHub web clone. Its only source mutation is an interacted task marker. Repository-context links,
issue expansion, server-side transformations, and other GitHub-specific post-processing are out of scope.
