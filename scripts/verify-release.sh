#!/usr/bin/env bash
# Verify a published tag resolves and builds the way a consumer sees it.
# Usage: scripts/verify-release.sh <version> [git-url]
# Builds a throwaway package, so it needs network access to the git URL.
set -euo pipefail
VERSION="${1:?Usage: scripts/verify-release.sh <version> [git-url]}"
URL="${2:-https://github.com/NoemiRozpara/FlatMark.git}"
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "Version must look like 1.2.3 or 1.2.3-beta.1, got: $VERSION" >&2
  exit 2
fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/Sources/Check"
cat > "$WORK/Package.swift" <<SWIFT
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FlatMarkReleaseCheck",
    platforms: [.iOS(.v17), .macOS(.v15)],
    dependencies: [
        .package(url: "$URL", exact: "$VERSION")
    ],
    targets: [
        .executableTarget(
            name: "Check",
            dependencies: [.product(name: "FlatMark", package: "FlatMark")]
        )
    ]
)
SWIFT
cat > "$WORK/Sources/Check/main.swift" <<'SWIFT'
import FlatMark
import SwiftUI

@available(macOS 15, *)
struct ReleaseCheck: View {
    let markdown: String

    var body: some View {
        FlatMarkView(
            document: FlatMarkDocument(markdown: markdown),
            linkActivationAction: { _ in .rejected },
            taskToggleAction: { _ in }
        )
    }
}

if #available(macOS 15, *) {
    _ = ReleaseCheck(markdown: "- [x] ok")
    print("FlatMark released API compiled.")
}
SWIFT

cd "$WORK"
swift build
if ! grep -q "\"version\" : \"$VERSION\"" Package.resolved; then
  echo "Resolved FlatMark is not $VERSION:" >&2
  cat Package.resolved >&2
  exit 1
fi
echo "Tag $VERSION resolved and built from $URL"
