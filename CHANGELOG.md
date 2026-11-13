# Changelog

Notable changes to FlatMark. Format: [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/).
Versions follow the [versioning policy](Documentation/Versioning.md). Publication follows the [release checklist](Documentation/Releasing.md).

## [Unreleased]

## [0.1.0] - 2026-11-13

Initial public surface.

### Added

- `FlatMark` Swift package for iOS 17+ and macOS 15+, requiring Xcode 26+ / Swift 6.2.
- `FlatMarkView` with Markdown-source and retained-`FlatMarkDocument` initializers.
- Selectable native text with semantic typography, Markdown formatting, bold `@username` mentions,
  links, lists, tables, quotes, and code blocks. Top-level blocks mount lazily.
- Host-owned image loading with native images, URL policy, inline presentation, and cancellation.
- Host-controlled link activation and optional source-preserving task-list edits with passive custom
  task-marker drawings.
- Literal and omission policies for unsupported content. Literal HTML stays inert and preserves
  enclosing Markdown styling; FlatMark does not execute HTML or fetch its resources.
- Package tests, snapshot suites, shared recipe fixtures, demo hosts, manual-dispatch CI definitions,
  construction benchmarks, and capture tooling. Their presence does not establish platform or
  accessibility qualification; see [verification status](Tests/README.md#verification-status).
- MIT license for source and docs, with separate [fixture-image attribution](Support/FlatMarkFixtures/ASSETS.md).

[0.1.0]: https://github.com/NoemiRozpara/FlatMark/tree/0.1.0
