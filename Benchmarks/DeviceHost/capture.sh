#!/bin/bash
# Run after launching the host with the selected fixture as its last argument.
set -euo pipefail
if [[ $# != 3 ]]; then echo "Usage: $0 DEVICE_ID FIXTURE OUTPUT_DIR" >&2; exit 2; fi
device=$1
fixture=$2
out=$3
bundle=dev.flatmark.RenderBenchmark
mkdir -p "$out/captures"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
copy_from() {
    xcrun devicectl device copy from --device "$device" --domain-type appDataContainer \
        --domain-identifier "$bundle" --source "Documents/$1" --destination "$2" --quiet --timeout 15
}
current_run() {
    awk '/^"run",/ { rows="" } { rows=rows $0 ORS } END { printf "%s", rows }' \
        "$out/preview-$fixture.csv"
}
for ((iteration=${FROM_ITERATION:-0}; iteration<=3; iteration++)); do
    id="$fixture-$iteration"
    deadline=$((SECONDS + ${FLATMARK_LAYOUT_TIMEOUT:-180}))
    until copy_from capture-ready.txt "$scratch/ready" 2>/dev/null && [[ $(< "$scratch/ready") == "$id" ]]; do
        copy_from "preview-$fixture.csv" "$out/preview-$fixture.csv" 2>/dev/null || true
        if current_run 2>/dev/null | grep -q '"completion".*"failure'; then
            echo "Host reported failure; see $out/preview-$fixture.csv" >&2; exit 1
        fi
        if (( SECONDS >= deadline )); then echo "Timed out waiting for $id" >&2; exit 1; fi
        sleep 2
    done
    xcrun devicectl device capture screenshot --device "$device" \
        --destination "$out/captures/$id.png" --timeout 20
    printf '%s\n' "$id" > "$scratch/capture-ack.txt"
    # Older hosts can consume/remove the acknowledgement before devicectl's final stat.
    # The next ready marker or completion row confirms that the host consumed it.
    xcrun devicectl device copy to --device "$device" --domain-type appDataContainer \
        --domain-identifier "$bundle" --source "$scratch/capture-ack.txt" \
        --destination Documents/capture-ack.txt --quiet --timeout 15 || \
        echo "Acknowledgement copy reported an error; checking host progression" >&2
    echo "Captured and acknowledged $id"
done
for attempt in {1..20}; do
    copy_from "preview-$fixture.csv" "$out/preview-$fixture.csv"
    if current_run | grep -q '"completion".*"success"'; then exit 0; fi
    sleep 1
done
echo 'Missing completion marker' >&2
exit 1
