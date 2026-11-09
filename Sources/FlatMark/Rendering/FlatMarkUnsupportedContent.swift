import Foundation
import Markdown

// MARK: - FlatMarkRenderUnsupportedContent

/// A block or inline span that the parser accepted but that has no native structural view.
///
/// ``literalText`` is inert: it comes from the extraction contract below, never from a
/// reconstructed serialization, and no HTML attribute is interpreted anywhere in the renderer.
struct FlatMarkRenderUnsupportedContent: Equatable, Sendable {
    var literalText: AttributedString
}

// MARK: - FlatMarkUnsupportedContentExtractor

/// Extracts one unsupported node's literal text before render-time policy decisions.
///
/// Raw HTML uses the parser's own ``rawHTML`` unchanged, including the trailing newline an
/// HTML block usually carries. Every other unsupported node first gets the exact source slice
/// its parser range addresses in the snapshot it came from, then readable descendant text, then
/// empty text. A type name, a diagnostic prefix, and an invented Markdown serialization never
/// reach the output.
enum FlatMarkUnsupportedContentExtractor {
    static func literal(from markup: any Markup, source: String) -> AttributedString {
        switch markup {
        case let htmlBlock as HTMLBlock:
            return AttributedString(htmlBlock.rawHTML)
        case let inlineHTML as InlineHTML:
            return AttributedString(inlineHTML.rawHTML)
        default:
            return AttributedString(sourceSlice(for: markup, source: source)
                ?? readableText(of: markup))
        }
    }

    /// Descendant leaves a reader could actually read, in source order, without Markdown
    /// delimiters.
    ///
    /// A code block and an HTML block are leaves that keep their content on themselves rather than
    /// in text children, so both answer from their own raw text.
    static func readableText(of markup: any Markup) -> String {
        switch markup {
        case let text as Text:
            text.string
        case let inlineCode as InlineCode:
            inlineCode.code
        case let html as InlineHTML:
            html.rawHTML
        case let codeBlock as CodeBlock:
            codeBlock.code
        case let htmlBlock as HTMLBlock:
            htmlBlock.rawHTML
        case is SoftBreak, is LineBreak:
            "\n"
        default:
            markup.children.map(readableText).joined()
        }
    }

    private static func sourceSlice(for markup: any Markup, source: String) -> String? {
        guard let range = markup.range.map(FlatMarkSourceRange.init) else {
            return nil
        }

        return range.text(in: source)
    }
}
