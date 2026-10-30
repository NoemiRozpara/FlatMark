# Planning workflow

Use this workflow for planning new work. Explicitly requested, bounded implementation or maintenance tasks can proceed directly under [AGENTS.md](../AGENTS.md); not every bug fix or documentation update needs a PRD or issue.

## 1. Clarify the idea and write the specification

Use the installed `grill` skill when clarification or stress-testing is needed. If `to-spec` is available, use it for PRD synthesis; otherwise write the agreed specification directly. Do not assume a referenced skill is installed or block an agreed task on an unavailable helper.

For architecture, refactoring, state modeling, or code-smell discussions:

- Identify the concrete problem before proposing structural changes.
- Consider the smallest change and leaving the code as-is alongside alternatives that could change the decision.
- Explain what each option improves, its material tradeoffs, and why the smallest justified solution is preferable.
- Challenge unnecessary complexity and violations of FlatMark's renderer/host responsibilities.

Settle scope, non-goals, user stories, observable acceptance criteria, risks, meaningful verification, and `track`: `product` for delivering behavior or `learning` for answering a specific uncertainty. Learning work needs a concrete question, a bounded experiment, and evidence that determines the next decision.

Establish a proportionate, code-grounded technical direction before ending clarification: integration points, ownership, contracts, important transitions, behavior to preserve, and meaningful verification. Investigate repository facts; obtain agreement on consequential choices; leave routine coding choices and test sequencing to implementation. Resolve essential uncertainties or assign them to agreed bounded learning work.

For FlatMark, explicitly consider public compatibility, minimum-platform support, source preservation, render-time versus construction settings, and host ownership where relevant. Identify required updates to the README, support matrix, testing limits, or benchmark documentation without duplicating those documents in the specification.

The user confirms shared understanding before PRD synthesis. Write agreed PRDs to `AI-docs/prds/<feature-slug>.md`. Preserve agreed behavior and technical decisions; distinguish repository facts from unresolved questions. Include verified code anchors as navigation hints rather than frozen APIs, and only requirements justified by the discussion. Give stories and acceptance criteria stable identifiers such as `US-01` and `AC-01`.

This stage produces a local PRD, not published issues or implementation. Write clarification questions and PRDs under [Write plainly](../AGENTS.md#write-plainly): one requirement per sentence, plain words, no preamble, and no restating linked documents. Finish with the path and a compact decision summary for the next thread. For exploratory requests without a PRD, finish with a compact decision summary instead.

## 2. Turn the PRD into issues in a fresh thread

If the installed `to-tickets` skill is available, use its slice-design and issue procedure. Otherwise prepare self-contained issue drafts directly. Obtain approval before publication; do not assume that approval of a local specification also authorizes publishing issues.

The PRD is the handoff; do not depend on the previous chat being available. Ground tickets in affected code and representative tests. Each child issue must include the relevant stories, requirements, decisions, constraints, acceptance criteria, verification, and explicit blockers needed for implementation without the full PRD. Write issue bodies under the same rule. Make each acceptance criterion one short testable sentence. Drop background that verified code anchors already show. Add verified entry points, a short ordered implementation approach, and preservation hazards; show the compact approach during approval.

Do not silently delegate missing product or architectural decisions to implementation. Self-contained pickup does not promise conflict-free simultaneous edits.

Verification describes observable behaviors, important edge cases, existing test boundaries and support, and required running-app checks. Use concrete scenario examples where they resolve ambiguity, not a mandatory first red scenario or fixed test sequence. Preserve the approach in [BUILD_AND_TEST.md](BUILD_AND_TEST.md): favor nonredundant behavioral coverage, reuse existing tests, and leave selection of each next example to implementation.

### Tracker policy

Resolve the publication repository from FlatMark's current Git remote; do not publish to a consumer application's repository or project by assumption. Do not add labels, milestones, project membership, or custom fields unless explicitly agreed. `track` remains useful in the PRD and issue body without requiring a matching tracker field.

Read back published issues to confirm their content and relationships. Report publication failures without silently substituting another repository or tracker.

## 3. Implement one issue in each fresh thread

Read the selected child issue's complete body and relevant comments, current repository guidance, and affected code. Do not require rereading the parent PRD: the child should contain the necessary context. Check listed blockers; if unresolved, report them and stop. If essential context is missing, request clarification rather than silently relying on the full PRD.

Implement the smallest correct change meeting the acceptance criteria. Revalidate ticket anchors and assumptions, especially after blockers land; stop if a major assumption no longer holds. Follow [BUILD_AND_TEST.md](BUILD_AND_TEST.md) and use the installed TDD skill for suitable behavior changes. Inspect existing coverage, then work one meaningful failing behavioral example → minimal implementation → small green-state refactoring at a time. Do not write all tests upfront or add redundant preservation tests.

Verification agreed in the issue supplies the testing context; do not repeat settled decisions merely because this is a fresh thread. Update the authoritative public and verification documentation when behavior or evidence changes.

Report under [AGENTS.md](../AGENTS.md) and stop. Do not automatically close issues or pick up another task in the same thread.
