# Physical-device rendering diagnostic

This opt-in host measures document construction separately from initial mounting. It does not change
the demo or the consumed library product. `ContentView.swift` serves the separate
construction-only procedure in [the device construction guide](../DeviceConstruction.md).
Keep this adapter separate from the rendering host; the construction procedure calls its
`runBenchmark()` entry point.

## Generate, build and run

Requires XcodeGen, a signing team and a development-enabled iPhone. Discover the device with
`mobilebuildmcp device list`. Run from the repository root:

```sh
bash Benchmarks/DeviceHost/generate.sh
mobilebuildmcp device build-and-run \
  --project-path /tmp/flatmark-render-device/FlatMarkRenderDevice.xcodeproj \
  --scheme FlatMarkRenderDevice --device-id "$DEVICE_ID" \
  --configuration Release --derived-data-path /tmp/flatmark-render-device-build \
  --extra-args DEVELOPMENT_TEAM="$TEAM_ID" -allowProvisioningUpdates \
  --launch-args ordinary
bash Benchmarks/DeviceHost/capture.sh "$DEVICE_ID" ordinary /tmp/flatmark-xr-render
```

Keep the app foregrounded. The generator references the local FlatMark package and extracts the
fixtures and helpers from `Construction/main.swift`; it does not maintain a second fixture generator.
The temporary project uses bundle ID `dev.flatmark.RenderBenchmark` and contains only the rendering
host and generated helpers, not the older construction host.

Stop the reported process with `mobilebuildmcp device stop`, then use `mobilebuildmcp device launch`
with the same device and bundle and a final launch argument of `large-100`, `large-1000`, `nested`, or
`links-tables`. Start `capture.sh` immediately for that fixture. Run sequentially, without a debugger.
Rebuild after changing the renderer; relaunching an installed binary alone does not pick up changes.

## Intervals and capture protocol

Each process runs one fixture: one warmup, then three measured samples. The full-screen window uses
the device's actual bounds and safe areas, with a padded vertical scroll view, default font, no image
loader, and fresh hosting controllers. Construction runs in a detached task; mounting asserts the
main thread. Thread assertions check placement, not responsiveness.

The CSV in `Documents/preview-<fixture>.csv` records progress before expensive stages and synchronizes
each row. It appends a new `run` section on relaunch; compare only the intended section, not every
summary in an accumulated file. Require the current section's checksum and successful completion.

- `construction`: parsing and projection; excludes scheduling, the main-actor hop and consumption.
- `main-mount-layout`: controller creation, root replacement and explicit window/controller layout.
- `visible-capture-upper-bound`: from the same mount start through display yielding, a 100 ms
  suspension, external screenshot capture and acknowledgement receipt. This includes synchronized
  progress writes, polling, file transfer and capture overhead; it is not an exact first-frame time.

After layout, the host writes `Documents/capture-ready.txt`. The capture script polls the marker,
saves a device screenshot, then copies its identifier to `Documents/capture-ack.txt`. The host records
elapsed time only after that acknowledgement. Inspect screenshots for actual content; a successful
capture command alone does not establish that the document is visible.

The script uses `devicectl` for device capture and file transfer because MobileBuildMCP's physical-device
workflow has no corresponding tools. Its default wait for each ready marker is 180 seconds; override
with `FLATMARK_LAYOUT_TIMEOUT`. The host separately times out after 120 seconds waiting for a capture
acknowledgement. `FROM_ITERATION` can resume an interrupted capture driver, but operator delay then
contaminates that sample's upper bound. Rerun rather than compare such a sample.

The script checks progression to the next marker or successful completion after an acknowledgement
transfer error. A transfer message alone is not proof of failure or success.

Large fixtures can exhaust memory or hang during layout. Preserve the partial CSV and record that
failure instead of inventing a timing. Device diagnostics can distinguish Jetsam from a timeout.
There is no automatic crash diagnosis or physical-device scrolling in this harness.

See [current results](../Results/README.md) for measurements and limitations.
