# Construction benchmarks

Opt-in benchmarks measure `FlatMarkDocument` construction, separately from SwiftUI rendering. They
cover ordinary descriptions, large documents, nested lists and quotes, and link/table-heavy content.

## Findings

Retain a `FlatMarkDocument` while its source and projection inputs are unchanged. Reusing it avoids
parsing and projection; constructing a new snapshot does not.

Medians across three processes on an Apple M3 Pro, in milliseconds:

| Fixture | Initial | Source change | Base URL change |
| --- | ---: | ---: | ---: |
| Ordinary, 172 B | 0.410–0.415 | 0.449–0.457 | 0.398–0.416 |
| Large, 17.2 KB | 38.244–41.365 | 37.390–41.064 | 38.847–40.638 |
| Large, 172 KB | 386.811–387.431 | 387.574–390.288 | 381.154–391.887 |
| Nested | 1.677–1.720 | 1.720–1.843 | 1.675–1.773 |
| Links and tables | 13.713–13.752 | 13.713–13.887 | 13.508–14.325 |

A 60 Hz frame lasts 16.7 ms, with only part of it available for construction, and the 17.2 KB and
172 KB fixtures exceed that budget outright. This supports host-owned background construction for large
or frequently changing sources while the synchronous snapshot API stays as it is. No async state machine
or optimization is included.

These numbers do not establish a safe maximum source size, typing latency, or performance on other
Apple devices. See the [iPhone XR report](iPhone-XR.md) for device execution and limits.

## Run

Use a toolchain meeting the [package requirements](../README.md#requirements) and a Release build
from the repository root:

```sh
swift build --product FlatMarkConstructionBenchmark --configuration release
```

Then run the executable three times sequentially, saving stdout:

```sh
.build/release/FlatMarkConstructionBenchmark > /tmp/flatmark-run1.csv
.build/release/FlatMarkConstructionBenchmark > /tmp/flatmark-run2.csv
.build/release/FlatMarkConstructionBenchmark > /tmp/flatmark-run3.csv
```

Do not overlap runs; keep power, thermal conditions, and background work comparable. If a launcher
times out, check whether its process is still running before starting another. Each completed run has
20 scenario rows plus comments, and a nonzero consumed-result checksum; checksums should agree within
a build.

## Method

Each scenario takes five warmups and 30 samples with `ContinuousClock`, reported in milliseconds as
upper-middle median, nearest-rank p95, and minimum. This measures warmed construction, not process
startup.

| Scenario | Work measured |
| --- | --- |
| `initial` | Fresh snapshot |
| `source-change` | Fresh snapshot after appending `\nUpdated description.\n` (22 bytes) |
| `baseURL-change` | Fresh snapshot with `/archive/` instead of `/tasks/` as URL base |
| `retained-copy-per-value` | Per-value cost of 1,000 copies into a preallocated array |

Construction includes parsing, projection, and allocation, but excludes input generation, result
consumption, snapshot destruction, and rendering. Changed inputs reconstruct; this is not incremental
parsing. Retained-copy timings measure array copy/retain overhead, not view refresh or equality.

Outside each interval, a non-inlined consumer reflects the snapshot into the printed checksum to prevent
optimized code from discarding projection. Reflection perturbs allocator/cache state: these are diagnostic
timings, not memory measurements. The no-reparse contract also follows from code:
`FlatMarkView(document:)` reads the retained projection; `FlatMarkDocument.init` constructs it.

## Fixtures

Fixtures are generated deterministically in `Construction/main.swift`, with no network or file input.
All start from `https://example.com/tasks/`.

| Fixture | Parameters | UTF-8 bytes |
| --- | --- | ---: |
| `ordinary` | Heading, prose, mention, relative link, two tasks, quote | 172 |
| `large-100` | 100 ordinary sections | 17,200 |
| `large-1000` | 1,000 ordinary sections | 172,000 |
| `nested` | 32 quote levels, then a separate 32-level list | 1,416 |
| `links-tables` | Three columns, 500 rows, 1,500 relative links | 37,107 |

Mentions inside link labels are excluded by library semantics. Synthetic stress cases do not represent
a distribution of user documents.

## Desktop baseline

Recorded 2026-11-09 on Apple M3 Pro, arm64, 12 cores, 36 GiB RAM; macOS 27.0.1 (26A434); Xcode 27.0
(27A266a), Apple Swift 6.4; SwiftPM Release with default optimization. Source revision:
`Construction/Baselines/revision.txt`. Dependency resolution is in `Package.resolved`.

Three sequential standalone processes produced `Construction/Baselines/m3-pro-run{1,2,3}.csv`.
Retained-copy medians were 0.000015–0.000016 ms per value, and all three checksums agreed. Median
spreads stayed under 10%; the largest p95 was 448.510 ms (large, base URL change). Power, thermal
state, and background activity were not controlled or instrumented, so desktop figures are not mobile
performance claims.

Mention detection is unconditional. Earlier optional-mention `initial` figures (about 0.06 ms for the
ordinary fixture) are obsolete; use the table above.

## Regression checks

Use periodic local measurement, not CI timing assertions. Rerun after parser, projector, dependency,
or toolchain changes, or when investigating latency. Record hardware, OS, toolchain, configuration,
revision, and fixture changes, and rebaseline separately when the environment changes.

Compare the median of three process medians per scenario. Investigate an increase exceeding **both 20%
and 0.1 ms**, then confirm with another three-run set. The relative margin exceeds observed
substantial-case variation; the absolute floor filters tiny-description noise. Inspect p95s too, but do
not gate on a single tail sample. This is an investigation threshold, not a responsiveness guarantee.
Retained reuse is a structural contract, not a nanosecond timing gate.
