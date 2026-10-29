# UI

## Philosophy

Build native SwiftUI rendering that embeds in a host's interface without requiring its application architecture. Prefer composition and platform capabilities over custom infrastructure. Support iOS, iPadOS, and macOS, including VoiceOver, Dynamic Type, and right-to-left layout.

The [README](../README.md) and [support matrix](../SUPPORT.md) own public behavior and documented layout/selection limits. Do not promise browser-like typesetting or continuous selection across arbitrary native views.

## Components and semantics

Use the most specialized appropriate native control and styling APIs. Do not wrap controls only for styling or recreate semantics SwiftUI already provides. Extract custom components for meaningful rendering or interaction responsibilities, not arbitrary line-count targets.

Read inherited state such as `isEnabled` from the environment rather than duplicating it in initializers. Override accessibility only when native semantics are missing, ambiguous, duplicated, misleading, or incorrect.

Keep implementation components internal unless there is a justified host need. Unlike an application's screen library, FlatMark deliberately exposes an embeddable view and supporting types; do not impose a rule that only full screens may be public.

## State and ownership

Follow [ARCHITECTURE.md](ARCHITECTURE.md): source and persistence belong to the host; documents pair source with projection; render-time settings remain independent of construction inputs.

Use local state only for renderer-owned presentation and lifecycle needs. Do not introduce required screen Binding Models, routers, coordinators, repositories, or an application environment. Keep semantic actions explicit through the established host callbacks.

Avoid making unrelated render-setting changes reset surviving tasks, custom content, or image requests. Respect the documented distinction between surviving identity and state inside views removed by a policy change.

## Task markers

Custom marker drawings are passive. Do not add a button, toggle, gesture, or separate accessibility element to them. FlatMark owns interaction, hit testing, checked-state semantics, and disabled behavior.

Keep drawing and editing independent: custom markers also apply to read-only and nested tasks. Tasks without an editing address remain static. Verify that one activation affects only its selected source marker and that inherited disabling prevents edits.

## Links and custom content

Keep Markdown-link activation, task activation, and host replacement controls independently actionable. Do not add enclosing actions or accessibility proxies that swallow or duplicate a host control's behavior.

Custom unsupported-content views retain their structural position and ambient environment. Do not synthesize spaces, fallback wording, minimum-size boxes, or copied inline text styling that the public contract does not promise. An empty custom view is not the same as recursive omission.

Application routing remains host-owned. Do not add navigation containers, choose presentation styles, or turn fragment links into internal document scrolling without an agreed public change.

## Images

The host owns fetching, decoding, authentication, and caching. FlatMark owns loading presentation, failure/success transitions, and cancellation. Use the existing loader configuration identity contract to decide when requests restart; do not let unrelated view refreshes become new requests.

Keep image-fetch policy separate from linked-image navigation permission. Do not introduce implicit network access for default placeholders, raw HTML, or rejected sources.

## Layout and appearance

Design for changing content, not fixed device sizes. Prefer intrinsic sizing, natural reflow, multiline text, and adaptive layout. Avoid fixed text dimensions, fixed font sizes, and single-line assumptions unless required by a deliberate documented behavior.

Use numeric constants for meaningful visual properties rather than device-specific workarounds. Respect ambient host styles where supported; do not impose ToDoo theme infrastructure or require a global theme environment.

Check narrow and wide widths, enlarged system text, RTL, nested blocks, tables, mixed inline content, and empty structures when relevant. A nonzero measured size does not establish readable geometry. Do not add synthetic content merely to make an inspection helper succeed.

## Accessibility and previews

Prefer correct native semantics over manual labels and actions. Check labels, checked state, nesting, focus order, independent actions, keyboard activation, and disabled/read-only behavior where applicable. State must remain distinguishable without color alone.

Previews and verification hosts must work without live services or a bootstrapped application. Reuse shared fixtures and lightweight callbacks; do not duplicate the Recipe Lab into a second fixture system. Add representative previews where they make the component easier to inspect; use `@Previewable` state only where available on the supported preview toolchain.

Follow [BUILD_AND_TEST.md](BUILD_AND_TEST.md) and the [testing guide](../Tests/README.md) for evidence. Exported native text, semantic trees, automated callbacks, and screenshots answer different questions. Live VoiceOver, actual selection gestures, and visual layout require corresponding runtime observations.
