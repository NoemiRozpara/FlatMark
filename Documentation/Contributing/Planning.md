# Planning workflow

Use this workflow for new work. Explicitly requested, bounded implementation or maintenance can proceed under [AGENTS.md](../../AGENTS.md) without a PRD or issue.

## 1. Clarify and specify

Use installed `grill` for clarification or stress-testing and `to-spec` for PRD synthesis when available. Otherwise write the agreed specification directly; unavailable helpers must not block agreed work.

For architecture, refactoring, state modeling, or code-smell discussions, identify the concrete problem first. Compare the smallest change and leaving code unchanged with alternatives that could affect the decision. Explain benefits and material tradeoffs; challenge unnecessary complexity and violations of renderer/host responsibilities.

Agree on:

- Scope, non-goals, user stories, observable acceptance criteria, risks, and meaningful verification.
- `track`: `product` for behavior delivery or `learning` for a concrete uncertainty. Learning work needs a bounded experiment and evidence that determines the next decision.
- A proportionate, code-grounded technical direction: integration points, ownership, contracts, important transitions, and behavior to preserve.

Investigate repository facts and obtain agreement on consequential choices. Resolve essential uncertainties or assign bounded learning work; leave routine coding and test sequencing to implementation. Where relevant, consider public compatibility, minimum platforms, source preservation, construction versus render-time settings, and host ownership. Identify needed README, support, testing-limit, or benchmark updates without copying those documents.

The user confirms shared understanding before PRD synthesis. Write agreed PRDs to `AI-docs/prds/<feature-slug>.md`. Preserve agreed behavior and decisions, distinguish facts from open questions, and include only justified requirements. Use verified code anchors as navigation hints, not frozen APIs. Give stories and acceptance criteria stable IDs such as `US-01` and `AC-01`.

This stage produces a local PRD, not issues or implementation. Follow [Write plainly](../../AGENTS.md#write-plainly): one requirement per sentence, no preamble or restating linked guidance. Finish with the path and a compact decision summary for the next thread; exploratory work without a PRD needs only the summary.

## 2. Create issues in a fresh thread

Use installed `to-tickets` for slice design and issue creation when available; otherwise prepare drafts directly. Obtain approval before publication. Local-specification approval does not authorize publishing issues.

The PRD is the handoff; do not depend on previous chat. Ground each child issue in affected code and representative tests. Include the relevant stories, requirements, decisions, constraints, acceptance criteria, verification, and explicit blockers so implementation needs neither chat nor the full PRD. Add verified entry points, a short ordered approach, and preservation hazards; show that approach for approval. Keep each acceptance criterion short and testable, and omit background shown by code anchors.

Do not leave missing product or architecture decisions to implementation. Self-contained pickup does not guarantee conflict-free parallel edits.

Verification covers observable behavior, important edge cases, existing test boundaries/support, and required running-app checks. Add scenarios where they resolve ambiguity, not a fixed first failing test or sequence. Follow [build and test](BuildAndTest.md): reuse coverage, avoid redundant tests, and leave the next example to implementation.

### Tracker policy

Resolve the publication repository from FlatMark's current Git remote, not an assumed consumer repository or project. Add no labels, milestones, project membership, or custom fields without explicit agreement; `track` can stay in the PRD and issue body.

Read back published content and relationships. Report publication failures; do not silently substitute another repository or tracker.

## 3. Implement one issue per fresh thread

Read the selected child's complete body and relevant comments, repository guidance, and affected code. The child should supply context without rereading the parent PRD. Stop on unresolved blockers or missing essential context and request clarification.

Implement the smallest correct change meeting acceptance criteria. Revalidate anchors and assumptions, especially after blockers land; stop if a major assumption fails. Follow [build and test](BuildAndTest.md) and use installed TDD for suitable behavior changes. Inspect coverage, then work one meaningful failing behavioral example → minimal implementation → small green-state refactoring at a time. Do not write all tests upfront or add redundant preservation tests.

Use the issue's agreed verification context without reopening settled decisions. Update authoritative public and verification documentation when behavior or evidence changes. Report and stop under [AGENTS.md](../../AGENTS.md); do not close the issue or start another task automatically.
