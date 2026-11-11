# AGENTS.md

## Goal and scope

Implement the smallest correct change. Favor clarity, maintainability, and reviewability.

FlatMark is a native SwiftUI Markdown preview renderer, not an editor, browser, HTML sanitizer, or application framework. Preserve host ownership of persistence, image fetching, navigation decisions, and custom content. See [README.md](README.md) for scope and public contracts.

- Follow agreed scope; avoid unrelated cleanup, speculative abstractions, and hypothetical requirements.
- Obtain agreement before material scope/architecture changes or new dependencies.
- If an important agreed assumption fails, stop and explain before redesigning.

## Read relevant guidance

Read only the documents relevant to the task:

- [AI-docs/PLANNING.md](AI-docs/PLANNING.md): clarification, specifications, issue creation, and issue pickup.
- [AI-docs/ARCHITECTURE.md](AI-docs/ARCHITECTURE.md): snapshots, rendering, host ownership, and package boundaries.
- [AI-docs/UI.md](AI-docs/UI.md): native semantics, layout, interaction, accessibility, and custom content.
- [AI-docs/BUILD_AND_TEST.md](AI-docs/BUILD_AND_TEST.md): toolchain requirements, verification selection, demo generation, and reporting.
- [AI-docs/CODE_REVIEW.md](AI-docs/CODE_REVIEW.md): code review and specialist selection.
- [AI-docs/DEVICE_HUB.md](AI-docs/DEVICE_HUB.md): driving simulators and devices with `devicectl`, including resizing the running app, capture, and device settings.
- [CONTRIBUTING.md](CONTRIBUTING.md) and [RELEASING.md](RELEASING.md): contributor expectations, changelog and versioning rules, and the gated release process.

`AGENTS.md` owns repository-wide rules; `AI-docs/` owns contributor policy; task skills own procedures and on-demand examples. Link to the authoritative source rather than copying its rules. Load only relevant skill references, not entire reference folders.

Within repository guidance, prefer this file, then `AI-docs/`, then tool-specific guidance. Higher-priority harness instructions still apply. If guidance conflicts with an established public contract, explain the conflict rather than silently changing behavior.

## Repository exploration

Search narrowly first. Prefer existing project code, then Swift Standard Library and Apple frameworks, then existing dependencies.

## Write plainly

Use concise, plain language in everything you produce: replies, reports, plans, specs, issues, review findings, doc comments, and code comments.

- Use short sentences, one idea each, and common, concrete words.
- Use active voice and name the actor: "FlatMark cancels the request."
- Cut filler and hype such as "simply", "robust", "seamless", and "leverage".
- Use bullets or tables for lists; link to authoritative guidance instead of repeating it.
- Keep evidence-bearing qualifications: "iOS is unverified", not "it may possibly behave differently".

Brevity must not cost precision. Do not shorten a verification claim, public contract, or security statement until it becomes vague or wrong.

## Code style

Write comments under [Write plainly](#write-plainly). Say why, or name the invariant that holds; do not narrate the next line. Doc comments state the contract a caller can rely on. Omit parameter restatements.

Extract meaningful responsibilities or UI components, not arbitrary line counts. Prefer inlining over one-caller helpers or empty proxies without a distinct responsibility. Consider decomposition before lint suppression.

Do not run unrelated repository-wide formatting or automatic lint fixes, or assume a formatting hook exists.

## Git

Unless explicitly requested, do not commit, push, merge, rebase, create PRs, or create tags. Preserve unrelated working-tree changes. Do not bypass configured hooks. Tagging is a release act: follow [RELEASING.md](RELEASING.md) only when the maintainer asks for a release.

## Reports

Scale reports to the task and write them under [Write plainly](#write-plainly). For issue implementation, briefly include:

- selected issue and completed behavior;
- files changed and important decisions;
- verification performed, distinguishing inspection, compilation, automated tests, and running-app observations;
- remaining uncertainty;
- a suggested imperative commit message.

Do not describe unobserved UI behavior as verified; see [AI-docs/BUILD_AND_TEST.md](AI-docs/BUILD_AND_TEST.md). For other tasks, report the outcome, relevant verification, and remaining uncertainty without an unnecessary implementation template.

Stop after completing and verifying the selected issue. Do not pick up another issue or automatically close it.
