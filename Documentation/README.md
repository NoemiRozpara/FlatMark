# Documentation

## Using FlatMark

- [Introduction, installation, and quick start](../README.md)
- [Usage guide](Usage.md): tasks, retained documents, navigation, images, and rendering policies.
- [Markdown support](MarkdownSupport.md): supported constructs and their behavior.
- [Demo](../Demo/README.md): run the example host and explore its settings.
- [Known performance limits and benchmarks](../Benchmarks/README.md): measured costs and their qualifications.
- [Testing and verification status](../Tests/README.md): what automation establishes and what remains unverified.
- [Security policy](../SECURITY.md): private reporting, threat model, and host responsibilities.
- [Versioning policy](Versioning.md) and [changelog](../CHANGELOG.md).

The API reference is authored in the [DocC catalog](../Sources/FlatMark/FlatMark.docc/FlatMark.md)
and public Swift doc comments. See [building the documentation](Releasing.md#5-build-the-documentation)
for the native Xcode workflow.

## Contributing

Start with [CONTRIBUTING.md](../CONTRIBUTING.md) for setup, commands, and contribution expectations.
Read the guides relevant to your change:

| Guide | Covers |
| --- | --- |
| [Architecture](Contributing/Architecture.md) | Snapshots, projection, package boundaries, and host ownership. |
| [Build and test](Contributing/BuildAndTest.md) | Toolchains, verification selection, CI lanes, and evidence boundaries. |
| [UI](Contributing/UI.md) | Native semantics, state, layout, interaction, and accessibility. |
| [Code review](Contributing/CodeReview.md) | Review priorities and specialist selection. |
| [Device Hub](Contributing/DeviceHub.md) | Driving running devices, resizing, capture, and settings. |
| [Planning](Contributing/Planning.md) | Specifications, issue publication, and implementation handoffs. |

Detailed procedures stay beside their subjects: [demo setup](../Demo/README.md),
[test and snapshot procedures](../Tests/README.md), [Recipe Lab captures](../Tests/References/RecipeLab/README.md),
and [benchmark procedures](../Benchmarks/README.md).

[AGENTS.md](../AGENTS.md) defines repository rules for coding agents. Local PRDs, ticket drafts,
and handoffs stay under `AI-docs/`, separate from reference documentation.

## Maintaining releases

- [Versioning](Versioning.md): compatibility guarantees and release numbering.
- [Release checklist](Releasing.md): candidate verification, documentation, tagging, and publication.
- [Changelog](../CHANGELOG.md): released changes.
