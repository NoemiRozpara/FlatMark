# Architecture

FlatMark is an embeddable native Markdown preview renderer. It does not own application state, services, routing, or persistence. The [README](../README.md) is authoritative for public usage and contracts; the [support matrix](../SUPPORT.md) records construct-specific behavior.

## Package boundaries

- `Sources/FlatMark` implements the public `FlatMark` library product: document construction, projection, rendering, and host integration points.
- `Support/FlatMarkFixtures` supplies shared fixture data through an internal package target. It is not part of the library product. The demo compiles these shared sources directly.
- `Tests/FlatMarkTests` contains package tests, including macOS-mounted checks.
- `Tests/FlatMarkNavigationTestHost` provides isolated macOS interaction support.
- `Benchmarks/Construction` measures document construction, not rendering.
- `Demo` hosts the local package on iOS and macOS without requiring application services.

Keep fixtures, test infrastructure, benchmark code, and demo-only dependencies out of the consumed library product. Do not reproduce an application's domain/data/presentation layering inside the renderer without a demonstrated need.

## Document construction and rendering

`FlatMarkDocument` is a snapshot pairing the original Markdown with its parsed/projected representation. Its construction inputs are source, `baseURL`, and mention detection. Changing any of these requires a new document; document equality compares these inputs.

`FlatMarkView(markdown:)` constructs a document on initialization. Hosts can retain a document and use `FlatMarkView(document:)` to avoid repeated construction. Rendering settings can change without reparsing. They include image loading, unsupported-content policy, callbacks, and task-marker appearance.

Keep parsing/projection separate from render-time decisions. Do not introduce callback execution, resource fetching, or URL opening into document construction. Preserve initializer parity for equivalent inputs and settings.

## Source and identity

Task editing addresses belong to the rendered snapshot, not whichever source the host currently holds. Task updates use that snapshot's source and change only the selected marker's state byte, preserving all other bytes. Unaddressable tasks remain static.

The host decides whether and when to accept updated source. Deferred callback results must not overwrite newer content; do not silently turn FlatMark into a persistence or conflict-resolution layer.

Stable projected identity supports surviving nodes across render-policy changes. Preserve surviving task addresses and unaffected image-loading state. Removed views need not retain their internal state. See the README's unsupported-content contract for exact behavior.

## Host ownership

Define one authoritative owner for each responsibility:

| Responsibility | Owner |
| --- | --- |
| Source and persistence | Host |
| Snapshot construction and projection | FlatMark, when requested by the host |
| Task activation and source-preserving marker update | FlatMark; host accepts the result |
| Navigation permission and application routing | Host callback and inherited SwiftUI `openURL` action |
| Image fetching, decoding, authentication, and caching | Host image loader |
| Image loading presentation and cancellation | FlatMark |
| Custom unsupported-content behavior | Host replacement view |

Do not add repositories, authenticated stores, coordinators, global caches, or application navigation infrastructure to satisfy a single host integration. Prefer small explicit inputs and callbacks over a required application environment.

## Separate security decisions

Navigation permission and image-fetch permission are independent. Link activation has no built-in scheme allowlist or same-origin restriction; hosts can route or reject it. Image sources are checked against the image URL policy before reaching the loader.

Built-in unsupported-content policies do not execute HTML or fetch HTML resources. Custom replacement views are host-owned, including interpretation, sanitization, resource access, and navigation. FlatMark is not an HTML sanitizer.

Preserve these separate decisions rather than treating an allowed link, image, or replacement as authorization for another operation. Do not silently change permissive or restrictive defaults; discuss public-contract changes explicitly.

## Interface and dependency discipline

Keep implementation details internal. Add public configuration only for a justified host need, and document its invariants, lifecycle, error behavior, and performance implications. Consider source compatibility and supported platform availability when changing public declarations.

Prefer tests through meaningful observable interfaces. Internal tests remain appropriate when they protect distinct source-coordinate, projection, identity, or layout invariants that higher-level checks do not cover. Do not expose implementation details solely to make tests convenient or delete useful lower-level coverage mechanically.

## Performance

Construction is synchronous. Retaining a document avoids parsing and projection, not layout or rendering. Do not infer rendering speed from construction measurements or promise a safe source-size limit from one device's timings.

Use the [benchmark guide](../Benchmarks/README.md) for measurement and regression investigation. Changes to construction scheduling or asynchronous ownership require an agreed design, not an incidental refactor.
