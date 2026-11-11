# Release checklist

Produce a tag from a clean, auditable state. Version numbers follow
[VERSIONING.md](VERSIONING.md); [CHANGELOG.md](CHANGELOG.md) is the release narrative. Verification
standards and lane limits: [AI-docs/BUILD_AND_TEST.md](AI-docs/BUILD_AND_TEST.md).

Only the maintainer pushes and tags. Run commands from the repository root. Start verification and
tagging with a clean working tree (`git status --porcelain` empty). Stop when a gate fails.

## 1. Prepare the release

- Check out `main` with a clean working tree.
- Choose `X.Y.Z` from the changes since the last tag, not from a date. Record the choice.

## 2. Update the changelog

- Move every `Unreleased` entry under `## [X.Y.Z] - YYYY-MM-DD`, newest version first.
- Leave an empty `Unreleased` heading at the top for the next cycle.
- Check entries against the [versioning rules](VERSIONING.md#breaking-changes-before-100).
- Refresh the compare links at the bottom of the file.

## 3. Update version-bearing docs

- `README.md`: the two install snippets use the new version; the note that guides describe an
  unreleased checkout applies only when `main` is ahead of the tag.
- Update [SUPPORT.md](SUPPORT.md) and [Documentation/Usage.md](Documentation/Usage.md) wherever the
  release changed documented behavior, and [SECURITY.md](SECURITY.md) for any change to link, image, or
  HTML handling.
- Public doc comments are DocC content: update them with the API, not afterwards.

## 4. Commit the candidate

```sh
git add CHANGELOG.md README.md  # also stage any other release-doc updates
git diff --cached              # confirm only intended release changes are staged
git commit -m "Release X.Y.Z"
git rev-parse HEAD            # record this candidate SHA
```

Push the candidate to `main` so manual-dispatch CI can verify it:

```sh
git push origin main
```

Keep verification results in an external release record, not a new commit or an amendment. Record
the candidate SHA, commands, results, toolchain, OS, and any unverified lane there. If a fix changes
the candidate, commit it, record the new SHA, and restart verification.

## 5. Build the documentation

```sh
bash scripts/build-docs.sh "$(mktemp -d)/flatmark-docs" X.Y.Z
```

Gate: exit code 0. DocC runs with `--warnings-as-errors`, so a broken symbol link or unresolved
reference fails the release. Open the printed `index.html` and confirm the module page, both
**Topics** groups, and a page for every public type. Confirm repository-guide and *View on GitHub*
links target `X.Y.Z`; they become reachable after the tag is published.

## 6. Verify the candidate commit

Record toolchain and OS with the results; newer-toolchain success does not prove the declared minimum.

```sh
FLATMARK_SNAPSHOT_RECORD=never swift test
```

Then, in order:

- Snapshot lanes on both platforms through the normal (verify) schemes
  ([verify and record](Tests/README.md#verify-and-record)). Never use a `-Record` scheme for a release,
  and never re-record to turn a lane green — inspect the diff images and file a finding.
- Running demo smoke check on both platforms ([run-fixture-host.sh](Demo/README.md#capture-presets))
  plus the [manual checklist](Tests/README.md#manual-checklist) items covering what the release changed.
- [Benchmark regression check](Benchmarks/README.md#regression-checks) when parser, projector,
  dependency, or construction cost changed.
- Run [`.github/workflows/ci.yml`](.github/workflows/ci.yml) manually on the candidate commit; it is
  dispatch-only. Keep failing-lane artifacts.

Gate: no new failure beyond the triaged known issues listed in
[AI-docs/BUILD_AND_TEST.md](AI-docs/BUILD_AND_TEST.md#ci). A new failure ends the release. Record the
results in the external release record.

## 7. Tag the verified commit

Confirm `HEAD` still matches the recorded candidate SHA before tagging. Do not create or amend a
commit after verification.

```sh
git tag -a X.Y.Z -m "FlatMark X.Y.Z"
git rev-list -n1 X.Y.Z        # must print the audited candidate SHA
git show --stat --no-patch X.Y.Z
```

Gate: the tag points at the commit that passed steps 5 and 6, and the working tree is clean.

## 8. Publish

```sh
git push origin X.Y.Z
```

Confirm the tag is visible on GitHub and that
[`Documentation/Usage.md`](Documentation/Usage.md) reads correctly at that tag. Check the generated
DocC repository-guide and *View on GitHub* links now that the tag is published.

## 9. Confirm what hosts receive

```sh
bash scripts/verify-release.sh X.Y.Z
```

Gate: a throwaway consumer package pins exactly `X.Y.Z`, resolves from the published git URL, and
builds against the documented entry points. Then re-dispatch CI once against the tag for the record.

## If something is wrong afterwards

Keep published tags unchanged; follow the [yank and fix policy](VERSIONING.md#yanks-and-fixes).
