# macOS rendering measurement

## Outcome

The five preview fixtures measured the eager renderer at revision
`74bda7cb839906da04752f367be24d1c4d361b44`, with the benchmark-host changes identified below.
These historical controls show substantial main-thread mount/layout cost for large documents after
background construction finishes. A subsequent
Window Server capture confirms visible document content, but gives only an upper bound on time to
first visible content, not an exact first-frame timestamp.

The measured renderer and dependencies match that revision. See the
[eager/lazy comparison](lazy-stack-comparison.md) for the later candidate and adoption decision;
the [benchmark guide](README.md#preview-mount-and-visible-content-checkpoint-macos) describes the
current renderer.

## Results

Milliseconds; one process, one warmup and three measured samples per fixture. Values are medians.

| Fixture | Background construction | Main-thread mount/layout | Visible-content capture upper bound |
| --- | ---: | ---: | ---: |
| ordinary, 172 B | 0.604 | 13.611 | 108.699 |
| large-100, 17.2 KB | 41.210 | 1,826.394 | 1,942.280 |
| large-1000, 172 KB | 400.332 | 126,510.796 | 133,931.423 |
| nested, 1,416 B | 1.956 | 664.810 | 806.251 |
| links-tables, 37.1 KB | 15.922 | 5,390.546 | 7,603.972 |

The 172 KB measured mount/layout samples span 116.809–140.346 seconds. Its capture checkpoints span
124.569–150.119 seconds. The capture checkpoint adds deferred display/run-loop work and capture
cost; the difference cannot be attributed solely to rendering.

The process completed all 15 summary rows, with checksum `13388676` and empty stderr. Runtime
preconditions checked background construction and main-thread mounting. Thermal state was nominal
at the recorded checkpoints. Only one process was run; further repeat processes were omitted because
this run took about nine minutes. These results do not establish a performance regression relative
to another revision or a reliable p95.

## Method and environment

- Apple M3 Pro MacBook Pro, 12 cores, 36 GB RAM; macOS 27.0.1 (26A434); Apple Swift 6.4.
- SwiftPM Release build, no debugger; source `74bda7cb839906da04752f367be24d1c4d361b44` plus the
  preview benchmark host archived in `cdc98c6`. Its `PreviewBenchmark.swift` hash matches the
  measured source; its `main.swift` contains the post-measurement dispatch simplification described
  below. The exact measured dispatch patch was not archived; the environment record retains its
  hash and diff size. Dependencies and renderer match the measured base revision.
- Battery power at the environment checkpoint. Background activity and power were not controlled.
- Existing 390 × 844-point content window; vertical scroll view; default font; dark appearance;
  2× capture scale; no image loader. Window creation is outside the intervals.
- Construction runs in `Task.detached`. Snapshot consumption occurs outside all timed intervals.
- Mount/layout begins before creating `NSHostingView`, includes attachment and explicit layout,
  and ends before explicit display or yielding the main actor.
- The capture interval starts at the same mount timestamp, then includes `displayIfNeeded()`, a
  20 ms suspension, and completion of `screencapture -x -o -l <window>`, polled every 5 ms.
- Visually inspected the first measured PNG for every fixture. All five show the expected document
  content rather than an empty window. This is a content-presence check, not a complete UI review.

See [commands and metric definitions](README.md#preview-mount-and-visible-content-checkpoint-macos).
Raw samples and source hashes are in [the baseline directory](Construction/Baselines/render-mount/).
The five inspected screenshots are retained in its `captures/` directory. All 20 captures, including
warmups, remain locally at `/tmp/flatmark-render-captures/` until temporary files are removed.

The final `main.swift` dispatch was simplified after measurement and rebuilt successfully; the
preview benchmark implementation is unchanged. Initial and final source hashes are recorded.

## Interpretation and limits

The capture checkpoint includes screenshot overhead and intentionally waits after synchronous
layout. It confirms that content exists by that checkpoint; it does not locate the earliest frame
or measure physical screen presentation. For the small fixture, capture overhead dominates. Both
mount and capture intervals exclude parsing, so neither is end-to-end source-to-screen latency.

This establishes a historical eager-layout control for the
[later lazy-stack comparison](lazy-stack-comparison.md). This run alone does not demonstrate that
`LazyVStack` fixes the cost. The table is one top-level block, so top-level laziness alone need
not reduce its row-layout work. Scrolling, frame pacing, interaction responsiveness, image-loading
lifecycle, selection, and accessibility were not exercised.

This run measured macOS only. The later comparison records physical iPhone XR measurements.
