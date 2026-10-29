# iPhone XR baseline

Three Release runs on a physical iPhone XR confirm that large-document construction can be too
expensive for main-thread work. See [benchmark methodology and regression policy](README.md).

## Results

Range of medians across three processes, in milliseconds:

| Fixture | Initial | Source change | Base URL change | Mentions enabled |
| --- | ---: | ---: | ---: | ---: |
| ordinary | 0.141–0.146 | 0.143–0.147 | 0.130–0.155 | 1.178–1.185 |
| large-100 | 11.720–12.525 | 11.655–11.691 | 11.664–11.688 | 113.635–113.855 |
| large-1000 | 118.387–128.795 | 118.234–129.817 | 118.680–132.424 | 1162.302–1265.196 |
| nested | 0.811–0.821 | 0.822–0.834 | 0.816–0.824 | 5.339–5.709 |
| links-tables | 39.821–40.806 | 40.501–41.709 | 38.939–40.801 | 38.307–41.577 |

Retained-copy medians were 0.000039–0.000049 ms/value: copy overhead, not parsing.
Raw output: `Construction/Baselines/iphone-xr-run{1,2,3}.csv`. Each file contains all 25 scenarios;
all checksums were `573663895`. The largest construction p95 was 1276.757 ms.

Construction-median variation was below 12%, except the ordinary/base-URL case (19.1%, 0.025 ms
absolute). The large fixture slowed across processes despite nominal endpoint thermal readings.
Endpoint readings do not establish stable clock speed.

**Conclusion:** preserve retained-document reuse and the synchronous API. Evaluate host-owned
background construction for large/changing sources, with snapshot pairing and stale-result handling.
These results do not require a package-owned async state machine.

## Environment and limits

Recorded 2026-10-28:

- iPhone XR (`iPhone11,8`, A12 Bionic), iOS 18.7 (22H20), arm64.
- Xcode 27.0 RC (27A266a), Apple Swift 6.4; standard iOS Release optimization, no debugger.
- swift-markdown 0.8.0 (`3c6f9523da3a1ec2fd829673e472d95b8097a3b8`),
  swift-cmark 0.9.0 (`08ddb528923cc1a6527e02b7a1aee9e516ca749a`).
- Same benchmark/library working tree as the desktop baseline; base revision in
  `Construction/Baselines/revision.txt`.
- Three sequential, separate app processes; five warmups and 30 samples per scenario.
- Low Power Mode off at each start; thermal state nominal at each start/end. No continuous thermal
  sampling or control of charging, battery level, room temperature, background activity, or scheduling.

A separate development app runs the synchronous benchmark in a detached `.userInitiated` task,
keeping the UI responsive. Auto-lock is disabled during measurement. Status updates and output-file
writes are outside timed intervals; no Markdown is rendered. These are executor-specific construction
timings, **not observed main-thread stalls or frame rates**. One older phone cannot establish a safe
source-size limit or performance across devices. Compare future XR runs to this baseline, not to
desktop numbers.

## Reproduce on a device

Use the [package requirements](../README.md#requirements), a connected development-enabled
iPhone, and a valid signing team. The host is temporary and separate from the application under test.

1. Run `mobilebuildmcp device list` and set `DEVICE_ID` to the intended phone. Set `TEAM_ID` to
   the signing team and `BUNDLE_ID` to an available development identifier, such as
   `com.example.FlatMarkDeviceBenchmark`.
2. Scaffold a host outside the repository:

   ```sh
   mobilebuildmcp project-scaffolding scaffold-ios \
     --project-name FlatMarkDeviceBenchmark --output-path /tmp/flatmark-device \
     --bundle-identifier "$BUNDLE_ID" --deployment-target 18.0
   ```

3. In `FlatMarkDeviceBenchmarkPackage/Package.swift`, use tools version 6.4, add
   `.package(path: "<repository>/FlatMark")`, and add
   `.product(name: "FlatMark", package: "FlatMark")` to the feature target's dependencies.
4. Replace the feature target's `ContentView.swift` with [the device adapter](DeviceHost/ContentView.swift).
   Copy `Construction/main.swift` alongside it as `Benchmark.swift`: add `Sendable` to `Fixture`,
   then wrap everything from `let clock = ContinuousClock()` to EOF in
   `public func runBenchmark() { ... }`. Leave all timed work unchanged.
5. Build and launch:

   ```sh
   mobilebuildmcp device build-and-run \
     --workspace-path /tmp/flatmark-device/FlatMarkDeviceBenchmark.xcworkspace \
     --scheme FlatMarkDeviceBenchmark --device-id "$DEVICE_ID" \
     --configuration Release --derived-data-path /tmp/flatmark-device-build \
     --extra-args DEVELOPMENT_TEAM="$TEAM_ID" -allowProvisioningUpdates \
     --launch-args run1
   ```

6. Keep the app foregrounded until complete (about two minutes in this baseline). Retrieve output
   using Apple's file-transfer tool; MobileBuildMCP has no device-container copy command:

   ```sh
   xcrun devicectl device copy from --device "$DEVICE_ID" \
     --source Documents/benchmark-run1.csv --destination /tmp/iphone-run1.csv \
     --domain-type appDataContainer --domain-identifier "$BUNDLE_ID"
   ```

7. Validate all 25 scenario rows, the checksum, and the final environment line. An empty or partial
   file is incomplete. Stop the returned process with `mobilebuildmcp device stop`, then use
   `mobilebuildmcp device launch` with the same device/bundle and `--launch-args run2` or `run3`.
   Repeat retrieval and stop the final process. The temporary app can be removed independently.
