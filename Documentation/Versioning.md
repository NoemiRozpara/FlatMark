# Versioning policy

How FlatMark numbers releases and what hosts may rely on between them.
[CHANGELOG.md](../CHANGELOG.md) records changes; the [release checklist](Releasing.md) runs the release.

## What is covered

The public surface is everything a host can depend on:

- All public declarations in the `FlatMark` library product.
- Host-facing behavior documented in [README.md](../README.md),
  [usage](Usage.md), [Markdown support](MarkdownSupport.md), and
  [SECURITY.md](../SECURITY.md).
- Declared minimums in `Package.swift`: toolchain, Swift language mode, iOS and macOS floors.
- Package identity: repository URL, product name, and target names.

Outside the compatibility guarantee: the demo app, `Support/FlatMarkFixtures`, tests, benchmarks, `scripts/`,
contributor guidance in `Documentation/Contributing/`, and local planning artifacts in `AI-docs/`.
They can change in any release, including a patch.

## Version rules

FlatMark follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html) as `MAJOR.MINOR.PATCH`.

| Change | Before 1.0.0 | From 1.0.0 |
| --- | --- | --- |
| Fix, no public-surface change | Patch | Patch |
| Additive public API, or new documented behavior that existing calls keep working through | Minor | Minor |
| Breaking public-surface change, including a security-weighted default | Minor | Major |
| Raise the toolchain or an OS floor | Minor | Major |
| Rename or remove a product, target, or the repository URL | Minor | Major |

Version `0.1.0` defines the initial public surface.

Release tags use bare numbers without a `v` prefix — `0.1.0`, `0.2.0`.
SwiftPM accepts both forms; keep the chosen form after publication.

Pre-release tags use `X.Y.Z-beta.1`. Range requirements ignore them, so name the exact pin in the
release notes; a pre-release carries no support commitment beyond the next stable release.

Additive rules that keep the table honest:

- A new initializer parameter needs a default value, so existing call sites still compile.
- New conformances (`Sendable`, `Hashable`) are additive. A new enum case is additive only where hosts
  cannot switch exhaustively; hosts can switch `FlatMarkLinkActivationResult` and
  `FlatMarkUnsupportedContentPolicy`, so a new case in either is breaking.
- A snapshot, doc, benchmark, or internal refactor that changes no documented behavior is a patch.

## Breaking changes before 1.0.0

Pre-1.0 means no API stability promise. FlatMark still may not break quietly:

1. Every breaking change gets a **Breaking** entry in [CHANGELOG.md](../CHANGELOG.md) naming the
   replacement.
2. Removals are allowed directly; a deprecation cycle is not required before 1.0.0. After 1.0.0, a
   deprecated API stays for at least one minor release before removal.
3. Update affected guides in the same release, including changes to security-weighted defaults
   such as link handling, image policy, and unsupported-content policy.
4. Before 1.0, use a patch-only dependency range to exclude minor releases that may break compatibility,
   or an exact pin for a fixed version. See the [installation examples](../README.md#installation).

## Reaching 1.0.0

Declare 1.0.0 only when all of these hold, and say so in the release entry:

- The public surface above is unchanged across two consecutive minor releases, or the remaining
  breaks are agreed as the last ones.
- Required CI lanes meet the [build and test policy](Contributing/BuildAndTest.md#ci).
- Live accessibility and selection behavior on both platforms has running-app evidence recorded in
  [Tests/README.md](../Tests/README.md#verification-status).
- No open issue disputes a documented public contract.

## Yanks and fixes

Never move or delete a published tag: SwiftPM caches resolved sources. Fix forward with a new version
and mark the withdrawn one in [CHANGELOG.md](../CHANGELOG.md).
