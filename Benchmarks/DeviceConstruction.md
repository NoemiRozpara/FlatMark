# Device construction benchmarks

This procedure measures construction on a physical iPhone, without rendering inside the timed
interval. See [current results](Results/README.md) and the shared [method](README.md#method).
Detached-task timings do not measure main-thread stalls or frame rates.

## Prepare a host

Requires the [package toolchain](../README.md#requirements), XcodeGen, a development-enabled iPhone,
and a signing team. Discover the phone with `mobilebuildmcp device list`; set `DEVICE_ID` and
`TEAM_ID` locally. Do not include device identifiers or signing credentials in recorded artifacts.

The [recorded host](Results/iphone-xr-construction/Host) and
[project specification](Results/iphone-xr-construction/project.json) preserve the measured adapter.
To generate its disposable project from the repository root:

```sh
python3 - <<'PY'
from pathlib import Path
root = Path.cwd()
out = Path('/tmp/flatmark-construction-device')
out.mkdir(exist_ok=True)
spec = root / 'Benchmarks/Results/iphone-xr-construction/project.json'
(out / 'project.json').write_text(spec.read_text().replace('${REPOSITORY}', str(root)))
PY
xcodegen generate --spec /tmp/flatmark-construction-device/project.json \
  --project /tmp/flatmark-construction-device
```

When the construction harness changes, regenerate `Host/Benchmark.swift` from
`Construction/main.swift`: keep imports, fixtures, and helpers at file scope; remove only the
macOS-only preview dispatch; wrap the timed loop from `let clock = ContinuousClock()` to the end
in `public func runBenchmark() { ... }`. Leave measured work unchanged. The
[ContentView adapter](DeviceHost/ContentView.swift) runs it in a detached task and exports CSV.
Archive the exact adapted host, project settings, source hashes, and dependency lockfile.

## Record three processes

Build and launch the first process in Release:

```sh
mobilebuildmcp device build-and-run \
  --project-path /tmp/flatmark-construction-device/FlatMarkConstructionDevice.xcodeproj \
  --scheme FlatMarkConstructionDevice --device-id "$DEVICE_ID" \
  --configuration Release --derived-data-path /tmp/flatmark-construction-device-build \
  --extra-args DEVELOPMENT_TEAM="$TEAM_ID" -allowProvisioningUpdates \
  --launch-args run1
```

Keep the app foregrounded until it reports completion. Retrieve its output:

```sh
xcrun devicectl device copy from --device "$DEVICE_ID" \
  --source Documents/benchmark-run1.csv --destination /tmp/iphone-run1.csv \
  --domain-type appDataContainer --domain-identifier dev.flatmark.ConstructionBenchmark
```

Require 15 unique scenario rows, 30 samples each, a nonzero consumed checksum, and the final
`# end=` environment line. Output can remain buffered until completion; an empty or partial file
is not a completed run. Check that minimum ≤ median ≤ p95 and all values are finite.

Stop the reported process with `mobilebuildmcp device stop --device-id "$DEVICE_ID" --process-id <PID>`.
Launch the next process:

```sh
mobilebuildmcp device launch --device-id "$DEVICE_ID" \
  --bundle-id dev.flatmark.ConstructionBenchmark --launch-args run2
```

Repeat for `run3`, retrieving each output separately. Checksums must agree across all three processes
of the same build. Do not overlap measurements.

Record hardware model, OS, toolchain, Release configuration, revision, power source, thermal
observations, and uncontrolled conditions. Pipe captured tool output through
[scripts/log_sanitizer.py](../scripts/log_sanitizer.py) before archiving it, as the
[benchmark guide](README.md) requires. Preserve incomplete runs as failures, not timing results.
