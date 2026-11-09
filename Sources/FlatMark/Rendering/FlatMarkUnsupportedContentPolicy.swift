import Foundation

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
public enum FlatMarkUnsupportedContentPolicy: Hashable, Sendable {
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
}

// MARK: - Policy interpretation

extension FlatMarkUnsupportedContentPolicy {
    /// The inert text one unsupported node contributes.
    ///
    /// Under ``omit`` the answer is empty text; ``presents(_:)`` also removes the corresponding
    /// layout slot.
    func literalText(
        for content: FlatMarkRenderUnsupportedContent
    ) -> AttributedString {
        switch self {
        case .literal:
            content.literalText
        case .omit:
            AttributedString()
        }
    }

    /// The plain text one inline span contributes under this policy.
    ///
    /// Omitted nodes add no wording.
    func plainText(for content: FlatMarkRenderInlineContent) -> String {
        FlatMarkRenderInlineContent.plainText(of: content.components) {
            literalText(for: $0)
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
        case .literal:
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
