# ``FlatMark``

A native SwiftUI GitHub Flavored Markdown preview renderer for iOS 17+ and macOS 15+.

## Overview

FlatMark parses GitHub Flavored Markdown with
[swift-markdown](https://github.com/swiftlang/swift-markdown) and projects the parsed document into
native SwiftUI views. Paragraphs, headings, list text, and table cells use selectable
`UITextView` (iOS) or `NSTextView` (macOS) content with semantic system fonts.

Start with ``FlatMarkView``. Retain a ``FlatMarkDocument`` to reuse one parse across renders.

The host owns persistence, navigation decisions, and image fetching, decoding, authentication, and
caching. Links have no scheme allowlist: activation reaches the inherited SwiftUI `openURL` action
unless a ``FlatMarkLinkActivationResult`` handler handles or rejects it. Images are network-free
alt-text placeholders until a ``FlatMarkImageLoader`` returns a ``NativeImage``, and
``FlatMarkImageURLPolicy`` gates the scheme before the loader runs. Navigation permission does not
authorize image fetching.

FlatMark is a preview renderer, not an editor, browser, or HTML sanitizer. Content with no native
view follows ``FlatMarkUnsupportedContentPolicy``: inert literal text, or removal. FlatMark never
executes HTML or fetches HTML resources.

The repository guides own the authoritative contracts, support matrix, and verification limits:
[documentation index](https://github.com/NoemiRozpara/FlatMark/blob/main/Documentation/README.md),
[README](https://github.com/NoemiRozpara/FlatMark/blob/main/README.md),
[usage guide](https://github.com/NoemiRozpara/FlatMark/blob/main/Documentation/Usage.md),
[support matrix](https://github.com/NoemiRozpara/FlatMark/blob/main/Documentation/MarkdownSupport.md),
[security policy](https://github.com/NoemiRozpara/FlatMark/blob/main/SECURITY.md), and
[testing guide](https://github.com/NoemiRozpara/FlatMark/blob/main/Tests/README.md).

## Topics

### Rendering

- ``FlatMarkView``
- ``FlatMarkDocument``
- ``ContentBuilder``

### Host-provided behavior

- ``FlatMarkImageLoader``
- ``FlatMarkImageURLPolicy``
- ``NativeImage``
- ``FlatMarkLinkActivationResult``
- ``FlatMarkTaskMarker``
- ``FlatMarkUnsupportedContentPolicy``
