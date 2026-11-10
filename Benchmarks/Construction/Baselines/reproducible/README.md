# Reproducible construction baseline

Three sequential Release processes measured committed source
`91492edb172bd68f87351df5f1365c1ca14a033b` from
https://github.com/NoemiRozpara/FlatMark. The tracked working tree was clean before the build;
no library, harness, fixture, manifest, or dependency-lock changes were made for these runs.
The result files and this report were added after measurement.

## Obtain and run

In a separate checkout:

```sh
git clone https://github.com/NoemiRozpara/FlatMark.git
cd FlatMark
git checkout --detach 91492edb172bd68f87351df5f1365c1ca14a033b
swift build --product FlatMarkConstructionBenchmark --configuration release
for n in 1 2 3; do
  .build/release/FlatMarkConstructionBenchmark > "/tmp/flatmark-run$n.csv"
done
```

The commit contains the library in `Sources/`, the executable and deterministic fixture definitions
in `Benchmarks/Construction/main.swift`, its companion `PreviewBenchmark.swift`, the build settings in
`Package.swift`, and exact dependency revisions in `Package.resolved`. Use that commit's lockfile,
not the latest lockfile. No preview mode or device adapter was used.

SHA-256 checks for the measured inputs:

| File | SHA-256 |
| --- | --- |
| `Package.resolved` | `699e6efaf72535253913ab1db4dcf65ed513c9d7250bcd6bf17b46977ed0acbf` |
| `Package.swift` | `446c0f47bb4faa6891a814e31b5197a3d72954e98bbc277633eb5a69844f669f` |
| `Benchmarks/Construction/main.swift` | `a60c10d14d2996e7afb8072e12b440bc865983e6c6a6bc5b44b67e25bf009a29` |
| `Benchmarks/Construction/PreviewBenchmark.swift` | `8adfcd3d7d658984a9287955efc0b211101d6054a93ba7d37cc3dce397df4323` |

## Environment and limits

- Apple M3 Pro, arm64, 12 cores (6 performance, 6 efficiency), 36 GB memory.
- macOS 27.0.1 (26A434); Xcode 27.0 (27A266a).
- Apple Swift 6.4 (`swiftlang-6.4.0.34.1`, `clang-2100.3.34.1`).
- SwiftPM Release, default optimization; five warmups and 30 samples per scenario.
- Three standalone processes ran sequentially after one build, without a debugger.
- Power, thermals, and background activity were not controlled or instrumented.

Each CSV contains 15 construction scenario rows and checksum `351684165`. Timings include the harness's disclosed
reflection/cache/allocator limitations; see [methodology](../../../README.md#method).
These are construction diagnostics, not rendering or mobile responsiveness measurements.
Use these files for future same-method, comparable-environment investigations, not CI timing gates.
