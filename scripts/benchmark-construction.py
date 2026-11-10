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

ROOT = pathlib.Path(__file__).resolve().parent.parent
INPUTS = ["Sources", "Package.swift", "Package.resolved", "Benchmarks/Construction/main.swift",
          "Benchmarks/Construction/PreviewBenchmark.swift"]
SCENARIOS = {"initial", "source-change", "baseURL-change"}
FIXTURES = {"ordinary", "large-100", "large-1000", "nested", "links-tables"}


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
        "remote": output("git", "remote", "get-url", "origin"),
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
    with (destination / "build.log").open("w") as log:
        subprocess.run(metadata["build_command"], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
    require_committed_inputs(revision)
    binary_directory = output("swift", "build", "--configuration", "release", "--show-bin-path")
    checksums = []
    for number in range(1, 4):
        print(f"Running process {number}/3", flush=True)
        path = destination / f"run{number}.csv"
        with path.open("w") as stdout, (destination / f"run{number}.stderr.log").open("w") as stderr:
            subprocess.run([str(pathlib.Path(binary_directory) / "FlatMarkConstructionBenchmark")],
                           cwd=ROOT, stdout=stdout, stderr=stderr, check=True)
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
