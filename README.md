# FlatMark

A native SwiftUI GitHub Flavored Markdown preview renderer for iOS 17+ and macOS 15+, with optional
interactive task lists. Parsing uses [swift-markdown](https://github.com/swiftlang/swift-markdown).

[Usage guide](Documentation/Usage.md) · [Markdown support](SUPPORT.md) · [Demo](Demo/README.md) · [Testing](Tests/README.md) · [Benchmarks](Benchmarks/README.md)

## Requirements

- Xcode 26.0+ / Swift 6.2
- iOS 17 / macOS 15
- [swift-markdown](https://github.com/swiftlang/swift-markdown) 0.8.x

See [contributor guidance](AI-docs/BUILD_AND_TEST.md#toolchain) for platform-floor rationale and
verification boundaries.

## Installation

In Xcode, choose **File → Add Package Dependencies**, enter
`https://github.com/NoemiRozpara/FlatMark.git`, select **Up to Next Minor Version** from **0.1.0**,
and add the **FlatMark** library product to your app target.

For a Swift package, add the dependency and product:

```swift
// Package dependencies:
.package(url: "https://github.com/NoemiRozpara/FlatMark.git", .upToNextMinor(from: "0.1.0"))

// Your target's dependencies:
.product(name: "FlatMark", package: "FlatMark")
```

`0.1.0` is the existing public tag; these guides describe the current checkout, which includes
unreleased changes. Consult the documentation at the selected tag when using a released version.
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
including Unicode and line endings, is preserved. Updates derive from the rendered snapshot, not a
newer host string. Hosts that defer accepting a result must prevent stale results from overwriting
newer content. Without a callback, tasks remain static accessible content. Live VoiceOver and keyboard
behavior still need platform verification. See [task contracts and custom markers](Documentation/Usage.md#interactive-tasks).

### Reusing a document

Retain a snapshot to avoid repeated parsing and projection:

```swift
let document = FlatMarkDocument(
    markdown: markdown,
    baseURL: URL(string: "https://example.com/docs/")
)

FlatMarkView(document: document)
```

Rebuild when the source or `baseURL` changes. Construction is synchronous; retained reuse avoids
construction, not layout or rendering. See [document contracts](Documentation/Usage.md#reusing-a-document).

## Essential limits

- The host owns persistence, navigation decisions, and image fetching, decoding, authentication, and
  caching. Images default to network-free alt-text placeholders.
- Links have **no scheme allowlist or same-origin restriction**. Activation uses the inherited SwiftUI
  `openURL` action unless the host handles or rejects it. Navigation permission does not authorize
  image fetching. See [navigation policy](Documentation/Usage.md#links-and-document-bases) and
  [image loading](Documentation/Usage.md#images).
- Unsupported content is inert literal text by default, or can be omitted by parser node. FlatMark
  never executes HTML or fetches HTML resources. See [unsupported content](Documentation/Usage.md#unsupported-content).
- Native text is selectable, but selection may reset on updates and does not span blocks. Tables
  scroll horizontally. Native typography, attachment behavior, and accessibility qualifications are
  in [layout and selection limits](Documentation/Usage.md#layout-and-selection-limits).

FlatMark is a preview renderer, not a Markdown editor, general serializer, browser, HTML sanitizer, or
GitHub web clone. Its only source mutation is an interacted task marker. Repository-context links,
issue expansion, server-side transformations, and other GitHub-specific post-processing are out of scope.

## Demo

Open [Demo/FlatMarkDemo.xcodeproj](Demo/FlatMarkDemo.xcodeproj), select **FlatMarkDemo-iOS** or
**FlatMarkDemo-macOS**, and Run. See [demo setup](Demo/README.md) for signing and capture presets.

## License

FlatMark's source code and documentation are available under the [MIT License](LICENSE).
The bundled fixture images have separate terms; see [asset notices](Support/FlatMarkFixtures/ASSETS.md)
for photo attribution and Apple's SF Symbols restrictions.
