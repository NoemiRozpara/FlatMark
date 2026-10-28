# Recipe Lab references — #228

## How to explore

Recipe Lab now presents one compact focaccia recipe, shared with the mounted policy-transition
tests. The former prep checklist, web clipping, mixed-content, and task-marker samples have been
consolidated into it, along with the mention examples. **Detect mentions** in Appearance controls
mention rendering. Empty quotes and supported continuation notes exercise omission in the recipe;
deliberately blank rows remain only in the automated omission oracle. **Notebook rendering** switches
the main recipe between string and retained-document initializers. The playground shows only one
recipe; initializer parity is compared in automated tests. The former regression documents and
their disclosure have been removed. Links stay local; interaction feedback appears above the recipe.

**The screenshots and recorded observations below predate this reduction.** They remain historical
references, not verified images of the current fixture. Capture presets still apply to the same page.

The local image is an SF Symbol leaf representing rosemary. It is intentionally an illustration,
not a photograph; its appearance is tied to the recorded OS. The same existing image loader and
`FlatMarkCustomFixture` serve exploration and captures. No backend or snapshot dependency is used.

## Reproduce

From the repository root, with a booted iPhone simulator / logged-in desktop:

```sh
export DEVELOPER_DIR=/Applications/Xcode-27-RC.app/Contents/Developer
bash scripts/capture-recipe-lab.sh macos FlatMark/Tests/References/RecipeLab
bash scripts/capture-recipe-lab.sh ios FlatMark/Tests/References/RecipeLab
```

The script builds/packages through the existing fixture-host script, launches a fresh process for
each preset, waits two seconds for the local image, and captures the initial viewport. Because the
documents now follow the header and note strip, the initial viewport shows the start of **The
recipe**; everything below it needs a scroll. Desktop capture needs Screen Recording and System
Events access and a display large enough for an 850 × 1040 point window positioned at (20, 40). Avoid
overlapping windows during capture. The script closes the macOS fixture between presets. Do not run
it during another fixture session. Screenshots contain platform chrome and clocks; these are review
references, not pixel baselines. `*-environment.txt` records OS, toolchain, and the booted simulator
used for each run.

For one configuration:

```sh
scripts/run-fixture-host.sh macos --capture hostMarkers
scripts/run-fixture-host.sh ios --capture generous
```

## Named matrix

Every preset shows the same single page. Standard text, light appearance, LTR, interactive tasks,
default markers, and Custom unsupported-content rendering apply unless listed otherwise. iOS always
uses the 240-point reading column; macOS has no document width cap, so a capture's reading width comes
from the window the script sizes to 850 × 1040. Settings chrome retains the ambient text size.

| Name | Variations | References |
| --- | --- | --- |
| `daylight` | Custom with host buttons, linked illustration, lists/quotes, tasks, table, code | [iOS](ios-daylight.png) · [macOS](macos-daylight.png) |
| `midnight` | Dark appearance | [iOS](ios-midnight.png) · [macOS](macos-midnight.png) |
| `generous` | Enlarged text (`accessibility2` on iOS, 28 pt body on macOS) | [iOS](ios-generous.png) · [macOS](macos-generous.png) |
| `rightToLeft` | RTL; English retained for comparison | [iOS](ios-rightToLeft.png) · [macOS](macos-rightToLeft.png) |
| `hostMarkers` | Hand-drawn markers, independent link and tips | [iOS](ios-hostMarkers.png) · [macOS](macos-hostMarkers.png) |
| `readOnly` | Static tasks (task editing off) | [iOS](ios-readOnly.png) · [macOS](macos-readOnly.png) |
| `literal` | Show HTML | [iOS](ios-literal.png) · [macOS](macos-literal.png) |
| `omission` | Hide HTML | [iOS](ios-omission.png) · [macOS](macos-omission.png) |

Read-only tasks are the `readOnly` preset. There is no separate "everything disabled" switch: it only
suppressed `Button`/`Link` activation, which is platform behavior, and the inherited-environment path
is asserted automatically by `hands an inline and a whole-block host view the ancestor's own enabled
state`. Empty-tag/empty-task edge cases remain in the focused omission sample rather than the recipe
narrative.

## Recorded verification — second pass, 2026-10-27 (historical)

This pass predates the single-page merge; it describes the former three-page fixture with a page menu
and a settings sheet, so its screenshot links were re-pointed at freshly captured files rather than
re-verified one by one.

- macOS and iOS hosts built and ran through `scripts/run-fixture-host.sh`, using Xcode 27 RC.
- FlatMark package tests passed via `mobilebuildmcp swift-package test --package-path FlatMark`.
- Both platform capture runs refreshed the references. This is not automated pixel comparison.
- Recipe quantities, yeast method, tin size, timing table, prep wording, and baking notes agree; the
  leaf illustration depicts rosemary rather than a carrot.
- Enlarged recipe text is visibly larger on both platforms. iOS uses `accessibility2`; macOS supplies
  28-point body text because Dynamic Type alone did not enlarge it. This fixture approximation does
  not establish system-wide macOS accessibility text support; renderer heading/code fonts may not
  scale.
- Narrow macOS clipping tables overflowed their column and the initial horizontal position was
  visibly clipped. Horizontal scrolling and complete cell reachability remain unverified.
- The first-pass long quote truncated “kneading” on macOS. The rewritten quote wraps, but **no
  production renderer fix was made**; the earlier defect is not considered resolved merely because
  different wording fits.
- Per-tag custom replacements intentionally produce separate controls around supported wording; they
  do not interpret matching HTML tags as a pair.
- The two artifacts that pass kept on disk — the settings-sheet screenshot and the first-pass
  task-feedback capture — were later lost with the rest of this untracked folder and are not
  reproduced here; the sheet itself has since been removed from the fixture.

## Recorded verification — single-page merge, 2026-10-28

### Compilation / automated checks

- iOS host built through `scripts/run-fixture-host.sh` and the macOS host through `swift build`, using
  Xcode 27 RC. The `--mentions`, `--document`, and `--task-markers` host arguments were removed;
  `--capture <preset>` remains.
- `mobilebuildmcp swift-package test --package-path FlatMark` and `sweetpad -C FlatMark test` passed:
  **155 tests in 19 suites**. The `marker-disabled` mode in `TaskInteractionTestHost` and the
  corresponding `"disabled"` case of `FlatMarkTaskMarkerTests` were deleted as platform-behavior
  assertions; the automatic `isEnabled` propagation check was retained.
- Both capture runs refreshed all sixteen references plus the two environment files.

### Running-app observations (iPhone 18 Pro / iOS 27, and macOS 27)

Captured through the MobileBuildMCP runtime semantic tree, whose text search covers the whole
rendered page, plus a pixel scan of an iOS capture for the column width:

- All nine section titles and their content are present in one scroll: the three narrative pages,
  mixed content, task-marker sample, both omission documents, mentions, and the retained document —
  including `Refresh requests:`, **Re-render without editing**, **Edit source**, **Detect mentions**,
  and the fenced `@jane is code, not a mention` line.
- `Local image loads this session: 5` — one per document that carries an image.
- Activating **Choose a 23 × 33 cm tin** (nested, Prep checklist) changed only that marker, printed
  `Prep checklist: Recipe updated. Nice prep work!` in the note strip, and increased only
  `Task updates` (0 → 1). Section-prefixed feedback is what keeps one shared strip attributable now
  that all documents share the counters.
- **Capture presets & diagnostics**: the preset menu opened; applying `literal` made the HTML source
  (`hidden block`, `quoted block`) appear, applying `omission` removed both and reset every counter to
  zero. Element counts moved 468 → 396 → 386 as content was added and removed.
- Column width: iOS document text ends at ≈ 792 px on a 3x capture = 24 pt page padding + the 240 pt
  column. macOS document lines measured 400–500 pt inside the 850 pt window, confirming no cap.

### Not established

- **The screenshots were not visually reviewed**: the session that produced this pass had no image
  access. They are fresh artifacts for human review, not reviewed references.
- **The settings controls could not be operated by the automation lane.** `tap` and touch down/up on
  the Appearance / Checklist behavior / Web clipping switches reported success and left their values
  unchanged; the inline `Baker’s tip` host buttons likewise did not activate. Neither working nor
  broken is recorded — real-pointer and VoiceOver interaction remains the way to check them. The same
  lane has failed on non-standard controls before (the former settings sheet).
- Live VoiceOver was **not performed** on either platform. Native exports and semantic trees are not
  substitutes. On each platform, use `hostMarkers` and `readOnly`:
  - Read checked/unchecked and nested tasks; record actual labels, state, nesting, focus order,
    available actions, OS, and outcome.
  - Activate one unchecked task once; only it should change and task updates should increase once.
  - Confirm static tasks offer no toggle action, and that the hand-drawn marker drawing never becomes
    an extra focus stop.
  - Reach the tin note, replacement tips, and linked leaf independently; only the corresponding
    feedback line and counter should move.
- Initial viewports only: lower recipe rows, code blocks, full mixed-content flow, the controls at the
  bottom of the page, all note activations, selection gestures, and a complete per-platform interaction
  matrix still need directed checks.

Historical observations in [the runtime guide](../../README.md) remain historical.
**#228 is not fully verified** until the outstanding matrix and accessibility checks are completed.
