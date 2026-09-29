import Foundation
import Markdown

/// Converts Markdown inline nodes into SwiftUI's native rich-text value.
struct FlatMarkInlineAttributedStringProjector: MarkupVisitor {
    typealias Result = AttributedString

    mutating func project(_ markup: Markup) -> AttributedString {
        visit(markup)
    }

    mutating func defaultVisit(_ markup: Markup) -> AttributedString {
        markup.children.reduce(into: AttributedString()) { result, child in
            result += visit(child)
        }
    }

    mutating func visitText(_ text: Markdown.Text) -> AttributedString {
        AttributedString(text.string)
    }

    mutating func visitSoftBreak(_: SoftBreak) -> AttributedString {
        AttributedString("\n")
    }

    mutating func visitLineBreak(_: LineBreak) -> AttributedString {
        AttributedString("\n")
    }

    mutating func visitStrong(_ strong: Strong) -> AttributedString {
        applying(.stronglyEmphasized, to: strong)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> AttributedString {
        applying(.emphasized, to: emphasis)
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> AttributedString {
        applying(.strikethrough, to: strikethrough)
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> AttributedString {
        var result = AttributedString(inlineCode.code)
        result.inlinePresentationIntent = .code
        return result
    }

    mutating func visitLink(_ link: Link) -> AttributedString {
        var result = defaultVisit(link)

        if let destination = link.destination,
           let url = URL(string: destination),
           url.scheme != nil
        {
            result.link = url
        }

        return result
    }

    mutating func visitImage(_ image: Markdown.Image) -> AttributedString {
        let altText = String(defaultVisit(image).characters)
        let source = image.source.map { " (\($0))" } ?? ""
        return AttributedString("Image: \(altText.isEmpty ? "image" : altText)\(source)")
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> AttributedString {
        AttributedString("HTML: \(inlineHTML.rawHTML)")
    }

    private mutating func applying(
        _ intent: InlinePresentationIntent,
        to markup: Markup
    ) -> AttributedString {
        var result = defaultVisit(markup)

        for run in result.runs {
            let existingIntent = result[run.range].inlinePresentationIntent ?? []
            result[run.range].inlinePresentationIntent = existingIntent.union(intent)
        }

        return result
    }
}
