# UI

## Native rendering

Use native SwiftUI composition and platform capabilities without requiring host application architecture. Support iOS, iPadOS, macOS, VoiceOver, Dynamic Type, and RTL. The [README](../README.md) and [support matrix](../SUPPORT.md) own behavior and layout/selection limits; do not promise browser typesetting or continuous selection across arbitrary native views.

Use specialized native controls and styling APIs rather than wrappers or recreated semantics. Extract components for meaningful responsibilities, not line counts. Read inherited state such as `isEnabled` from the environment. Override accessibility only when native semantics are missing, ambiguous, duplicated, misleading, or wrong.

Keep implementation components internal unless hosts need them. FlatMark exposes an embeddable view and supporting types; public APIs need not be full screens.

## State and ownership

Follow [ARCHITECTURE.md](ARCHITECTURE.md) for snapshots, construction inputs, render settings, and host responsibilities. Local state serves renderer-owned presentation and lifecycle only. Do not require screen Binding Models, routers, coordinators, repositories, or an application environment. Use established host callbacks for semantic actions.

Unrelated render-setting changes must not reset surviving tasks or image requests. State inside views removed by policy changes need not survive.

## Tasks and links

Custom marker drawings are passive: no button, toggle, gesture, or separate accessibility element. FlatMark owns interaction, hit testing, checked-state semantics, and disabling. Drawing remains independent of editing, including read-only and nested tasks; tasks without addresses stay static. Verify that activation changes only the selected source marker and inherited disabling prevents edits.

Keep Markdown links and task activation independently actionable. Enclosing actions or accessibility proxies must not swallow or duplicate controls. Routing stays host-owned: do not add navigation containers, choose presentation styles, or implement fragment scrolling without an agreed public change.

## Images

Follow architecture's host-loader ownership. FlatMark owns presentation, failure/success transitions, and cancellation. Restart requests according to the loader configuration identity contract, not unrelated refreshes.

Keep image-fetch policy separate from linked-image navigation permission. Default placeholders, raw HTML, and rejected sources must not cause implicit network access.

## Layout and appearance

Prefer intrinsic sizing, reflow, multiline text, and adaptive layout over fixed device sizes. Avoid fixed text dimensions, font sizes, and single-line assumptions unless deliberate documented behavior requires them. Numeric constants should represent visual properties, not device workarounds.

Respect supported ambient host styles; do not require host theme infrastructure or a global theme environment. Where relevant, check narrow/wide widths, enlarged text, RTL, nested blocks, tables, mixed inline content, and empty structures. Nonzero size does not prove readable geometry; do not add synthetic content to satisfy inspection helpers.

## Accessibility and previews

Prefer native semantics over manual labels/actions. Check labels, checked state, nesting, focus order, independent actions, keyboard activation, and disabled/read-only behavior where applicable. State must be distinguishable without color alone.

Previews and verification hosts must run without live services or application bootstrap. Reuse shared fixtures and lightweight callbacks, not a second Recipe Lab fixture system. Add previews where they aid inspection; use `@Previewable` only with a supported toolchain.

Follow [BUILD_AND_TEST.md](BUILD_AND_TEST.md) and the [testing guide](../Tests/README.md). Exported text, semantic trees, callbacks, and screenshots prove different things. Live VoiceOver, selection gestures, and visual layout require corresponding runtime observations.
