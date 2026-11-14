# Build and test

## Authoritative guides

This document selects verification; the linked guides own commands, scenarios, and limitations:

- [README requirements](../../README.md#requirements): supported toolchain and platform minimums.
- [Tests/README.md](../../Tests/README.md): package tests, observation boundaries, manual checklist, and verification status.
- [Demo/README.md](../../Demo/README.md): running the host, capture presets, signing, and project configuration.
- [Benchmarks/README.md](../../Benchmarks/README.md): construction measurements and regression checks.
- [Markdown support](../MarkdownSupport.md): supported Markdown behavior.
- [Release checklist](../Releasing.md): release verification order, gates, doc build, and tagging.
- [Device Hub](DeviceHub.md): device targeting, resizing, capture, and settings.

## Toolchain

FlatMark requires Xcode 26.0+ / Swift 6.2 and supports iOS 17+ / macOS 15+. `Package.swift` declares the package's tools version, Swift language mode, and platform minimums. Keep it consistent with the README.

The macOS 15 floor retains compatibility with Intel Macs. Do not raise it without a new decision.
When revisiting the floor, check [Apple security releases](https://support.apple.com/en-us/100100)
and supported hardware; that inventory changes over time.

Xcode 26 requires a macOS 15.6 or later development host
([release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-26-release-notes)).
The development-host requirement is separate from FlatMark's deployment target and does not
establish runtime behavior on the minimum supported OS. macOS 14 is outside FlatMark's support
contract and has not been runtime-tested.

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

## CI

[`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) runs the `pr` subset on pull requests
and the `weekly` subset each Monday at 06:00 UTC. It also offers three manual dispatch subsets.
[The shared unit lane](../../.github/workflows/unit-lane.yml) owns test commands, simulator lifecycle,
and the single iOS snapshot exclusion list.

The configured lanes pair macOS 26 with Xcode 26 and macOS 27 with Xcode 27.
These are runner configurations, not an Apple restriction against Xcode 27 on macOS 26.
The separate macOS 15 hosted lane targets the minimum macOS version.

| Dispatch subset | Lane | Runner / host | Xcode | Execution |
| --- | --- | --- | --- | --- |
| `pr` (default) | `macos-minimum` | `macos-15` / macOS 15 | 26.0.1 | macOS unit tests |
| `pr` | `macos-current` | `xcode-27` / macOS 27 | GA 27.2 | macOS unit tests |
| `pr` | `ios-unit` | `macos-26` / macOS 26 | 26.6 | Newest installed GA iOS 26.x simulator |
| `weekly` | `macos-26-xcode26` | `macos-26` / macOS 26 | 26.6 | macOS unit tests |
| `weekly` | `ios-26` | `macos-26` / macOS 26 | 26.6 | Newest installed GA iOS 26.x simulator |
| `weekly` | `ios-27` | `xcode-27` / macOS 27 | GA 27.2 | Newest installed GA iOS 27.x simulator |
| `ios17-feasibility` | `ios-17-feasibility` | `macos-15` / macOS 15 | 26.0.1 | Exactly iOS 17.5; manual feasibility trial, then pre-release if qualified |

Scheduled runs use the default branch. There is no push trigger.
The `ios17-feasibility` subset and `ios-17-feasibility` lane name identify the iOS 17.5 feasibility
check. It stays manual-only:
`gh workflow run ci.yml -f subset=ios17-feasibility` requests it.

### Test and build boundaries

- macOS runs `swift test --skip Snapshot`.
- iOS runs `xcodebuild test -scheme FlatMark-Package -destination 'platform=iOS Simulator,id=<created UUID>'`
  with explicit `-skip-testing:FlatMarkTests/<Suite>` arguments. The eight pixel suites are listed in
  one place in `unit-lane.yml`; update that list when adding a pixel suite. Non-pixel snapshot-reference
  helper tests can still run on iOS. Both platforms use the existing `FlatMarkTests` target.
- Each test lane must report a nonzero executed test count in the job summary. Zero or missing counts
  fail the check. Logs record the actual host, selected Xcode, and iOS runtime; host-major assertions
  reject a runner that no longer provides the intended OS.
- Every lane separately builds `FlatMarkDemo-macOS` or `FlatMarkDemo-iOS`. This is **compile-only**,
  not demo runtime coverage.
- All hosted lanes exclude exact-pixel suites and set `FLATMARK_SNAPSHOT_RECORD=never`.
  Exact-pixel verification stays local; record OS, Xcode,
  and display/capture scale. Results qualify only the recorded environment.
- No lane drives the running demo, VoiceOver, gestures, or iOS system Dynamic Type changes. These
  remain manual. FlatMark does not support enlarged text on macOS.

### iOS 17.5 feasibility and remaining gaps

The feasibility lane targets iOS 17.5 with Xcode 26.0.1. It does not establish iOS 17.0
execution. If the runtime is absent, the job attempts `xcodebuild -downloadPlatform iOS -buildVersion 17.5`.
Download availability, installation, boot, and test execution remain unverified until the hosted trial.
Failure leaves iOS 17.5 execution as an explicit gap; the lane must not substitute a newer runtime. No simulator runtime
is cached. This is the only approved hosted iOS 17 exception.

macOS 26 × Xcode 27 is deferred: the standard `macos-26` Apple-silicon inventory does not list
Xcode 27. No toolchain download is approved. Substituting `xcode-27` would run macOS 27.
Revalidate the runner inventory before revisiting the gap. macOS 27 × Xcode 26 is unsupported;
iOS 27 × Xcode 26 awaits feasibility review. Local iOS 17.5 × GA Xcode 27 and release-only checks
remain separate requirements.

Recorded Xcode 27.0 results do not qualify the pinned Xcode 27.2 lanes or minimum-toolchain
coverage. Hosted behavior, test counts, durations, and mounted native-test behavior remain
unverified until actual runs.

### Guardrails

- Standard `macos-15`, `macos-26`, and `xcode-27` runners only. Public-repository standard-runner compute
  is free; queue, disk, artifact, and cache limits still apply. The PR subset contains three jobs.
  Before dispatching, confirm the repository is public or
  obtain approval for private-repository compute usage; the public-runner cost assumption does not
  apply while it is private.
- Keep cancellation concurrency, read-only contents permission, and the existing 30-minute macOS /
  45-minute iOS ceilings. Repository settings must require approval for first-time/outside contributors
  before PR triggers are enabled; a workflow cannot enforce that repository setting itself.
- Cache only macOS `.build`, keyed by runner and pinned Xcode path. DerivedData and simulator runtimes
  stay uncached. Keep total repository cache usage within the included 10 GB.
- Upload failure-only diagnostics, capped at 1 MB per file with seven-day retention. Do not upload
  full result bundles, capture directories, or pixel images. Test logs and summaries remain in Actions.
- Pin GA toolchains explicitly; review image inventories when updating the current Xcode 27 pin.
  Missing toolchains or intended runtimes fail rather than silently changing coverage.

## Demo project changes

`Demo/FlatMarkDemo.xcodeproj` and its shared schemes are the source of truth for demo project configuration. Edit them directly in Xcode and include the changes. Demo sources, shared fixtures, and snapshot suites use synchronized folders; the macOS snapshot target's two Rendering helpers use explicit file references. See the [demo guide](../../Demo/README.md) for file membership.

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
manual smoke and screenshot sweep, not a geometry qualification tool. Inspect the screenshots;
capture failures must remain visible. See [Device Hub](DeviceHub.md).

Run relevant checks on both iOS and macOS when shared rendering or interaction changes affect both. Record platform, actions, observations, and unavailable checks. If a lane is unavailable, say so and leave the affected behavior unverified rather than substituting compilation or a semantic tree.

The testing guide owns current verification status; historical observations and old captures do not verify a changed fixture or implementation.

## Reporting

Write reports under [Write plainly](../../AGENTS.md#write-plainly). Distinguish what was inspected, compiled, automatically tested, and observed in the running app. Name the commands or tool lane, and report meaningful limitations. A green result needs a concise summary, not pasted test listings.

Do not claim coverage percentages, performance improvements, platform compatibility, or accessibility correctness without corresponding evidence. For benchmarks, record the environment and follow the existing measurement method rather than comparing unrelated runs.
