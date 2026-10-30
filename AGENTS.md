# AGENTS.md

## Goal and scope

Implement the smallest correct change that satisfies the current task. Optimize for clarity, correctness, maintainability, and reviewability.

FlatMark is a native SwiftUI Markdown preview renderer, not an editor, browser, HTML sanitizer, or application framework. Preserve host ownership of persistence, image fetching, navigation decisions, and custom content. See [README.md](README.md) for scope and public contracts.

- Follow the agreed direction; do not add unrelated cleanup, speculative abstractions, or hypothetical future requirements.
- Preserve existing architecture. Obtain agreement before materially changing scope or architecture or adding dependencies.
- If implementation invalidates an important agreed assumption, stop and explain the conflict before redesigning.

## Read relevant guidance

Read only the documents relevant to the task:

- [AI-docs/PLANNING.md](AI-docs/PLANNING.md): clarification, specifications, issue creation, and issue pickup.
- [AI-docs/ARCHITECTURE.md](AI-docs/ARCHITECTURE.md): snapshots, rendering, host ownership, and package boundaries.
- [AI-docs/UI.md](AI-docs/UI.md): native semantics, layout, interaction, accessibility, and custom content.
- [AI-docs/BUILD_AND_TEST.md](AI-docs/BUILD_AND_TEST.md): toolchain requirements, verification selection, demo generation, and reporting.
- [AI-docs/CODE_REVIEW.md](AI-docs/CODE_REVIEW.md): code review and specialist selection.

`AGENTS.md` owns repository-wide rules; `AI-docs/` owns contributor policy; task skills own procedures and on-demand examples. Link to the authoritative source rather than copying its rules. Load only relevant skill references, not entire reference folders.

Within repository guidance, prefer this file, then `AI-docs/`, then tool-specific guidance. Higher-priority harness instructions still apply. If guidance conflicts with an established public contract, explain the conflict rather than silently changing behavior.

## Repository exploration

Search narrowly first. Prefer existing project code, then Swift Standard Library and Apple frameworks, then existing dependencies.

## Write plainly

Use concise, plain language in everything you produce: replies, reports, plans, specs, issues, review findings, doc comments, and code comments.

- Write short sentences with one idea each. Split long or nested sentences.
- Use common, concrete words. Prefer the plain word over the formal one.
- Prefer active voice and name the actor: "FlatMark cancels the request," not "the request is cancelled by the renderer."
- Cut filler and hype: "it's important to note", "simply", "actually", "robust", "seamless", "comprehensive", "leverage", "utilize", "delve".
- Use bullets or tables for lists of facts instead of long prose.
- Link to the authoritative document instead of restating it.
- Keep hedges that carry evidence. "iOS is unverified" is required; "it may possibly behave differently" is not.

Brevity must not cost precision. Do not shorten a verification claim, public contract, or security statement until it becomes vague or wrong.

## Code style

Write comments under [Write plainly](#write-plainly). Say why, or name the invariant that holds; do not narrate the next line. Doc comments state the contract a caller can rely on. Omit parameter restatements.

Extract code only when there is a meaningful responsibility or UI component to separate. Cohesive SwiftUI layout need not be split to meet an arbitrary size metric.

Prefer inlining over one-caller functions or empty proxies that add no meaningful responsibility. Do not introduce lint suppressions without first considering decomposition. Do not run repository-wide formatting or automatic lint fixes as unrelated cleanup; do not assume a formatting hook is installed.

## Git

Unless explicitly requested, do not commit, push, merge, rebase, or create PRs. Preserve unrelated working-tree changes. Do not bypass configured hooks.

## Reports

Scale reports to the task and write them under [Write plainly](#write-plainly). For issue implementation, briefly include:

- selected issue and completed behavior;
- files changed and important decisions;
- verification performed, distinguishing inspection, compilation, automated tests, and running-app observations;
- remaining uncertainty;
- a suggested imperative commit message.

Do not describe unobserved UI behavior as verified; see [AI-docs/BUILD_AND_TEST.md](AI-docs/BUILD_AND_TEST.md). For other tasks, report the outcome, relevant verification, and remaining uncertainty without an unnecessary implementation template.

Stop after completing and verifying the selected issue. Do not pick up another issue or automatically close it.
