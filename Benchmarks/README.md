# Benchmarks

Opt-in Release benchmarks measure `FlatMarkDocument` construction and initial SwiftUI preview
mounting separately on macOS and a physical iPhone XR. They cover ordinary descriptions, large
documents, nested lists and quotes, and link/table-heavy content.

## Current results

See [Results](Results/README.md) for the recorded environment, construction summary, preview summary,
raw measurements, and limitations. Results apply only to the recorded source and environment.

Retain a `FlatMarkDocument` while its source and projection inputs are unchanged. Reusing it avoids
parsing and projection, not layout or rendering. Construction timings do not establish a safe maximum
source size, typing latency, or source-to-screen latency.

## Known performance limits

The [recorded XR nested-content run](Results/README.md#xr-nested-failure) did not finish mounting
within the capture driver's 180-second wait. The fixture contains a 32-level quote followed by a
separate 32-level list. The cause and eventual completion time remain unknown. The maintainer accepts
this recorded timeout as a known 0.1.0 limitation; [#78](https://github.com/NoemiRozpara/FlatMark/issues/78)
tracks the investigation.

Large tables also mount eagerly; the recorded 500-row table took about 3.28 seconds on the Mac and
11.48 seconds on the XR, with the environment qualifications in the results. These observations do
not establish safe source-size or nesting limits. Hosts must choose their own content/resource
budgets; FlatMark does not truncate content or impose a depth cap.

The XR timeout acceptance does not waive other failures or qualify any other release candidate. Record its
scope and rationale in the external release record required by the
[release checklist](../Documentation/Releasing.md). [#82](https://github.com/NoemiRozpara/FlatMark/issues/82) tracks
post-squash measurements; keep the existing failures visible until new evidence supersedes them.

## Run

Use a toolchain meeting the [package requirements](../README.md#requirements) on macOS. The
recommended workflow needs Python 3 and a new output directory:

```sh
python3 scripts/benchmark-construction.py /tmp/flatmark-construction-results
```

The script builds in Release, runs three processes sequentially, and validates 15 unique scenarios,
30 samples per scenario, and matching nonzero checksums. It saves CSVs, build and stderr logs, source
hashes, revision, and environment metadata. Only `summary.json` with `complete: true` marks success.
Failed runs remain for inspection; the script never overwrites an existing destination.

Records leave the script sanitized: `build.log`, per-run stderr logs, and `environment.json` lose
terminal escape codes, developer-home paths, and machine-local Xcode paths. CSVs stay verbatim.
[scripts/log_sanitizer.py](../scripts/log_sanitizer.py) owns these rules. Do not collect machine
identifiers, battery details, or unrelated runtime inventory.

Commit library, harness, manifest, and lockfile changes before running. Unrelated documentation and
script edits are allowed. Do not modify measured inputs or run other benchmarks while it runs.
Keep power, thermal conditions, and background work comparable; record the power source and relevant
thermal observations. The script does not control these conditions or enforce timing thresholds.

Contributors should compare before/after measurements on the same machine, using separate result
directories. They need not reproduce the maintainer's hardware or update the shared baseline.

For manual execution, build in Release from the repository root, then run three times sequentially:

```sh
swift build --product FlatMarkConstructionBenchmark --configuration release
.build/release/FlatMarkConstructionBenchmark > /tmp/flatmark-run1.csv
.build/release/FlatMarkConstructionBenchmark > /tmp/flatmark-run2.csv
.build/release/FlatMarkConstructionBenchmark > /tmp/flatmark-run3.csv
```

Do not overlap runs. If a launcher times out, check whether its process is still running before
starting another. Each completed run has 15 scenario rows (five fixtures × three construction
scenarios) plus comments and a nonzero consumed-result checksum. Checksums should agree within a
build, not across harness revisions.

## Test the benchmark script

```sh
python3 -m unittest discover -s scripts/tests -p 'test_benchmark_construction.py'
```

This local check tests result validation and committed-input checks without building or running the
Swift benchmark. It is not a hosted CI step.

## Method

Each construction scenario takes five warmups and 30 samples with `ContinuousClock`, reported in
milliseconds as upper-middle median, nearest-rank p95, and minimum. This measures warmed
construction, not process startup.

| Scenario | Work measured |
| --- | --- |
| `initial` | Fresh snapshot |
| `source-change` | Fresh snapshot after appending `\nUpdated description.\n` (22 bytes) |
| `baseURL-change` | Fresh snapshot with `/archive/` instead of `/tasks/` as URL base |

Construction includes parsing, projection, and allocation, but excludes input generation, result
consumption, snapshot destruction, and rendering. Changed inputs reconstruct; this is not incremental
parsing. The harness does not measure retained-copy overhead or view refresh.

Outside each interval, a non-inlined consumer reflects the snapshot into the printed checksum to
prevent optimized code from discarding projection. Reflection perturbs allocator/cache state:
these are diagnostic timings, not memory measurements.

The no-reparse contract also follows from code: `FlatMarkView(document:)` stores the supplied
snapshot and its body reads `document.renderDocument`; only `FlatMarkDocument.init` invokes the
projector. Review this structural contract when changing either path. Elapsed copy timings cannot
establish no-reparse behavior.

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

## Preview mount and visible-content checkpoint (macOS)

The opt-in `--preview` mode separates background document construction from main-actor mounting.
It measures the checked-out renderer without changing its layout. Production uses a top-level
`LazyVStack`; block quotes, list entries, and table rows remain eager. Run from a logged-in graphical
session with screen-capture permission:

```sh
swift build --product FlatMarkConstructionBenchmark --configuration release
FLATMARK_CAPTURE_DIR=/tmp/flatmark-render-captures \
  .build/release/FlatMarkConstructionBenchmark --preview > /tmp/flatmark-preview.csv
```

Each fixture has one warmup and three measured samples. Each sample creates a fresh document off-main,
then mounts a fresh `NSHostingView` containing `ScrollView { FlatMarkView(document:) }` in an existing
390 × 844-point window, with default font and no image loader.

- `background-construction`: parsing and projection inside a detached task; excludes scheduling and
  the hop back to the main actor.
- `main-mount-layout`: hosting-view creation, window attachment, and `layoutSubtreeIfNeeded()`;
  excludes parsing, window creation, and teardown.
- `visible-capture-upper-bound`: from the same mount start through explicit display, a 20 ms
  run-loop suspension, and completion of a Window Server PNG capture. Inspect the PNGs for document
  content before interpreting this as an upper bound on time to first visible content.

The capture checkpoint includes screenshot overhead and polling (5 ms intervals). It is **not an exact
first-frame timestamp** or physical-display measurement. It includes deferred work serviced before
capture, but does not measure later work or scrolling. Parsing is excluded from both display
intervals; this is not source-to-screen latency.

Do not compare this mode's three-sample construction column to the construction-only baseline as if
their methods were identical. The reported p95 is the maximum of three samples, not a reliable tail
estimate. Run sequentially, check for an existing process before restarting, and record omitted
repeats. Archive inspected captures with results if they are needed beyond the local session.

## Physical iPhone

The [device construction guide](DeviceConstruction.md) describes the construction adapter and
three-process procedure. The [device preview host](DeviceHost/README.md) measures initial mounting
and uses external screenshots with capture acknowledgements. Both require a development-enabled
physical iPhone and signing. Run sequentially, keep the app foregrounded, and preserve partial output
when a fixture fails. Desktop and device capture protocols differ; do not compare their capture
checkpoints as renderer speed ratios.

## Regression checks

Use periodic local measurement, not CI timing assertions. Rerun after parser, projector, dependency,
or toolchain changes, or when investigating latency. Record hardware, OS, toolchain, configuration,
revision, and fixture changes. Rebaseline separately when the environment or harness changes; do not
directly compare incompatible methods.

New records must identify a committed measured snapshot (or archive all source changes), its dependency
lockfile, harness, fixtures, and build settings. Establish before/after baselines from the measured
commits on the same machine.

Compare the median of three process medians per scenario. Investigate an increase exceeding **both
20% and 0.1 ms**, then confirm with another three-run set. The absolute floor filters tiny-description
noise. Inspect p95s too, but do not gate on a single tail sample. This is an investigation threshold,
not a responsiveness guarantee. Retained reuse is a structural contract, not a nanosecond timing gate.
