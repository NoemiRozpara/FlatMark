# iPhone XR baseline

For current rendering measurements and the top-level lazy-stack experiment, see
[the eager/lazy comparison](lazy-stack-comparison.md). The construction results below are historical.

Three physical iPhone XR Release runs measured construction, not rendering or main-thread stalls.
See [methodology and regression policy](README.md).

**Read the "Mentions enabled" column as the current analogue.** These runs predate unconditional mention
detection, so `initial`, `source change`, and `base URL change` excluded it and understate today's cost.
Re-measure before using this as a regression baseline. The exact measured source and temporary host
were not archived together; these are historical diagnostics with incomplete provenance, not a
reproducible baseline. This does not establish that the measurements are numerically wrong.
See the [new desktop baseline](Construction/Baselines/reproducible/README.md) for an exact committed
source record; it does not replace device measurement.

Range of medians across three processes, in milliseconds:

| Fixture | Initial | Source change | Base URL change | Mentions enabled |
| --- | ---: | ---: | ---: | ---: |
| ordinary | 0.141–0.146 | 0.143–0.147 | 0.130–0.155 | 1.178–1.185 |
| large-100 | 11.720–12.525 | 11.655–11.691 | 11.664–11.688 | 113.635–113.855 |
| large-1000 | 118.387–128.795 | 118.234–129.817 | 118.680–132.424 | 1162.302–1265.196 |
| nested | 0.811–0.821 | 0.822–0.834 | 0.816–0.824 | 5.339–5.709 |
| links-tables | 39.821–40.806 | 40.501–41.709 | 38.939–40.801 | 38.307–41.577 |

Retained-copy medians were 0.000039–0.000049 ms per value: copy overhead, not parsing. The largest
construction p95 was 1276.757 ms. Median variation stayed below 12%, except the ordinary base-URL case
(19.1%, 0.025 ms absolute). The large fixture slowed across processes despite nominal endpoint thermal
readings, and endpoint readings do not establish stable clock speed. Raw output, including the
`mentions-change` scenario that current builds no longer emit, is in
`Construction/Baselines/iphone-xr-run{1,2,3}.csv` (25 scenario rows each; current builds emit 20).

These costs support retained reuse and host-owned background construction for large or changing
sources, with stale-result handling; the snapshot API remains synchronous.

## Environment and limits

Recorded 2026-10-28 on iPhone XR (`iPhone11,8`, A12 Bionic), iOS 18.7 (22H20), arm64, with Xcode 27.0 RC
(27A266a) and Swift 6.4, standard iOS Release optimization and no debugger. swift-markdown 0.8.0 and
swift-cmark 0.9.0, as recorded in the run headers. Three sequential app processes, five warmups and 30
samples per scenario. Low Power Mode off and thermal state nominal at each start and end; no continuous
thermal sampling, and no control of charging, battery level, room temperature, background activity, or
scheduling.

A temporary development app runs the benchmark in a detached `.userInitiated` task, keeping the UI
responsive, with auto-lock disabled; status updates and file writes sit outside timed intervals, and no
Markdown is rendered. These are executor-specific construction timings, **not observed main-thread stalls
or frame rates**. One older phone cannot establish a safe source-size limit or performance across devices.
Remeasure current code on the XR before regression comparisons; desktop numbers are not comparable.

## Reproduce on a device

Needs the [package requirements](../README.md#requirements), a development-enabled iPhone, and a signing
team. Pick the phone with `mobilebuildmcp device list`, then set `DEVICE_ID`, `TEAM_ID`, and a free
`BUNDLE_ID`.

1. Scaffold a host outside the repository and point its feature package at FlatMark:

   ```sh
   mobilebuildmcp project-scaffolding scaffold-ios \
     --project-name FlatMarkDeviceBenchmark --output-path /tmp/flatmark-device \
     --bundle-identifier "$BUNDLE_ID" --deployment-target 18.0
   ```

   Add `.package(path: "<repository>/FlatMark")` and the `FlatMark` product to the feature target.

2. Replace that target's `ContentView.swift` with [the device adapter](DeviceHost/ContentView.swift), and
   copy `Construction/main.swift` beside it as `Benchmark.swift`: mark `Fixture` as `Sendable` and wrap
   everything from `let clock = ContinuousClock()` to end of file in `public func runBenchmark() { ... }`.
   Leave all timed work unchanged.

3. Build and launch:

   ```sh
   mobilebuildmcp device build-and-run \
     --workspace-path /tmp/flatmark-device/FlatMarkDeviceBenchmark.xcworkspace \
     --scheme FlatMarkDeviceBenchmark --device-id "$DEVICE_ID" \
     --configuration Release --derived-data-path /tmp/flatmark-device-build \
     --extra-args DEVELOPMENT_TEAM="$TEAM_ID" -allowProvisioningUpdates \
     --launch-args run1
   ```

4. Keep the app foregrounded until it finishes (about two minutes here), then pull the output; MobileBuildMCP
   has no device-container copy command:

   ```sh
   xcrun devicectl device copy from --device "$DEVICE_ID" \
     --source Documents/benchmark-run1.csv --destination /tmp/iphone-run1.csv \
     --domain-type appDataContainer --domain-identifier "$BUNDLE_ID"
   ```

5. Require 20 scenario rows, the checksum, and the final environment line; an empty or partial file is
   incomplete. Then `mobilebuildmcp device stop`, relaunch with `mobilebuildmcp device launch` and
   `--launch-args run2`, then `run3`, repeating the retrieval. The temporary app can be removed
   independently.
