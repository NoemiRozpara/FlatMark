# Device construction benchmarks

No current device construction baseline is recorded. Desktop results do not establish mobile
construction cost, main-thread stalls, or frame rates. See [methodology and regression policy](README.md).

## Run on a device

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
   copy `Construction/main.swift` beside it as `Benchmark.swift`. Wrap everything from
   `let clock = ContinuousClock()` to end of file in `public func runBenchmark() { ... }`.
   Leave all timed work unchanged. Archive the exact host and adapted harness with the results,
   alongside the measured FlatMark commit and dependency lockfile.

3. Build and launch:

   ```sh
   mobilebuildmcp device build-and-run \
     --workspace-path /tmp/flatmark-device/FlatMarkDeviceBenchmark.xcworkspace \
     --scheme FlatMarkDeviceBenchmark --device-id "$DEVICE_ID" \
     --configuration Release --derived-data-path /tmp/flatmark-device-build \
     --extra-args DEVELOPMENT_TEAM="$TEAM_ID" -allowProvisioningUpdates \
     --launch-args run1
   ```

4. Keep the app foregrounded until it finishes, then pull the output:

   ```sh
   xcrun devicectl device copy from --device "$DEVICE_ID" \
     --source Documents/benchmark-run1.csv --destination /tmp/iphone-run1.csv \
     --domain-type appDataContainer --domain-identifier "$BUNDLE_ID"
   ```

5. Require 15 scenario rows, a nonzero checksum that agrees across runs of the same build, and the final
   environment line. An empty or partial file is incomplete. Then `mobilebuildmcp device stop`, relaunch
   with `mobilebuildmcp device launch` and `--launch-args run2`, then `run3`, repeating the retrieval.
   The temporary app can be removed independently.

Record hardware, OS, toolchain, build settings, power and thermal observations, and uncontrolled
conditions. These detached-task construction timings exclude rendering and do not measure UI stalls.
