#!/usr/bin/env bash
# Create the GitHub release for a pushed tag, with notes taken from CHANGELOG.md.
# Usage: scripts/publish-release.sh <version> [--dry-run]
# The changelog entry is the only source of release notes, so notes and audited commit cannot drift.
# The script never creates or moves a tag, and never edits an existing release.
set -euo pipefail

VERSION="${1:?Usage: scripts/publish-release.sh <version> [--dry-run]}"
DRY_RUN=0
if [[ "${2:-}" == "--dry-run" ]]; then
  DRY_RUN=1
elif [[ -n "${2:-}" ]]; then
  echo "Unknown option: $2 (expected --dry-run)" >&2
  exit 2
fi
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "Version must look like 1.2.3 or 1.2.3-beta.1, got: $VERSION" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGELOG="$ROOT/CHANGELOG.md"
NOTES_FILE="$(mktemp)"
trap 'rm -f "$NOTES_FILE"' EXIT

set +e
NOTES="$(awk -v v="$VERSION" '
  index($0, "## [" v "]") == 1 {
    hits++
    if (hits > 1) { dup = 1; exit }
    if (match($0, / - [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/)) { state = 1 } else { undated = 1 }
    next
  }
  state == 1 && substr($0, 1, 4) == "## [" { exit }
  state == 1 && index($0, "[" v "]:") == 1 { exit }
  state == 1 { body[NR] = $0; n = NR }
  END {
    if (hits == 0) { exit 3 }
    if (dup) { exit 4 }
    if (undated) { exit 5 }
    first = 0; last = 0
    for (i = 1; i <= n; i++) {
      if (body[i] ~ /[^[:space:]]/) {
        if (first == 0) { first = i }
        last = i
      }
    }
    for (i = first; i <= last; i++) { print body[i] }
  }
' "$CHANGELOG")"
extract_status=$?
set -e
case "$extract_status" in
  0) ;;
  3) echo "CHANGELOG.md has no \"## [$VERSION]\" section. Write the release entry first." >&2; exit 2 ;;
  4) echo "CHANGELOG.md has more than one \"## [$VERSION]\" heading." >&2; exit 2 ;;
  5) echo "The \"## [$VERSION]\" heading needs its actual release date: \"## [$VERSION] - YYYY-MM-DD\"." >&2; exit 2 ;;
  *) echo "Could not read $CHANGELOG (awk exit $extract_status)." >&2; exit 2 ;;
esac
if ! printf '%s\n' "$NOTES" | grep -q '[^[:space:]]'; then
  echo "The \"## [$VERSION]\" section has no content to publish." >&2
  exit 2
fi
printf '%s\n' "$NOTES" > "$NOTES_FILE"

if ! git -C "$ROOT" rev-parse -q --verify "refs/tags/$VERSION" > /dev/null; then
  echo "No local tag $VERSION. Tag the verified commit first (Releasing.md step 7)." >&2
  exit 2
fi
if [[ -z "$(git -C "$ROOT" ls-remote origin "refs/tags/$VERSION")" ]]; then
  echo "Tag $VERSION is not on origin. Push it first: git push origin $VERSION" >&2
  exit 2
fi
if ! command -v gh > /dev/null; then
  echo "The GitHub CLI (gh) is required to create the release." >&2
  exit 2
fi

cd "$ROOT"
EXISTS=0
if gh release view "$VERSION" > /dev/null 2>&1; then
  EXISTS=1
fi

ARGS=(release create "$VERSION" --title "FlatMark $VERSION" --notes-file "$NOTES_FILE")
if [[ "$VERSION" == *-* ]]; then
  ARGS+=(--prerelease)
else
  ARGS+=(--latest)
fi

if [[ "$DRY_RUN" == 1 ]]; then
  echo "Release notes for $VERSION, extracted from CHANGELOG.md:"
  echo "---"
  printf '%s\n' "$NOTES"
  echo "---"
  if [[ "$EXISTS" == 1 ]]; then
    echo "A release for $VERSION already exists; a real run would stop. Replace it with:" >&2
    echo "  gh release delete $VERSION --yes"
  fi
  printf 'Would run: gh'; printf ' "%s"' "${ARGS[@]}"; printf '\n'
  exit 0
fi

if [[ "$EXISTS" == 1 ]]; then
  echo "A release for $VERSION already exists; publish-release.sh never overwrites one." >&2
  echo "Inspect it with: gh release view $VERSION" >&2
  echo "To re-publish from CHANGELOG.md: gh release delete $VERSION --yes, then re-run." >&2
  exit 2
fi

gh "${ARGS[@]}"
echo "Published the $VERSION release from the CHANGELOG.md $VERSION section."
