# Changelog

Notable changes to FlatMark. Format: [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/).
Versions follow the [versioning policy](Documentation/Versioning.md). Publication follows the [release checklist](Documentation/Releasing.md).

## [Unreleased]

## [0.1.1] - 2026-11-13

Benchmark and tooling update. No public API and no documented behavior changed.

### Changed

- Re-recorded construction and preview benchmark results at the `0.1.0` sources on macOS 27.0.1
  (Apple M3 Pro, Xcode 27.0 / Swift 6.4) and on a physical iPhone XR running iOS 18.7.12. The iPhone
  XR record repeats the accepted nesting limit: the nested fixture did not finish mounting within the
  capture driver's 180-second wait, and the links/tables capture shows the second and third columns
  clipped. See [known performance limits](Benchmarks/README.md#known-performance-limits).
- Capture and environment records (`scripts/log_sanitizer.py`) also redact physical device
  identifiers, machine-local MobileBuildMCP log paths, signing team IDs, and signing account
  addresses.

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

[Unreleased]: https://github.com/NoemiRozpara/FlatMark/compare/0.1.1...HEAD
[0.1.1]: https://github.com/NoemiRozpara/FlatMark/compare/0.1.0...0.1.1
[0.1.0]: https://github.com/NoemiRozpara/FlatMark/tree/0.1.0
