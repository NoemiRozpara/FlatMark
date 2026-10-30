# Code review

For Swift and Apple-platform code review:

- Start with the installed `swift-code-review` skill as the primary reviewer.
- Review only; do not modify code unless explicitly asked to fix findings.
- Prefer concrete correctness, regression, lifecycle, public-contract, and behavioral findings over style or subjective architecture comments.
- Ground findings in reachable behavior and affected code. Distinguish demonstrated failures from unresolved risks.
- Write findings under [Write plainly](../AGENTS.md#write-plainly): state the failure first, then evidence and impact in short sentences.

## Specialist selection

- Use `swift-concurrency-expert` when concurrency is materially involved, including actor isolation, Sendable, tasks, async/await, cancellation, callbacks crossing isolation boundaries, or data-race concerns.
- Use `swiftui-pro` when SwiftUI-specific behavior is materially involved, especially state/observation, identity, accessibility, layout, interaction, animation, or rendering performance.
- Do not run escalation skills merely because a file imports SwiftUI or uses async/await. Escalate when that area is relevant to the risk being reviewed.
- UIKit/AppKit-only changes normally need only `swift-code-review`.

Read a selected skill's instructions before applying it. When multiple skills are used, reconcile overlapping findings into one report rather than reporting the same issue several times.

## FlatMark review priorities

Review against the [public contracts](../README.md), [support matrix](../SUPPORT.md), and [architecture](ARCHITECTURE.md). In particular, consider:

- Public interface source compatibility and minimum-platform availability.
- Snapshot/source-coordinate pairing and byte-preserving task updates.
- Equivalent behavior between source and retained-document initializers.
- Stable surviving identity and image-loading state across render-setting changes.
- Loader configuration identity, cancellation, and stale asynchronous results.
- Correct separation of navigation permission, image-fetch permission, and host-owned custom behavior.
- Native control semantics, disabled behavior, independent actions, and accessibility.
- Fixture, test-host, benchmark, and demo isolation from the consumed library product.

These are risk prompts, not a requirement to expand every review to the whole repository. Inspect the changed behavior and its relevant callers.

Use the [verification guide](BUILD_AND_TEST.md) to qualify evidence. Do not present a model assertion, exported text, or successful build as proof of visual or live accessibility correctness.
