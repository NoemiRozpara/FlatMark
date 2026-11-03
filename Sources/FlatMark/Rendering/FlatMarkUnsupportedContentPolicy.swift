import Foundation
import SwiftUI

// MARK: - FlatMarkUnsupportedContentPolicy

/// What the renderer does where Markdown carries content it cannot present natively.
///
/// FlatMark projects the Markdown constructs it supports and shows everything else under this
/// policy. A policy is chosen by the host, never by the document, so the same Markdown renders
/// the same way wherever the policy is the same.
///
/// ## Available policies
///
/// - ``literal`` renders unsupported content as inert source text.
/// - ``omit`` removes unsupported content, layout slot and all.
/// - ``custom`` replaces each unsupported node with attributed text or an optional block view.
///
/// The policy is neither `Equatable` nor `Sendable`: it travels in the non-`Sendable` render
/// context and is read while views are built, so identity and threading of a host closure are
/// the host's business rather than part of the value a document carries.
public enum FlatMarkUnsupportedContentPolicy {
    /// Show inert literal text, with the enclosing Markdown styling and links retained.
    ///
    /// The renderer never interprets HTML attributes: it does not restyle from them, navigate
    /// from them, load resources named by them, or run script from them. A Markdown link that
    /// legitimately encloses the content still opens, and a supported Markdown image still
    /// follows the host's image policy.
    case literal

    /// Remove unsupported content: no text, no placeholder, and no place in the layout.
    ///
    /// Omitting is not sanitizing. A supported sibling keeps its own meaning, and an unsupported
    /// node never has its descendants re-presented as supported content in its place.
    case omit

    /// Show host-provided attributed text, with an optional view override for block nodes.
    ///
    /// Inline nodes always use `inline`. Block nodes use `block` when supplied, or render
    /// `inline` output as native text. Both closures receive the same extracted string
    /// ``literal`` would show: the parser's raw HTML for an HTML node, otherwise the source
    /// slice the parser addressed, readable descendants, or empty text. An empty extraction
    /// still reaches the selected closure.
    ///
    /// These are presentation closures, not event callbacks; invocation counts are not
    /// guaranteed. FlatMark adds no literal fallback, diagnostic label, border, minimum-size
    /// box, or synthetic spaces. Block views keep their ambient environment, interaction,
    /// and accessibility. Interpretation, sanitization, fetching, and execution in custom
    /// output remain the host's responsibility.
    ///
    /// Inline text inherits ambient SwiftUI styles, including heading fonts. Each replacement run
    /// inherits enclosing Markdown presentation intents and links only where the host omits them.
    /// An explicit intent replaces the enclosing intent; an empty intent suppresses inheritance.
    /// A host link overrides the enclosing destination. Replacement links use the existing
    /// navigation callbacks. Hosts own explicit attributes and block-view actions and accessibility.
    ///
    /// Separate parser nodes remain separate calls: `<u>x</u>` supplies `<u>` and `</u>`, with
    /// supported `x` between the replacements. Known containers recurse; code, escaped HTML,
    /// and ordinary text do not dispatch. Inline flow may wrap whole text runs; selection can
    /// be fragmented across native runs/views, with no continuous-selection guarantee.
    ///
    /// Structural identity and ordinary parent spacing remain FlatMark's. Opaque empty output
    /// adds no placeholder or synthetic spaces, but does not request recursive `.omit` collapse.
    case custom(inline: (String) -> AttributedString, block: ((String) -> AnyView)? = nil)
}

// MARK: - Policy interpretation

extension FlatMarkUnsupportedContentPolicy {
    /// The inert text one unsupported node contributes.
    ///
    /// Literal sites and custom closure arguments share the extracted text. Under ``omit`` the
    /// answer is empty text; ``presents(_:)`` also removes the corresponding layout slot.
    func literalText(
        for content: FlatMarkRenderUnsupportedContent
    ) -> AttributedString {
        switch self {
        case .literal, .custom:
            content.literalText
        case .omit:
            AttributedString()
        }
    }

    /// The plain text one inline span contributes under this policy.
    ///
    /// Omitted nodes add no wording; custom nodes contribute their returned text.
    func plainText(for content: FlatMarkRenderInlineContent) -> String {
        FlatMarkRenderInlineContent.plainText(of: content.components) {
            FlatMarkInlineView.replacementText(for: $0, policy: self)
        }
    }

    /// The supported image retains its normal generic label when omission empties its description.
    func imageLabel(for image: FlatMarkRenderImage) -> String {
        let altText = plainText(for: image.altContent)
        return altText.isEmpty ? "Image" : altText
    }

    /// Whether a block still gets a place in the layout.
    ///
    /// Omission removes the unsupported node itself, so a paragraph, heading, or blockquote that
    /// only carried unsupported content loses its slot too, recursively and with the quote's
    /// rule. Lists, tables, code blocks, and dividers are supported structure, so their markers,
    /// rows, cell padding, and task controls stay where a reader can reach them even when the
    /// text beside them is gone.
    func presents(_ block: FlatMarkRenderBlock) -> Bool {
        switch self {
        case .literal, .custom:
            true
        case .omit:
            switch block.kind {
            case .unsupported:
                false
            case let .paragraph(content), let .heading(_, content):
                !content.isEmptiedByOmission
            case let .blockQuote(children):
                children.isEmpty || children.contains { presents($0) }
            case .codeBlock, .list, .table, .thematicBreak:
                true
            }
        }
    }
}
