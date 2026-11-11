# Changelog

Notable changes to FlatMark, newest first. Format:
[Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html) as interpreted by
[VERSIONING.md](VERSIONING.md). **Breaking** entries change the public API or documented behavior in
a way that needs host action; each one states the replacement.

Add an entry whenever public behavior changes. Release steps: [RELEASING.md](RELEASING.md).

## [Unreleased]

`main` is ahead of the last published tag; nothing here is in a released version yet.

### Added

- Paragraphs, headings, list text, and table cells render as selectable native text
  (`UITextView` on iOS, `NSTextView` on macOS) with semantic system typography, replacing SwiftUI
  text views on that path.
- Loaded images attach inline in that same native storage at intrinsic size, shrinking to the
  paragraph width; other phases show an inline state icon with the policy-resolved label.
- macOS exports meaningful image descriptions, destination-first image-link names, and phase wording.
- `FlatMarkUnsupportedContentPolicy` is now `Hashable` and `Sendable`.
- MIT license for source and docs, plus separate attribution for the bundled fixture images
  ([`Support/FlatMarkFixtures/ASSETS.md`](Support/FlatMarkFixtures/ASSETS.md)).
- Contributor and verification tooling outside the library product: manual-dispatch CI lanes,
  exact-pixel snapshot suites with diff artifacts, construction benchmarks with a history matrix, and
  Recipe Lab capture scripts that record real geometry.

### Changed

- **Breaking:** `FlatMarkImageLoader` returns `NativeImage` (`UIImage` on iOS, `NSImage` on macOS)
  instead of SwiftUI `Image`. Hosts convert or store native images; FlatMark no longer accepts a
  pre-built `Image`.
- **Breaking:** `@username` mentions always render bold. Remove `detectMentions: true`; the flag no
  longer exists on `FlatMarkDocument.init(markdown:baseURL:)` or `FlatMarkView(markdown:...)`.
  Detection and styling are unchanged otherwise, and no user lookup happens.
- **Breaking:** `FlatMarkUnsupportedContentPolicy.custom(render:)` is removed. Use `.literal` or
  `.omit`; host-owned views are out of scope for a preview renderer.
- Unsupported content now flows through the standard inline renderer, so `.literal` keeps the
  enclosing Markdown styling and link instead of replacing the run.
- Blocks build in a `LazyVStack`, so offscreen content is built lazily.

## [0.1.0] - 2026-10-29

### Added

- First published Swift package: `FlatMark` library product for iOS 17+ and macOS 15+.
- `FlatMarkView` with source and retained-`FlatMarkDocument` initializers, host image loader and URL
  policy, link-activation callback, optional task-list editing with custom markers, and the
  `.literal` / `.omit` / `.custom` unsupported-content policies.
- Package tests, a test fixture host with shared recipe fixtures, and construction benchmark sources.

[Unreleased]: https://github.com/NoemiRozpara/FlatMark/compare/0.1.0...HEAD
[0.1.0]: https://github.com/NoemiRozpara/FlatMark/releases/tag/0.1.0
