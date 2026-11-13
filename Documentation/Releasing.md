# Release checklist

Produce a tag from a clean, auditable state. Version numbers follow
the [versioning policy](Versioning.md); [CHANGELOG.md](../CHANGELOG.md) is the release narrative. Verification
standards and lane limits: [build and test](Contributing/BuildAndTest.md).

Only the maintainer pushes and tags. Run commands from the repository root. Start verification and
tagging with a clean working tree (`git status --porcelain` empty). Stop when a gate fails.

Never overwrite a published tag. If the chosen tag already exists, stop and resolve its status
with the maintainer before proceeding.

## 1. Prepare the release

- Check out `main` with a clean working tree.
- Choose `X.Y.Z` under the versioning policy from changes since the last published release, not
  from a date. Record the choice.

## 2. Update the changelog

- Once publication is authorized, finalize the release entry or move `Unreleased` entries under
  `## [X.Y.Z] - YYYY-MM-DD`, using the actual release date, newest version first. Do not invent a
  date for an undated entry.
- Leave an empty `Unreleased` heading at the top for the next cycle.
- Check entries against the [versioning rules](Versioning.md#breaking-changes-before-100).
- Add the release link; add compare links only when there is a previous published release.

## 3. Update version-bearing docs

- `README.md`: the two install snippets use the new version. Keep the guidance to read documentation
  at the dependency's tag.
- Update [Markdown support](MarkdownSupport.md) and [usage](Usage.md) wherever the
  release changed documented behavior, and [SECURITY.md](../SECURITY.md) for any change to link, image, or
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

1. Open `Package.swift` in Xcode.
2. Select the **FlatMark** scheme and **My Mac** destination.
3. Choose **Product → Build Documentation** (Control–Shift–Command–D).
4. In Xcode's documentation viewer, open the FlatMark module.

Gate: the documentation build succeeds with no documentation warnings. Inspect Xcode's diagnostics
for broken symbol links and unresolved references. Confirm the module overview, the **Rendering**
and **Host-provided behavior** Topics groups, and navigation to a page for every public type.
Confirm the overview is attached to the module rather than listed as a separate article.

Repository-guide links in the catalog point to `main`; Xcode does not rewrite them to the release
tag. Use GitHub's tag selector when consulting the guides for a specific release.

## 6. Verify the candidate commit

Record toolchain and OS with the results; newer-toolchain success does not prove the declared minimum.

```sh
FLATMARK_SNAPSHOT_RECORD=never swift test
```

Then, in order:

- Snapshot lanes on both platforms through the normal (verify) schemes
  ([verify and record](../Tests/README.md#verify-and-record)). Never use a `-Record` scheme for a release,
  and never re-record to turn a lane green — inspect the diff images and file a finding.
- Running demo smoke check on both platforms ([run-fixture-host.sh](../Demo/README.md#capture-presets))
  plus the [manual checklist](../Tests/README.md#manual-checklist) items covering what the release changed.
- [Benchmark regression check](../Benchmarks/README.md#regression-checks) when parser, projector,
  dependency, or construction cost changed.
- Run [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) manually on the candidate commit; it is
  dispatch-only. Keep failing-lane artifacts.

Gate: every required check passes. A required failure stops the release; a historical issue is not
a waiver. Any exception requires a separate, explicit maintainer decision for this candidate,
recorded with its scope and rationale in the external release record. Record all results there.

## 7. Tag the verified commit

Confirm `HEAD` still matches the recorded candidate SHA before tagging. Do not create or amend a
commit after verification.

```sh
git tag X.Y.Z                 # plain tag with the bare version name
git rev-list -n1 X.Y.Z        # must print the audited candidate SHA
git show --stat --no-patch X.Y.Z
```

Tags are plain and carry no message. The release narrative lives in `CHANGELOG.md` and in the GitHub
release created in step 8, so it is reviewed in a pull request instead of living in tag or commit text.

Gate: the tag points at the commit that passed steps 5 and 6, and the working tree is clean.

## 8. Publish

```sh
git push origin X.Y.Z
```

Create the GitHub release for the pushed tag. The notes come from the `X.Y.Z` section of
`CHANGELOG.md`; the script refuses to write them any other way, so notes cannot drift from the audited
commit. Do not hand-author notes or edit them on GitHub afterwards — fix `CHANGELOG.md` and re-publish.

```sh
bash scripts/publish-release.sh X.Y.Z --dry-run   # read the extracted notes first
bash scripts/publish-release.sh X.Y.Z
```

Confirm the tag is visible on GitHub, the release appears under
[Releases](https://github.com/NoemiRozpara/FlatMark/releases), and that
[`Documentation/Usage.md`](Usage.md) reads correctly at that tag. Check the repository guides at the published tag.

Gate: the release exists for `X.Y.Z` with the notes the script extracted, and the changelog entry and
release notes match. The script requires an authenticated `gh` session, refuses an unpublished tag, and
stops rather than overwriting an existing release.

Once the release exists, do not delete or move the tag. GitHub turns a release whose tag disappears
into an untagged draft, and re-pushing the tag does not relink it; delete that release with
`gh release delete X.Y.Z --yes` (it keeps the tag) and publish again.

## 9. Confirm what hosts receive

```sh
bash scripts/verify-release.sh X.Y.Z
```

Gate: a throwaway consumer package pins exactly `X.Y.Z`, resolves from the published git URL, and
builds against the documented entry points. Then re-dispatch CI once against the tag for the record.

## If something is wrong afterwards

Keep published tags unchanged; follow the [yank and fix policy](Versioning.md#yanks-and-fixes).
