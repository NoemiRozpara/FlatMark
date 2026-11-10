# Top-level lazy-stack comparison

## Decision

The lazy candidate substantially reduces initial mounting of long, many-block documents. It also
introduces reproducible macOS reflow and image-lifecycle test failures. The renderer was restored to
its original eager implementation after measurement, then **the measured lazy candidate was reapplied
at the user's request for a documentation commit and subsequent revert**. The working tree therefore
contains the known-failing candidate. Do not treat it as a completed, regression-free implementation.

The measured candidate is retained as
[`top-level-lazy.patch`](Construction/Baselines/lazy-comparison/top-level-lazy.patch). It makes only
the document's top-level block stack lazy. Block quotes keep eager stacks; list entries and table
rows are unchanged. It retains policy filtering and projected block IDs. There is no public API,
parser, demo, loading-state, or dependency change.

Resolve the reflow and image-lifecycle failures before enabling this candidate. Adding a public
layout mode or weakening existing behavior requires a separate decision; neither was done here.

## Physical iPhone XR

Release builds, no debugger, iOS 18.7.11 (22H384), actual 414 × 896-point screen at 2× scale. Captures
are 828 × 1792 pixels. The host uses safe areas and 16-point SwiftUI padding, not the desktop's
390 × 844-point viewport. Each completed fixture has one warmup and three measured samples in one
process per variant. Times below are medians in milliseconds; do not compare across platforms.

| Fixture | Eager mount/layout | Lazy mount/layout | Eager capture upper bound | Lazy capture upper bound |
| --- | ---: | ---: | ---: | ---: |
| ordinary, 172 B | 46.736 | 52.020 | 1,134.424 | 1,125.506 |
| large-100, 17.2 KB | 2,284.428 | 85.456 | 6,265.093 | 3,676.737 |
| large-1000, 172 KB | No completed mount: Jetsam | 86.086 | Not available | 2,376.179 |
| nested, 1,416 B | First mount interrupted | First mount terminated | Not available | Not available |
| links-tables, 37.1 KB | 10,853.249 | 10,391.589 | 17,064.517 | 17,024.616 |

The many-block 17.2 KB fixture mounted about 27× faster in this run. The 172 KB lazy case completed
all four mounts and produced visible content; no eager speedup ratio exists because the eager case
failed. The table remains one expensive top-level block, so laziness does not make its 500 rows lazy.
The small fixture shows no initial-mount benefit.

### Incomplete and contaminated runs

- Eager `large-1000` completed construction in 1,155.866 ms, then stopped during its first mount.
  The matching Jetsam event identifies `FlatMarkRenderDevice`, PID 763, as the largest process and
  gives reason `per-process-limit`. This is a memory-limit termination, not a measured mount time.
- Eager `nested` remained in its first mount for more than two minutes. The run was stopped manually;
  its partial CSV has no mount duration, checksum or successful completion. It is not a timing sample.
- Lazy `nested` also never completed its first mount. The matching PID 1026 crash reports a scene-update
  watchdog termination (`0x8BADF00D`), background visibility and serious thermal state. The CSV recorded
  fair thermal state at startup. This is an incomplete, thermally/background-confounded case, not a
  controlled eager/lazy timing comparison or proof of the same failure mechanism as Jetsam.
- The first eager `large-100` capture driver was interrupted by a transfer readback error. Manual
  resumption inflated a capture sample to 77 seconds. That run is retained as
  `preview-large-100-interrupted-capture.csv` and excluded from the comparison table. A fresh process
  completed an uninterrupted repeat. Use the **last `run` section** of `ios-eager/preview-large-100.csv`.
- Device CSVs append across launches and app reinstalls preserve data. Lazy ordinary, large-100 and
  links-tables CSVs therefore also contain earlier eager sections. The comparison uses only each
  file's last run section. Both successful variants have matching per-fixture checksums.

## macOS

Same M3 Pro machine, Swift 6.4 and macOS 27.0.1 as
[the preceding eager baseline](render-mount-results.md). Same benchmark host, five sources, viewport,
Release configuration, one warmup and three measured samples. The eager data is that completed prior
run, not another nine-minute eager repetition. Lazy data is one later process. Milliseconds:

| Fixture | Eager mount/layout | Lazy mount/layout | Eager capture upper bound | Lazy capture upper bound |
| --- | ---: | ---: | ---: | ---: |
| ordinary | 13.611 | 9.567 | 108.699 | 109.290 |
| large-100 | 1,826.394 | 32.390 | 1,942.280 | 126.187 |
| large-1000 | 126,510.796 | 32.769 | 133,931.423 | 140.795 |
| nested | 664.810 | 67.270 | 806.251 | 532.986 |
| links-tables | 5,390.546 | 3,535.372 | 7,603.972 | 4,273.200 |

Both processes completed all 15 summary rows with checksum `13388676`. The lazy process had empty
stderr and nominal endpoint thermal state. Reduced initial cost is deferred work, not evidence of
lower total full-document work or smooth scrolling. The small sample set does not establish a
reliable p95 or performance threshold.

## Regression checks: blockers

Ran `swift test` with the exact original eager renderer and with the lazy candidate:

| Renderer | Tests | Reported issues, including one known issue |
| --- | ---: | ---: |
| Original eager control | 189 | 37 |
| Lazy candidate | 189 | 46 |

The eager control already fails snapshot comparisons and eight isolated HTML-navigation-host cases
in this environment. The full suite is not green for either variant. These existing failures were
not repaired or re-recorded in this experiment.

Two existing tests isolate candidate regressions without relying on the full suite:

```sh
swift test --filter 'retainedParagraphReflowsNarrowWideNarrowWithoutOverlappingItsNeighbor|reverseCompletionsStayInSourceOrderAndResizeWithoutReloading'
```

- **Native paragraph reflow:** after widening the host from 140 to 400 points, the lazy candidate keeps
  a paragraph at 140 points, loses the second native paragraph from the mounted export, and fails
  geometry/reflow assertions. Showing the window during a temporary diagnostic did not fix it. Adding
  a flexible-width frame to every block also did not fix it; neither probe was retained.
- **Image lifecycle:** the lazy candidate fails the reverse-completion wording and exact two-request
  assertions while resizing a single paragraph. This reproduces in isolation; the precise lifecycle
  cause is not yet established.

The original eager renderer passes both tests together (two tests, zero issues). The saved lazy logs
show five reflow issues and two image issues. No existing test assertions or reference images were
changed. Other new failures involve whole-document native exports and readiness expectations that
assume eager realization. Those need viewport-aware investigation, not automatic dismissal or blanket
baseline replacement.

## Evidence, limits and reproduction

- Raw CSVs, compact diagnostic summaries, source hashes, test logs and inspected screenshots:
  [`Construction/Baselines/lazy-comparison/`](Construction/Baselines/lazy-comparison/).
- Device host generation, launch and capture protocol:
  [DeviceHost/README.md](DeviceHost/README.md).
- Desktop command and metric definitions:
  [benchmark guide](README.md#preview-mount-and-visible-content-checkpoint-macos).
- To reproduce the candidate, inspect and apply `top-level-lazy.patch`, then rebuild each target.
  `git apply --check` succeeds against the restored production source. The final local desktop
  benchmark executable was rebuilt against the restored eager renderer.

Visually inspected the first measured capture for each completed iOS fixture/variant and each macOS
lazy fixture. They show expected content. Only those representative captures are retained in the
repository. Remaining device captures are local under `/tmp/flatmark-lazy-comparison-captures/`;
remaining desktop captures are under `/tmp/flatmark-lazy-mac-captures/`.

Capture timings are **upper bounds on time to first visible content**, not first-frame timestamps.
On iOS they include a 100 ms suspension, two-second marker polling, screenshot work, file transfer
and acknowledgement polling. That overhead dominates small fixtures and can vary between samples.
On macOS the checkpoint includes a 20 ms yield and local screen capture. Neither measures physical
scanout, source-to-screen latency, GPU time or frame rate. Parsing is outside both mount and capture
intervals. Do not interpret the capture differences as pure rendering-time differences.

Device charging, battery, clock speed, background activity and ambient temperature were not controlled.
Low Power Mode was off in the recorded startup rows; nominal startup thermal state does not establish
stable conditions throughout a run. Some macOS package checks overlapped device measurements, so host
capture transport was not isolated from that work. Physical-device capture and file transfer used
`devicectl` because MobileBuildMCP lacks those device tools. No appearance, accessibility, orientation
or viewport settings were changed. The temporary host disabled auto-lock during each run; its process
is no longer running. No scrolling, task gestures, selection or live VoiceOver checks were performed.
