# Code review

For Swift and Apple-platform code review:

- Start with the installed `swift-code-review` skill as the primary reviewer.
- Review only; do not modify code unless explicitly asked to fix findings.
- Prioritize correctness, regressions, lifecycle, contracts, and behavior over style or subjective architecture.
- Ground findings in reachable code; distinguish demonstrated failures from unresolved risks.
- Follow [Write plainly](../../AGENTS.md#write-plainly): failure first, then evidence and impact.

## Specialist selection

- Add `swift-concurrency-expert` for material isolation, Sendable, task, cancellation, cross-isolation callback, or data-race risks.
- Add `swiftui-pro` for material state/observation, identity, accessibility, layout, interaction, animation, or rendering-performance risks.
- Imports or async/await alone do not justify escalation. UIKit/AppKit-only changes normally need only `swift-code-review`.

Read selected skills before use. Reconcile overlapping findings into one report.

## FlatMark review priorities

Review against the [public contracts](../../README.md), [support matrix](../MarkdownSupport.md), and [architecture](Architecture.md). In particular, consider:

- Public interface source compatibility and minimum-platform availability.
- Snapshot/source-coordinate pairing and byte-preserving task updates.
- Equivalent behavior between source and retained-document initializers.
- Stable surviving identity and image-loading state across render-setting changes.
- Loader configuration identity, cancellation, and stale asynchronous results.
- Correct separation of navigation permission and image-fetch permission.
- Native control semantics, disabled behavior, independent actions, and accessibility.
- Fixture, test-host, benchmark, and demo isolation from the consumed library product.

These are risk prompts, not a requirement to expand every review to the whole repository. Inspect the changed behavior and its relevant callers.

Use the [verification guide](BuildAndTest.md) to qualify evidence. Do not present a model assertion, exported text, or successful build as proof of visual or live accessibility correctness.
