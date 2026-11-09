# Construction benchmarks

Opt-in benchmarks measure `FlatMarkDocument` construction independently of SwiftUI rendering.
They cover ordinary descriptions, large documents, nested lists/quotes, and link/table-heavy content.

## Findings

Retain a `FlatMarkDocument` when its source and projection inputs are unchanged. Reusing it avoids
parsing and projection; constructing a new snapshot does not.

Ordinary descriptions were inexpensive on both measured devices. Larger documents can exceed a
UI frame budget, particularly with mention detection:

| Fixture | M3 Pro: default / mentions | iPhone XR: default / mentions |
| --- | ---: | ---: |
| Ordinary, 172 B | 0.054–0.071 / 0.407–0.413 ms | 0.141–0.146 / 1.178–1.185 ms |
| Large, 17.2 KB | 4.680–4.772 / 38.244–38.557 ms | 11.720–12.525 / 113.635–113.855 ms |
| Large, 172 KB | 47.680–48.189 / 382.319–387.078 ms | 118.387–128.795 / 1162.302–1265.196 ms |

Values are ranges of medians across three processes. A 60 Hz frame lasts 16.7 ms, with only part
of that available for construction. These results support evaluating host-owned background
construction for large or frequently changing sources, while preserving the synchronous snapshot
API. No async state machine or optimization is included.

The results do not establish a safe maximum source size, actual typing latency, or performance on
all Apple devices. See the [iPhone XR report](iPhone-XR.md) for device execution and limitations.

## Run

Use a toolchain meeting the [package requirements](../README.md#requirements) and a Release build from the repository root:

```sh
swift build --product FlatMarkConstructionBenchmark --configuration release
```

After building, run the executable three times sequentially and save stdout:

```sh
.build/release/FlatMarkConstructionBenchmark > /tmp/flatmark-run1.csv
.build/release/FlatMarkConstructionBenchmark > /tmp/flatmark-run2.csv
.build/release/FlatMarkConstructionBenchmark > /tmp/flatmark-run3.csv
```

Do not overlap runs. Keep power, thermal conditions, and background work comparable. If a launcher
times out, check whether its process is still running before starting another. Each completed run
has 25 scenario rows and a nonzero consumed-result checksum; checksums should agree within a build.
The output includes comments and metadata alongside CSV rows.

## Method

Each scenario uses five warmups and 30 samples timed with `ContinuousClock`. Output reports
milliseconds: upper-middle median, nearest-rank p95, and minimum. This measures warmed construction,
not process startup.

| Scenario | Work measured |
| --- | --- |
| `initial` | Fresh snapshot |
| `source-change` | Fresh snapshot after appending `\nUpdated description.\n` (22 bytes) |
| `baseURL-change` | Fresh snapshot with `/archive/` instead of `/tasks/` as URL base |
| `retained-copy-per-value` | Per-value cost of 1,000 copies into a preallocated array |

Mention detection is now always enabled. Historical baselines below include a `mentions-change`
scenario from when detection was optional; new runs omit that scenario.

Construction includes parsing, projection, and returned-document allocation. Input generation,
result consumption, final snapshot destruction, and all rendering are excluded. Changed-input
scenarios reconstruct; they do not measure incremental parsing.

After each interval, a non-inlined consumer reflects the complete snapshot, including its private
projection, and adds its length to a printed checksum. This prevents consuming only the source
while optimized code discards projection. Reflection affects allocator/cache state between samples;
these are diagnostic timings, not peak-memory or isolated allocator measurements.

The retained-copy scenario measures array/copy/retain overhead, not SwiftUI refresh or parser
latency. The no-reparse contract also follows from the code: `FlatMarkView(document:)` reads the
retained projection; `FlatMarkDocument.init` is the only production string-projector caller.
Total construction cost answers the latency question, so parsing and projection are not timed
separately. The mention-enabled slowdown is not a diagnosis of its internal cause.

## Fixtures

Fixtures are generated deterministically in `Construction/main.swift`, without network or file input.
All use `https://example.com/tasks/` as the initial base URL.

| Fixture | Parameters | UTF-8 bytes |
| --- | --- | ---: |
| `ordinary` | Heading, prose, mention, relative link, two tasks, quote | 172 |
| `large-100` | 100 ordinary sections | 17,200 |
| `large-1000` | 1,000 ordinary sections | 172,000 |
| `nested` | 32 quote levels, then a separate 32-level list | 1,416 |
| `links-tables` | Three columns, 500 rows, 1,500 relative links | 37,107 |

Mentions inside link labels are excluded by library semantics. Synthetic stress cases do not
represent a measured distribution of user documents.

## Desktop baseline

Recorded 2026-10-28: Apple M3 Pro, arm64, 36 GiB RAM; macOS 27.0.1 (26A434); Xcode 27.0 RC
(27A266a), Apple Swift 6.4 (`swiftlang-6.4.0.34.1`); SwiftPM Release with default optimization.
Source base revision: `Construction/Baselines/revision.txt`. The measured working tree includes
the benchmark implementation. Dependency resolution is recorded in `Package.resolved`.

Three sequential standalone processes produced `Construction/Baselines/m3-pro-run{1,2,3}.csv`:

| Fixture | Initial | Source change | Base URL change | Mentions enabled |
| --- | ---: | ---: | ---: | ---: |
| ordinary | 0.054–0.071 | 0.060–0.069 | 0.055–0.061 | 0.407–0.413 |
| large-100 | 4.680–4.772 | 4.655–4.753 | 4.633–4.765 | 38.244–38.557 |
| large-1000 | 47.680–48.189 | 47.669–50.090 | 47.774–48.486 | 382.319–387.078 |
| nested | 0.305–0.308 | 0.309–0.312 | 0.306–0.310 | 1.664–1.695 |
| links-tables | 13.470–14.343 | 13.235–14.861 | 13.329–14.570 | 13.367–14.716 |

Ranges are process medians in milliseconds. Retained-copy medians were 0.000014–0.000015 ms/value.
Construction spreads were below 13%, except ordinary initial construction (33%, only 0.018 ms
absolute). The large source-change p95 reached 72.991 ms. Background activity, power, and thermal
state were not controlled or instrumented. Desktop figures are not mobile performance claims.

## Regression checks

Use periodic local measurement, not CI timing assertions. Rerun after parser/projector, dependency,
or toolchain changes, or when investigating latency. Record hardware, OS, toolchain, configuration,
revision, and fixture changes; rebaseline separately when the environment changes.

Compare the median of three process medians for each construction scenario. Investigate an increase
exceeding **both 20% and 0.1 ms**, then confirm with another three-run set. The relative margin
exceeds observed substantial-case variation; the absolute floor filters tiny-description noise.
Inspect p95s too, but do not gate on one tail sample. This is an investigation threshold, not a
responsiveness guarantee. Retained reuse is a structural contract, not a nanosecond timing gate.
