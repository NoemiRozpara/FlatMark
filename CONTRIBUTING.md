# Contributing

FlatMark is a native SwiftUI Markdown preview renderer; see the [scope contract](Documentation/Usage.md#scope).

## Scope expectations

- Follow the [repository rules](AGENTS.md) for change scope, dependencies, and prior agreement.
- Public API, security-weighted defaults, and platform floors follow
  [VERSIONING.md](VERSIONING.md); notable changes need a [CHANGELOG.md](CHANGELOG.md) entry.

Read the guidance for your task:

- Planning work: [planning](AI-docs/PLANNING.md) and [architecture](AI-docs/ARCHITECTURE.md).
- Changing UI: [UI guidance](AI-docs/UI.md).
- Verifying changes: [build and test policy](AI-docs/BUILD_AND_TEST.md).
- Reviewing changes: [code review](AI-docs/CODE_REVIEW.md).

[AGENTS.md](AGENTS.md) defines document precedence and report style.

## Environment

Use the [required toolchain and platforms](README.md#requirements).
Optional tools: [SweetPad CLI](https://sweetpad.hyzyla.dev/docs/cli/getting-started/) for snapshot
capture, XcodeGen for the demo project, and Python 3 for benchmarks.

## Commands

Run from the repository root.

```sh
swift test                              # package tests, snapshot suites included
swift test --filter <test-name>         # focused run; confirm the intended tests ran
swift test --list-tests                 # discovery

bash scripts/build-docs.sh /tmp/flatmark-docs   # DocC build, warnings are errors
```

For demo changes, follow the [demo project policy](AI-docs/BUILD_AND_TEST.md#demo-project-changes)
and [regeneration instructions](Demo/README.md).

Further lanes, with their own prerequisites and limits:
[recipe captures](Demo/README.md#sweeping-widths),
[snapshot recording](Tests/README.md#verify-and-record),
[benchmarks](Benchmarks/README.md#run) and their
[regression check](Benchmarks/README.md#regression-checks), and
[device driving](AI-docs/DEVICE_HUB.md).

CI is manual-dispatch only for now
([`.github/workflows/ci.yml`](.github/workflows/ci.yml)); read its
[limits](AI-docs/BUILD_AND_TEST.md#ci) before trusting a green or red lane. Never record snapshots from
CI.

## Pull requests

- Describe the changed behavior, not the diff.
- Report verification under the [build and test policy](AI-docs/BUILD_AND_TEST.md#reporting).
- Add or update tests for behavior changes, and the affected guides when documented behavior changes.
