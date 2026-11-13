# Current benchmark results

Recorded on **2026-11-13** from FlatMark commit
`2775a791f073d4c272bce5833eef10abdc4a8f12` (0.1.0), in Release, with unchanged library,
construction harness, device hosts, fixtures, manifest, and lockfile throughout measurement.
Sanitizer and guide edits made during recording were uncommitted; no measured input changed.

These results describe this source and these environments, not all supported devices or OS versions.
See the [benchmark guide](../README.md) for fixtures, interval definitions, and regression policy.

## Environment and source record

| | Mac | Physical iPhone |
| --- | --- | --- |
| Hardware | Apple M3 Pro, 12 CPU cores, 36 GiB memory | iPhone XR (`iPhone11,8`) |
| OS | macOS 27.0.1 (26A434) | iOS 18.7.12 (22H390) |
| Build toolchain | Xcode 27.0 (27A266a), Swift 6.4 | Same host and toolchain |
| Power | Battery power; no charger connected | Wired USB for the whole set; battery level and charging state not collected |
| Construction thermal observations | Not sampled by the construction-only harness | Runs started fair, serious, fair; all three ended serious |
| Preview thermal observations | Nominal at process start and end | ordinary serious; large-100, large-1000, and nested nominal; links/tables fair |
| Preview host | 390 × 844-point content window, 2x capture | Actual 414 × 896-point screen, safe areas, padded content, 2x capture |
| Appearance | Dark | Dark |

Power, thermals, and background activity were not controlled. Runs were sequential, without a debugger.
The XR preview set was not thermally matched to its construction set or to the Mac. The device stayed
above nominal through the construction set even after a 15-minute idle period, and the warmest processes
were also the slowest. Its table timing was recorded after the nested-fixture timeout, at a fair start.
Do not treat these as nominal-thermal device performance or compare device speed ratios from these runs.

- [Source hashes and toolchain](snapshot.json), including harness, fixtures, manifest, and lockfile hashes.
- [Dependency lockfile](Package.resolved). Both device builds' resolved dependency revisions matched it.
- Construction metadata: [Mac](macos-construction/environment.json), [XR](iphone-xr-construction/environment.json).
- Preview metadata: [Mac](macos-preview/environment.json), [XR](iphone-xr-preview/environment.json).
- Exact device hosts and sanitized project specifications: [construction](iphone-xr-construction),
  [preview](iphone-xr-preview). Project placeholders avoid recording checkout paths and signing identities.

Both device builds succeeded with a missing SwiftShims precompiled-module-file warning. Their apps
installed and launched. Sanitized build summaries are retained alongside the results. Automatic signing
matched an existing wildcard iOS App Development profile for the recorded team, so no provisioning update
was requested; one attempt with `-allowProvisioningUpdates` failed before measurement because the host's
stored Apple-account session was rejected.

## Construction

Each platform ran **three processes**, with five warmups and 30 measured samples per scenario.
All 15 scenarios completed in every process; each produced checksum `351684165`.
Both result sets passed row, sample-count, timing-order, finite-value, and checksum validation.

Values below are the **median of three process medians**, in milliseconds. Device construction runs in
a detached task. Timed work includes parsing, projection, and allocation, but not rendering,
reflection-based result consumption, or snapshot destruction.

| Fixture | Mac initial | Mac source change | Mac base URL change | XR initial | XR source change | XR base URL change |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Ordinary, 172 B | 0.381 | 0.425 | 0.396 | 1.207 | 1.309 | 1.172 |
| Large, 17.2 KB | 37.314 | 36.903 | 36.662 | 113.417 | 113.223 | 113.279 |
| Large, 172 KB | 374.534 | 376.776 | 375.971 | 1201.313 | 1402.965 | 1391.104 |
| Nested, 1,416 B | 1.665 | 1.712 | 1.659 | 6.073 | 5.898 | 6.097 |
| Links/tables, 37,107 B | 13.483 | 13.429 | 13.410 | 46.054 | 46.055 | 46.342 |

Raw medians, p95s, and minima:

- Mac: [run 1](macos-construction/run1.csv), [run 2](macos-construction/run2.csv),
  [run 3](macos-construction/run3.csv), [validation](macos-construction/summary.json).
- XR: [run 1](iphone-xr-construction/run1.csv), [run 2](iphone-xr-construction/run2.csv),
  [run 3](iphone-xr-construction/run3.csv), [validation](iphone-xr-construction/summary.json).

Retaining a document avoids this construction work while source and projection inputs remain unchanged.
The large fixtures exceed a full 16.7 ms frame interval on both measured devices. This does not establish
a universal source-size limit, UI stall duration, or typing latency.

## Initial preview mounting

One process covered all Mac fixtures. On the XR, each fixture used a separate process, launched with a
short idle gap between fixtures. Each completed fixture had one warmup and three measured samples. The
table reports **three-sample medians**, in milliseconds; p95 in the raw output is the maximum of three
samples, not a reliable tail estimate. Do not substitute this mode's construction column for the 30-sample
construction baseline.

| Fixture | Mac background construction | Mac mount/layout | Mac capture checkpoint | XR background construction | XR mount/layout | XR capture checkpoint |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Ordinary | 0.626 | 9.158 | 113.790 | 8.579 | 48.364 | 1141.386 |
| Large, 100 sections | 38.585 | 27.520 | 133.153 | 155.958 | 82.561 | 3645.642 |
| Large, 1,000 sections | 367.528 | 30.095 | 142.429 | 1221.057 | 83.952 | 2370.622 |
| Nested | 1.977 | 50.736 | 152.077 | Incomplete | Incomplete | Incomplete |
| Links/tables | 14.673 | 3226.617 | 3895.077 | 80.603 | 10532.403 | 16574.110 |

The intervals start separately: background construction is excluded from mount/layout and capture.
The capture checkpoint starts at mounting, not after layout. Mac capture includes a 20 ms suspension,
Window Server capture, and polling. XR capture includes a 100 ms suspension, external screenshot
transport, polling, and acknowledgement. These are **not exact first-frame timestamps**, physical-display
measurements, source-to-screen latency, or comparable cross-platform capture protocols.

Raw results and status:

- Mac: [all fixtures](macos-preview/run1.csv), [validation](macos-preview/summary.json).
- XR: [ordinary](iphone-xr-preview/preview-ordinary.csv),
  [100 sections](iphone-xr-preview/preview-large-100.csv),
  [1,000 sections](iphone-xr-preview/preview-large-1000.csv),
  [nested partial output](iphone-xr-preview/preview-nested.csv),
  [links/tables](iphone-xr-preview/preview-links-tables.csv), [status](iphone-xr-preview/summary.json).

### XR nested failure

The 32-level quote/list fixture completed background construction for its warmup, then logged
`before_main_mount_layout`. It produced no layout result, capture-ready marker, screenshot, checksum,
or completion row. The capture driver timed out waiting for `nested-0` after its 180-second wait limit.
The process was then stopped. No measured sample completed, and no retry was made. The cause and
eventual completion time remain unknown; it remains tracked in
[#78](https://github.com/NoemiRozpara/FlatMark/issues/78).

The partial CSV and [capture-driver log](iphone-xr-preview/capture-nested.log) preserve the failure.
This run does not establish whether layout would eventually complete or identify a watchdog or
memory-termination cause. The XR preview set is explicitly incomplete; its summary is not marked
`complete: true`.

### Capture inspection and limits

The first measured screenshot of every completed fixture was inspected with Apple Vision text
recognition over the PNG, and the recognized strings were checked against the fixture source. Document
content is present in all nine inspected screenshots: heading, prose, mention, task list, and quote text
for ordinary and both large fixtures, quote and list levels for nested, and the table header plus
first-column cells for links/tables. Per fixture, captures 0-3 are byte-identical on the Mac, and their
pixels match below the top 100-pixel status-bar region on the XR, which was excluded from that comparison.
The two large fixtures share one capture hash on both platforms, because only the top of the document is
in view. All original captures are retained: [Mac](macos-preview/captures),
[XR](iphone-xr-preview/captures).

Both table captures recognize only the first column: the second and third columns are absent, which shows
horizontal clipping. These observations establish visible content at the capture checkpoint, not correct
whole-document geometry, and text recognition is not a pixel-level rendering assertion. No scrolling,
selection, link activation, VoiceOver, or later-frame performance was measured. Synthetic stress fixtures
do not represent a user-document distribution, and these runs do not qualify minimum-platform behavior.
