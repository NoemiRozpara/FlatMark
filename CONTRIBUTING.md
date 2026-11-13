# Contributing

FlatMark is a native SwiftUI Markdown preview renderer; see the [scope contract](README.md#scope).

## Scope expectations

- Follow the [repository rules](AGENTS.md) for change scope, dependencies, and prior agreement.
- Public API, security-weighted defaults, and platform floors follow
  [versioning policy](Documentation/Versioning.md); notable changes need a [CHANGELOG.md](CHANGELOG.md) entry.

Read the guidance for your task:

- Planning work: [planning](Documentation/Contributing/Planning.md) and [architecture](Documentation/Contributing/Architecture.md).
- Changing UI: [UI guidance](Documentation/Contributing/UI.md).
- Verifying changes: [build and test policy](Documentation/Contributing/BuildAndTest.md).
- Reviewing changes: [code review](Documentation/Contributing/CodeReview.md).

The [documentation index](Documentation/README.md) links all guides. [AGENTS.md](AGENTS.md) defines document precedence and report style.

## Environment

Use the [required toolchain and platforms](README.md#requirements).
Optional tools: [SweetPad CLI](https://sweetpad.hyzyla.dev/docs/cli/getting-started/) for snapshot
capture, Python 3 for [benchmarks](Benchmarks/README.md), and XcodeGen for the optional
[physical-device benchmark hosts](Benchmarks/DeviceHost/README.md).

## Commands

Run from the repository root.

```sh
swift test                              # package tests, snapshot suites included
swift test --filter <test-name>         # focused run; confirm the intended tests ran
swift test --list-tests                 # discovery
```

For DocC, use Xcode's **Product → Build Documentation**; see the
[documentation build checklist](Documentation/Releasing.md#5-build-the-documentation).

For demo changes, follow the [demo project policy](Documentation/Contributing/BuildAndTest.md#demo-project-changes)
and [demo guide](Demo/README.md).

Further lanes, with their own prerequisites and limits:
[recipe captures](Demo/README.md#sweeping-widths),
[snapshot recording](Tests/README.md#verify-and-record),
[benchmarks](Benchmarks/README.md#run) and their
[regression check](Benchmarks/README.md#regression-checks), and
[device driving](Documentation/Contributing/DeviceHub.md).

CI is manual-dispatch only for now
([`.github/workflows/ci.yml`](.github/workflows/ci.yml)); read its
[limits](Documentation/Contributing/BuildAndTest.md#ci) before trusting a green or red lane. Never record snapshots from
CI.

## Pull requests

- Describe the changed behavior, not the diff.
- Report verification under the [build and test policy](Documentation/Contributing/BuildAndTest.md#reporting).
- Add or update tests for behavior changes, and the affected guides when documented behavior changes.
