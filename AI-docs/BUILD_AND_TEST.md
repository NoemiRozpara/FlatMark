# Build and test

## Authoritative guides

This document selects verification; the linked guides own commands, scenarios, and limitations:

- [README requirements](../README.md#requirements): supported toolchain and platform minimums.
- [Tests/README.md](../Tests/README.md): package tests, observation boundaries, manual checklist, and verification status.
- [Demo/README.md](../Demo/README.md): running the host, capture presets, signing, and project generation.
- [Benchmarks/README.md](../Benchmarks/README.md): construction measurements and regression checks.
- [SUPPORT.md](../SUPPORT.md): supported Markdown behavior.
- [DEVICE_HUB.md](DEVICE_HUB.md): device targeting, resizing, capture, and settings.

## Toolchain

FlatMark requires Xcode 26.0+ / Swift 6.2 and supports iOS 17+ / macOS 15+. `Package.swift` declares the package's tools version, Swift language mode, and platform minimums. Keep it consistent with the README.

The README [Requirements](../README.md#requirements) section owns why macOS 14 was dropped: Apple stopped
patching it. Xcode 26 also requires macOS 15.6 or later, so macOS 14 cannot be built or tested with a
supported toolchain. Do not claim macOS 14 runtime behavior from a newer-OS run. Do not raise the floor
past macOS 15 without a new decision: macOS 15 is the newest release that still runs on every Mac Apple
patches.

Distinguish minimum requirements from the environment used for a particular run. Newer-toolchain success does not establish minimum-toolchain or minimum-OS compatibility. Record the actual environment when results depend on it, especially mounted native-content inspection and benchmarks. Do not copy a consumer application's machine-local Xcode path or toolchain pin into this repository.

## Verification policy

Run the narrowest meaningful check that covers affected behavior. Broaden when dependencies, shared behavior, a failure, or the task's acceptance criteria justify it. Name the check performed and its limitations.

- Documentation-only changes: check links, commands, and consistency; no app build is required.
- Focused behavior changes: inspect existing coverage, then run affected tests, for example `swift test --filter <test-name>` from the repository root.
- Shared package behavior, dependencies, or broad changes: run the package suite with `swift test` as appropriate.
- UI changes: run the relevant automated checks and observe affected behavior in the demo on the affected platforms.
- Parser/projector, dependency, or performance changes: consider the benchmark guide's regression procedure. Do not add noisy CI timing assertions.

Prefer Swift Testing for new tests. Use the installed TDD skill when requested or suited to the change.
Reuse existing test support and test behavior rather than implementation details.

A consumer application's green build or test run does not run FlatMark's dependency tests. Run FlatMark verification in this repository.

## Tools

Use the available package tooling for package checks; do not require a particular MCP integration or wrapper to run `swift test`.

Read the installed MobileBuildMCP skill before using it for Apple-platform build, run, debug, or UI
automation. Discover schemes and destinations rather than copying machine-local identifiers. Report
fallbacks or unavailable tooling when they limit verification.

Inspect diagnostics and failure logs when a run fails; do not read or paste an entire successful log by default. When an exact count or selection matters, inspect the result summary and confirm the intended tests ran. A successful command that selected no tests is not behavioral verification.

Do not assume session defaults, CI or formatter hooks, or coverage configuration exist.

## Demo project changes

`Demo/project.yml` is the source of truth for demo project configuration. Do not change configuration only in the generated Xcode project. After changing `project.yml` or adding/removing demo or shared fixture files, regenerate with `cd Demo && xcodegen generate`. Include the generated project and schemes in the change.

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

Drive the device instead of pinning a layout. Test a width, Dynamic Type size, or appearance by changing
the running device's state with `devicectl`, then capture and inspect. Do not add launch arguments,
fixture constants, or hardcoded window sizes that fake a viewport. `scripts/capture-recipe-lab.sh` is the
reference sweep: inspect its requested/measured geometry and scale provenance. A `clamped`, `rejected`,
unknown, or over-cap width is a finding, not a pass. See [DEVICE_HUB.md](DEVICE_HUB.md).

Run relevant checks on both iOS and macOS when shared rendering or interaction changes affect both. Record platform, actions, observations, and unavailable checks. If a lane is unavailable, say so and leave the affected behavior unverified rather than substituting compilation or a semantic tree.

The testing guide owns current verification status; historical observations and old captures do not verify a changed fixture or implementation.

## Reporting

Write reports under [Write plainly](../AGENTS.md#write-plainly). Distinguish what was inspected, compiled, automatically tested, and observed in the running app. Name the commands or tool lane, and report meaningful limitations. A green result needs a concise summary, not pasted test listings.

Do not claim coverage percentages, performance improvements, platform compatibility, or accessibility correctness without corresponding evidence. For benchmarks, record the environment and follow the existing measurement method rather than comparing unrelated runs.
