#!/bin/bash
# Generate an independent, disposable device benchmark project. Does not build or launch.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
out=/tmp/flatmark-render-device
mkdir -p "$out"
# Keep fixtures and checksum/timing helpers authoritative in the construction benchmark.
awk '/^#if os\(macOS\)/ { found=1; exit } { print } END { if (!found) exit 1 }' \
    "$repo/Benchmarks/Construction/main.swift" > "$out/FixtureHelpers.swift"
# JSON is also valid YAML; encode paths rather than interpolating YAML strings.
python3 - "$repo" "$out" <<'PY'
import json
import pathlib
import sys
repo, out = map(pathlib.Path, sys.argv[1:])
spec = {
    "name": "FlatMarkRenderDevice",
    "options": {"deploymentTarget": {"iOS": "17.0"}},
    "packages": {"FlatMark": {"path": str(repo)}},
    "settings": {"base": {
        "SWIFT_VERSION": "6.0",
        "CODE_SIGN_STYLE": "Automatic",
        "SWIFT_STRICT_CONCURRENCY": "complete"
    }},
    "targets": {"FlatMarkRenderDevice": {
        "type": "application",
        "platform": "iOS",
        "sources": [str(repo / "Benchmarks/DeviceHost/PreviewBenchmarkApp.swift"),
                    str(out / "FixtureHelpers.swift")],
        "dependencies": [{"package": "FlatMark"}],
        "settings": {"base": {
            "PRODUCT_BUNDLE_IDENTIFIER": "dev.flatmark.RenderBenchmark",
            "TARGETED_DEVICE_FAMILY": "1,2",
            "GENERATE_INFOPLIST_FILE": "YES",
            "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
            "INFOPLIST_KEY_UIRequiresFullScreen": "YES",
            "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES"
        }}
    }},
    "schemes": {"FlatMarkRenderDevice": {
        "build": {"targets": {"FlatMarkRenderDevice": "all"}},
        "run": {"config": "Release"},
        "archive": {"config": "Release"}
    }}
}
(out / "project.yml").write_text(json.dumps(spec, indent=2) + "\n")
PY
xcodegen generate --spec "$out/project.yml" --project "$out"
printf 'Generated %s/FlatMarkRenderDevice.xcodeproj (Release; no build performed)\n' "$out"
