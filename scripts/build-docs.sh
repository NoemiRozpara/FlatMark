#!/usr/bin/env bash
# Build FlatMark's DocC documentation from public-symbol doc comments.
# Usage: scripts/build-docs.sh <output-directory> [release-tag]
# Creates the output directory if missing; development links default to main.
# Warnings fail the build, so a documented release needs a clean run here.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:?Usage: scripts/build-docs.sh <output-directory> [release-tag]}"
REF="${2:-main}"
if [[ "$REF" != main ]] && ! [[ "$REF" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "Release tag must look like 1.2.3 or 1.2.3-beta.1, got: $REF" >&2
  exit 2
fi
# Kept under .build so the build tree does not accumulate in the system temp directory.
WORK="$ROOT/.build/docs"
cd "$ROOT"

rm -rf "$WORK"
mkdir -p "$WORK/symbols" "$WORK/module" "$OUT"

# Flat start: symbol graphs are only emitted for files SwiftPM actually recompiles.
swift build --target FlatMark --scratch-path "$WORK/spm" \
  -Xswiftc -emit-symbol-graph -Xswiftc -emit-symbol-graph-dir -Xswiftc "$WORK/symbols"

# Keep only FlatMark's graphs so dependency symbols cannot fail the build.
if ! ls "$WORK"/symbols/FlatMark*.symbols.json >/dev/null 2>&1; then
  echo "No FlatMark symbol graphs were emitted." >&2
  ls "$WORK/symbols" >&2
  exit 1
fi
cp "$WORK"/symbols/FlatMark*.symbols.json "$WORK/module/"

# Build from a copy so release links can name the future tag without editing tracked files.
cp -R Sources/FlatMark/FlatMark.docc "$WORK/FlatMark.docc"
OVERVIEW="$(<"$WORK/FlatMark.docc/FlatMark.md")"
OLD_LINK_PREFIX="https://github.com/NoemiRozpara/FlatMark/blob/main/"
NEW_LINK_PREFIX="https://github.com/NoemiRozpara/FlatMark/blob/$REF/"
printf '%s\n' "${OVERVIEW//$OLD_LINK_PREFIX/$NEW_LINK_PREFIX}" > "$WORK/FlatMark.docc/FlatMark.md"

xcrun docc convert "$WORK/FlatMark.docc" \
  --additional-symbol-graph-dir "$WORK/module" \
  --output-dir "$OUT" \
  --hosting-base-path FlatMark \
  --source-service github \
  --source-service-base-url "https://github.com/NoemiRozpara/FlatMark/blob/$REF" \
  --checkout-path "$ROOT" \
  --transform-for-static-hosting \
  --warnings-as-errors

echo "DocC site written to $OUT/index.html"
