# Current benchmark results

Recorded on **2026-11-12** from FlatMark commit
`d02a16ae81e45de63ca9baefebb7cd4e476dde32`, in Release, with unchanged library and construction-harness
inputs throughout measurement. Documentation edits were uncommitted. The device construction adapter
is preserved under [Host](iphone-xr-construction/Host); no timed construction work was changed.

These results describe this source and these environments, not all supported devices or OS versions.
See the [benchmark guide](../README.md) for fixtures, interval definitions, and regression policy.

## Environment and source record

| | Mac | Physical iPhone |
| --- | --- | --- |
| Hardware | Apple M3 Pro, 12 CPU cores, 36 GiB memory | iPhone XR (`iPhone11,8`) |
| OS | macOS 27.0.1 (26A434) | iOS 18.7.12 (22H390) |
| Build toolchain | Xcode 27.0 (27A266a), Swift 6.4 | Same host and toolchain |
| Power | Battery power | Wired USB; charging indicator visible in preview captures |
| Construction thermal observations | Not sampled by the construction-only harness | Nominal at each process start; first two ended nominal, third ended fair |
| Preview thermal observations | Nominal throughout | Fair at the start of ordinary, large, and nested fixtures; serious at the start of links/tables |
| Preview host | 390 × 844-point content window, 2x capture | Actual 414 × 896-point screen, safe areas, padded content, 2x capture |
| Appearance | Dark | Dark |

Power, thermals, and background activity were not controlled. Runs were sequential, without a debugger.
The XR preview set was not thermally matched to its construction set or the Mac. Its table timing was
recorded after the nested-fixture timeout, with serious thermal state. Do not treat it as nominal-thermal
performance or compare device speed ratios from these runs.

- [Source hashes and toolchain](snapshot.json), including harness, fixtures, manifest, and lockfile hashes.
- [Dependency lockfile](Package.resolved). Both device builds' resolved dependency revisions matched it.
- Construction metadata: [Mac](macos-construction/environment.json), [XR](iphone-xr-construction/environment.json).
- Preview metadata: [Mac](macos-preview/environment.json), [XR](iphone-xr-preview/environment.json).
- Exact device hosts and sanitized project specifications: [construction](iphone-xr-construction),
  [preview](iphone-xr-preview). Project placeholders avoid recording checkout paths and signing identities.

Both device builds succeeded with a missing SwiftShims precompiled-module-file warning. Their apps
installed and launched. Sanitized build summaries are retained alongside the results.

## Construction

Each platform ran **three processes**, with five warmups and 30 measured samples per scenario.
All 15 scenarios completed in every process; each produced checksum `351684165`.
Both result sets passed row, sample-count, timing-order, finite-value, and checksum validation.

Values below are the **median of three process medians**, in milliseconds. Device construction runs in
a detached task. Timed work includes parsing, projection, and allocation, but not rendering,
reflection-based result consumption, or snapshot destruction.

| Fixture | Mac initial | Mac source change | Mac base URL change | XR initial | XR source change | XR base URL change |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Ordinary, 172 B | 0.406 | 0.452 | 0.403 | 1.221 | 1.312 | 1.170 |
| Large, 17.2 KB | 39.003 | 38.242 | 39.009 | 113.197 | 116.003 | 124.966 |
| Large, 172 KB | 388.317 | 385.261 | 388.201 | 1252.230 | 1266.840 | 1277.457 |
| Nested, 1,416 B | 1.691 | 1.735 | 1.687 | 5.640 | 5.804 | 5.632 |
| Links/tables, 37,107 B | 13.689 | 13.644 | 13.646 | 42.526 | 41.825 | 41.477 |

Raw medians, p95s, and minima:

- Mac: [run 1](macos-construction/run1.csv), [run 2](macos-construction/run2.csv),
  [run 3](macos-construction/run3.csv), [validation](macos-construction/summary.json).
- XR: [run 1](iphone-xr-construction/run1.csv), [run 2](iphone-xr-construction/run2.csv),
  [run 3](iphone-xr-construction/run3.csv), [validation](iphone-xr-construction/summary.json).

Retaining a document avoids this construction work while source and projection inputs remain unchanged.
The large fixtures exceed a full 16.7 ms frame interval on both measured devices. This does not establish
a universal source-size limit, UI stall duration, or typing latency.

## Initial preview mounting

One process covered all Mac fixtures. On the XR, each fixture used a separate process. Each completed
fixture had one warmup and three measured samples. The table reports **three-sample medians**, in
milliseconds; p95 in the raw output is the maximum of three samples, not a reliable tail estimate.
Do not substitute this mode's construction column for the 30-sample construction baseline.

| Fixture | Mac background construction | Mac mount/layout | Mac capture checkpoint | XR background construction | XR mount/layout | XR capture checkpoint |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Ordinary | 0.620 | 7.933 | 108.413 | 8.933 | 49.509 | 1138.088 |
| Large, 100 sections | 39.790 | 28.327 | 134.932 | 159.896 | 82.535 | 3624.830 |
| Large, 1,000 sections | 389.686 | 31.773 | 145.410 | 1214.606 | 84.006 | 2366.746 |
| Nested | 1.981 | 53.503 | 156.793 | Incomplete | Incomplete | Incomplete |
| Links/tables | 14.991 | 3283.903 | 3947.636 | 79.262 | 11481.043 | 16715.003 |

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
The process was then stopped. No measured sample completed, and no retry was made.

The partial CSV and [capture-driver log](iphone-xr-preview/capture-nested.log) preserve the failure.
This run does not establish whether layout would eventually complete or identify a watchdog or
memory-termination cause. The XR preview set is explicitly incomplete; its summary is not marked
`complete: true`.

### Capture inspection and limits

The first measured screenshot of every completed fixture was visually inspected. Document content is
visible in all nine inspected screenshots. Mac measured captures 1–3 are byte-identical per fixture.
On the XR, their pixels match below the top 100-pixel status-bar region, which was excluded from the
comparison. All original captures are retained: [Mac](macos-preview/captures), [XR](iphone-xr-preview/captures).

Both table captures show horizontal clipping. These observations establish visible content at the
capture checkpoint, not correct whole-document geometry. No scrolling, selection, link activation,
VoiceOver, or later-frame performance was measured. Synthetic stress fixtures do not represent a
user-document distribution, and these runs do not qualify minimum-platform behavior.
