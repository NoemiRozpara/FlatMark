# Build and test

## Authoritative guides

This document selects verification; the linked guides own commands, scenarios, and limitations:

- [README requirements](../README.md#requirements): supported toolchain and platform minimums.
- [Tests/README.md](../Tests/README.md): package tests, observation boundaries, manual checklist, and verification status.
- [Demo/README.md](../Demo/README.md): running the host, capture presets, signing, and project generation.
- [Benchmarks/README.md](../Benchmarks/README.md): construction measurements and regression checks.
- [SUPPORT.md](../SUPPORT.md): supported Markdown behavior.

## Toolchain

FlatMark requires Xcode 26.0+ / Swift 6.2 and supports iOS 17+ / macOS 14+. `Package.swift` declares the package's tools version, Swift language mode, and platform minimums. Keep it consistent with the README.

Distinguish minimum requirements from the environment used for a particular run. Newer-toolchain success does not establish minimum-toolchain or minimum-OS compatibility. Record the actual environment when results depend on it, especially mounted native-content inspection and benchmarks. Do not copy a consumer application's machine-local Xcode path or toolchain pin into this repository.

## Verification policy

Run the narrowest meaningful check that covers affected behavior. Broaden when dependencies, shared behavior, a failure, or the task's acceptance criteria justify it. Name the check performed and its limitations.

- Documentation-only changes: check links, commands, and consistency; no app build is required.
- Focused behavior changes: inspect existing coverage, then run affected tests, for example `swift test --filter <test-name>` from the repository root.
- Shared package behavior, dependencies, or broad changes: run the package suite with `swift test` as appropriate.
- UI changes: run the relevant automated checks and observe affected behavior in the demo on the affected platforms.
- Parser/projector, dependency, or performance changes: consider the benchmark guide's regression procedure. Do not add noisy CI timing assertions.

Prefer Swift Testing for new tests. Use the installed TDD skill for behavior changes suited to test-first work or when requested. Work one meaningful failing example → minimal implementation → small green-state refactoring at a time. Reuse existing support and avoid redundant tests that merely mirror implementation details.

A consumer application's green build or test run does not run FlatMark's dependency tests. Run FlatMark verification in this repository.

## Tools

Use the available package tooling for package checks; do not require a particular MCP integration or wrapper to run `swift test`.

For Apple-platform build, run, debug, or UI automation through MobileBuildMCP, read the installed MobileBuildMCP skill before invoking its tools. Discover actual schemes and destinations rather than inventing simulator names or copying machine-local identifiers. Report fallbacks or unavailable tooling when they limit verification.

Inspect returned diagnostics and failure logs when a run fails. Do not read or paste an entire successful log by default. When an exact count or test selection matters, inspect the result summary and confirm that intended tests actually ran; a successful command that selected no tests is not behavioral verification.

Do not assume todo's tool tiers, session defaults, CI hooks, formatter hooks, or coverage configuration exist here.

## Demo project changes

`Demo/project.yml` is the source of truth for demo project configuration. After changing it or adding/removing demo or shared fixture files, regenerate with `cd Demo && xcodegen generate` and include the generated project and schemes in the change. Do not change configuration only in the generated Xcode project.

Use the actual `FlatMarkDemo-iOS` and `FlatMarkDemo-macOS` schemes described in the demo guide. A package test run does not establish that the demo still builds or that an iOS-specific path works.

## Runtime verification

Compiling does not prove a UI change works. Build and run the host, exercise the affected state, and inspect the result. Use the shared fixture and manual checklist rather than creating a second ad hoc verification application.

Match the evidence to the claim:

- Projection checks establish model structure, not visible pixels.
- Mounted native exports establish the exported wording and attributes described in the testing guide, not glyph visibility, clipping, or selection gestures.
- Isolated macOS interaction tests establish their callback behavior, not iOS interaction or external URL-opening success.
- Screenshots need visual inspection and do not establish live VoiceOver or keyboard behavior.
- Fixture font-size overrides are not system Dynamic Type verification.
- Live accessibility and actual selection gestures require running-platform checks.

Run relevant checks on both iOS and macOS when shared rendering or interaction changes affect both. Record platform, actions, observations, and unavailable checks. If a lane is unavailable, say so and leave the affected behavior unverified rather than substituting compilation or a semantic tree.

The testing guide owns current verification status; historical observations and old captures do not verify a changed fixture or implementation.

## Reporting

Distinguish what was inspected, compiled, automatically tested, and observed in the running app. Name the commands or tool lane, and report meaningful limitations. A green result needs a concise summary, not pasted test listings.

Do not claim coverage percentages, performance improvements, platform compatibility, or accessibility correctness without corresponding evidence. For benchmarks, record the environment and follow the existing measurement method rather than comparing unrelated runs.
