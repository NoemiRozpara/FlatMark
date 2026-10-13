import Foundation
import Markdown

/// Converts Markdown inline nodes into renderer values.
struct FlatMarkInlineAttributedStringProjector: MarkupVisitor {
    typealias Result = FlatMarkRenderInlineContent

    let baseURL: URL?

    mutating func project(_ markup: Markup) -> FlatMarkRenderInlineContent {
        visit(markup)
    }

    mutating func defaultVisit(_ markup: Markup) -> FlatMarkRenderInlineContent {
        markup.children.reduce(into: FlatMarkRenderInlineContent()) { result, child in
            result.append(contentsOf: visit(child))
        }
    }

    mutating func visitText(_ text: Markdown.Text) -> FlatMarkRenderInlineContent {
        FlatMarkRenderInlineContent(text: AttributedString(text.string))
    }

    mutating func visitSoftBreak(_: SoftBreak) -> FlatMarkRenderInlineContent {
        FlatMarkRenderInlineContent(text: AttributedString("\n"))
    }

    mutating func visitLineBreak(_: LineBreak) -> FlatMarkRenderInlineContent {
        FlatMarkRenderInlineContent(text: AttributedString("\n"))
    }

    mutating func visitStrong(_ strong: Strong) -> FlatMarkRenderInlineContent {
        applying(.stronglyEmphasized, to: strong)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> FlatMarkRenderInlineContent {
        applying(.emphasized, to: emphasis)
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> FlatMarkRenderInlineContent {
        applying(.strikethrough, to: strikethrough)
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> FlatMarkRenderInlineContent {
        var result = AttributedString(inlineCode.code)
        result.inlinePresentationIntent = .code
        return FlatMarkRenderInlineContent(text: result)
    }

    mutating func visitLink(_ link: Link) -> FlatMarkRenderInlineContent {
        var result = defaultVisit(link)

        if let destination = link.destination,
           let url = FlatMarkURLResolver.resolve(destination, relativeTo: baseURL)
        {
            result.applyLink(url)
        }

        return result
    }

    mutating func visitImage(_ image: Markdown.Image) -> FlatMarkRenderInlineContent {
        let altText = defaultVisit(image).plainText
        return FlatMarkRenderInlineContent(
            components: [.image(FlatMarkRenderImage(
                url: image.source.flatMap { FlatMarkURLResolver.resolve($0, relativeTo: baseURL) },
                altText: altText
            ))]
        )
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> FlatMarkRenderInlineContent {
        FlatMarkRenderInlineContent(text: AttributedString("HTML: \(inlineHTML.rawHTML)"))
    }

    private mutating func applying(
        _ intent: InlinePresentationIntent,
        to markup: Markup
    ) -> FlatMarkRenderInlineContent {
        var result = defaultVisit(markup)
        result.applyPresentationIntent(intent)
        return result
    }
}
