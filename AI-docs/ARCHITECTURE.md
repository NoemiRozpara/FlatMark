# Architecture

FlatMark is an embeddable native Markdown preview renderer, not an owner of application state, services, routing, or persistence. The [README](../README.md) owns public contracts; the [support matrix](../SUPPORT.md) owns construct-specific behavior.

## Package boundaries

| Path | Responsibility |
| --- | --- |
| `Sources/FlatMark` | Public library: construction, projection, rendering, host integration |
| `Support/FlatMarkFixtures` | Internal fixture target; demo compiles its sources directly |
| `Tests/FlatMarkTests` | Package tests, including macOS-mounted checks |
| `Tests/FlatMarkNavigationTestHost` | Isolated macOS interaction support |
| `Benchmarks/Construction` | Document construction measurements, not rendering |
| `Demo` | Local-package iOS/macOS host without application services |

Keep fixtures, test infrastructure, benchmarks, and demo-only dependencies out of the consumed library product. Do not reproduce application domain/data/presentation layers without a demonstrated need.

## Documents, source, and identity

`FlatMarkDocument` pairs original Markdown with its parsed and projected representation. Source and `baseURL` are construction inputs and determine equality; changing either requires a new document.

`FlatMarkView(markdown:)` constructs a document on initialization. Hosts can retain one for `FlatMarkView(document:)`. Image loading, unsupported-content policy, callbacks, and task-marker appearance are render-time settings and must not require reparsing. Preserve equivalent behavior between initializers. Construction must not execute callbacks, fetch resources, or open URLs.

Task addresses belong to the rendered snapshot. Updates use that snapshot's source and change only the selected marker's state byte. Unaddressable tasks stay static. The host accepts or rejects updated source; deferred results must not overwrite newer content. FlatMark must not become a persistence or conflict-resolution layer.

Preserve surviving projected identity, task addresses, and unaffected image-loading state across render-policy changes. Removed views need not retain internal state; see the README's unsupported-content contract.

## Host ownership

| Responsibility | Owner |
| --- | --- |
| Source and persistence | Host |
| Snapshot construction and projection | FlatMark, on host request |
| Task activation and source-preserving update | FlatMark; host accepts the result |
| Navigation permission and routing | Host callback and inherited SwiftUI `openURL` |
| Image fetching, decoding, authentication, caching | Host image loader |
| Image presentation and cancellation | FlatMark |

Prefer explicit inputs and callbacks over required application environments. Do not add repositories, authenticated stores, coordinators, global caches, or navigation infrastructure for a single integration.

## Separate security decisions

Navigation has no built-in scheme allowlist or same-origin restriction; hosts can route or reject links. Image sources pass the image URL policy before reaching the loader. These permissions are independent: allowing one operation does not authorize another.

Built-in unsupported-content policies neither execute HTML nor fetch its resources. Custom attributed text and block views are host-owned, including interpretation, sanitization, resource access, and navigation. FlatMark is not an HTML sanitizer. Discuss public-contract changes explicitly; do not silently change security defaults.

## Interfaces and tests

Keep implementation details internal. Public configuration needs a justified host use case and documented invariants, lifecycle, error behavior, and performance implications. Consider source compatibility and minimum-platform availability.

Prefer observable-interface tests. Keep internal tests for distinct source-coordinate, projection, identity, or layout invariants not covered above them. Neither expose internals for test convenience nor delete useful lower-level coverage mechanically.

## Performance

Construction is synchronous. Retaining documents avoids parsing and projection, not layout or rendering. Construction timings establish neither rendering speed nor a safe source-size limit from one device. Follow the [benchmark guide](../Benchmarks/README.md). Construction scheduling or asynchronous ownership changes require an agreed design, not an incidental refactor.
