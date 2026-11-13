#!/usr/bin/env python3
"""Record three opt-in Release construction runs without updating the shared baseline."""

import argparse
import csv
import datetime
import hashlib
import json
import pathlib
import platform
import subprocess
import sys

# Keep the shared sanitizer importable when this script is loaded by path from scripts/tests.
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import log_sanitizer

ROOT = pathlib.Path(__file__).resolve().parent.parent
INPUTS = ["Sources", "Package.swift", "Package.resolved", "Benchmarks/Construction/main.swift",
          "Benchmarks/Construction/PreviewBenchmark.swift"]
SCENARIOS = {"initial", "source-change", "baseURL-change"}
FIXTURES = {"ordinary", "large-100", "large-1000", "nested", "links-tables"}
# Captured tool output that is safe to rewrite; CSVs stay verbatim because validate() reads them.
SANITIZED_ARTIFACTS = ("*.log", "environment.json")


def output(*command):
    return subprocess.check_output(command, cwd=ROOT, text=True, stderr=subprocess.STDOUT).strip()


def require_committed_inputs(revision):
    if output("git", "rev-parse", "HEAD") != revision:
        raise ValueError("HEAD changed during measurement")
    if output("git", "status", "--porcelain", "--untracked-files=all", "--", *INPUTS):
        raise ValueError("Commit library, harness, manifest, and lockfile changes before measuring")


def validate(path):
    lines = path.read_text().splitlines()
    header = "fixture,scenario,samples,median_ms,p95_ms,min_ms"
    if len(lines) < 2 or lines[1] != header:
        raise ValueError(f"{path.name}: missing CSV header")
    checksums = [line for line in lines if line.startswith("Consumed snapshot checksum: ")]
    if len(checksums) != 1 or lines[-1] != checksums[0]:
        raise ValueError(f"{path.name}: incomplete or repeated output")
    checksum = int(checksums[0].split(": ")[1])
    if checksum == 0:
        raise ValueError(f"{path.name}: zero checksum")
    rows = list(csv.DictReader(line for line in lines[1:-1] if not line.startswith("#")))
    expected = {(fixture, scenario) for fixture in FIXTURES for scenario in SCENARIOS}
    if len(rows) != 15 or {(r["fixture"], r["scenario"]) for r in rows} != expected:
        raise ValueError(f"{path.name}: expected 15 unique construction scenarios")
    for row in rows:
        if row["samples"] != "30":
            raise ValueError(f"{path.name}: expected 30 samples")
        minimum, median, tail = (float(row[key]) for key in ("min_ms", "median_ms", "p95_ms"))
        if not 0 <= minimum <= median <= tail < float("inf"):
            raise ValueError(f"{path.name}: invalid timing values")
    return checksum


def sanitize_artifacts(destination):
    """Rewrite captured logs and environment metadata in place, so a recorded run keeps its
    failure messages, counts and timings without terminal bytes, home-directory paths, or
    machine-local Xcode paths. Failed runs keep their output for inspection, sanitized the
    same way as a successful one.
    """
    for pattern in SANITIZED_ARTIFACTS:
        for path in sorted(destination.glob(pattern)):
            text = path.read_text(errors="replace")
            path.write_text(log_sanitizer.sanitize_log_text(text, root=ROOT))


def run_logged(command, destination, log_path, measured_stdout=None):
    """Run `command` from the repository root, recording tool output to `log_path` in sanitized
    form. Pass `measured_stdout` to keep measured CSV output verbatim, because `validate()` reads
    those bytes. A failed command still leaves a sanitized log behind: failed runs stay for
    inspection, and a record must never hold terminal bytes or local paths.
    """
    log = log_path.open("w")
    measured = measured_stdout.open("w") if measured_stdout else None
    try:
        if measured is None:
            subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
        else:
            subprocess.run(command, cwd=ROOT, stdout=measured, stderr=log, check=True)
    finally:
        if measured is not None:
            measured.close()
        log.close()
        sanitize_artifacts(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=pathlib.Path, help="new results directory (must not exist)")
    args = parser.parse_args()
    destination = args.destination.resolve()
    revision = output("git", "rev-parse", "HEAD")
    require_committed_inputs(revision)
    destination.mkdir(parents=True, exist_ok=False)
    # Leave failed runs and logs intact; only a final summary marks a complete set.
    metadata = {
        "revision": revision,
        "started_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "platform": platform.platform(),
        "swift": output("swift", "--version"),
        "build_command": ["swift", "build", "--product", "FlatMarkConstructionBenchmark",
                          "--configuration", "release"],
        "runs": 3,
        "conditions": "Power, thermals, and background activity are not controlled by this script.",
        "input_sha256": {},
    }
    for entry in INPUTS:
        path = ROOT / entry
        for file in sorted(path.rglob("*")) if path.is_dir() else [path]:
            if file.is_file():
                metadata["input_sha256"][str(file.relative_to(ROOT))] = hashlib.sha256(file.read_bytes()).hexdigest()
    if sys.platform == "darwin":
        metadata["os"] = output("sw_vers")
        metadata["hardware"] = output("sysctl", "-n", "machdep.cpu.brand_string", "hw.ncpu", "hw.memsize")
        metadata["xcode"] = output("xcodebuild", "-version")
    (destination / "environment.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(f"Building Release; results: {destination}", flush=True)
    run_logged(metadata["build_command"], destination, destination / "build.log")
    require_committed_inputs(revision)
    binary_directory = output("swift", "build", "--configuration", "release", "--show-bin-path")
    checksums = []
    for number in range(1, 4):
        print(f"Running process {number}/3", flush=True)
        path = destination / f"run{number}.csv"
        run_logged([str(pathlib.Path(binary_directory) / "FlatMarkConstructionBenchmark")],
                   destination, destination / f"run{number}.stderr.log", measured_stdout=path)
        checksums.append(validate(path))
        require_committed_inputs(revision)
    if len(set(checksums)) != 1:
        raise ValueError("Consumed-result checksums differ across runs")
    (destination / "summary.json").write_text(json.dumps({
        "complete": True, "runs": 3, "scenarios_per_run": 15, "checksum": checksums[0],
    }, indent=2) + "\n")
    print("Complete: three validated runs. Compare only equivalent methods and environments.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Benchmark failed: {error}", file=sys.stderr)
        sys.exit(1)
