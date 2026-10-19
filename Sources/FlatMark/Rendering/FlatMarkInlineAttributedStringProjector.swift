import Foundation
import Markdown

/// Converts Markdown inline nodes into renderer values.
struct FlatMarkInlineAttributedStringProjector: MarkupVisitor {
    typealias Result = FlatMarkRenderInlineContent

    let source: String
    let baseURL: URL?

    mutating func project(_ markup: Markup) -> FlatMarkRenderInlineContent {
        visit(markup)
    }

    mutating func defaultVisit(_ markup: Markup) -> FlatMarkRenderInlineContent {
        guard isKnownContainer(markup) else {
            return FlatMarkRenderInlineContent(components: [.unsupported(unsupported(markup))])
        }

        return markup.children.reduce(into: FlatMarkRenderInlineContent()) { result, child in
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
        let altContent = defaultVisit(image)
        return FlatMarkRenderInlineContent(
            components: [.image(FlatMarkRenderImage(
                url: image.source.flatMap { FlatMarkURLResolver.resolve($0, relativeTo: baseURL) },
                altContent: altContent
            ))]
        )
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> FlatMarkRenderInlineContent {
        FlatMarkRenderInlineContent(components: [.unsupported(unsupported(inlineHTML))])
    }

    private mutating func applying(
        _ intent: InlinePresentationIntent,
        to markup: Markup
    ) -> FlatMarkRenderInlineContent {
        var result = defaultVisit(markup)
        result.applyPresentationIntent(intent)
        return result
    }

    /// A container whose children FlatMark projects one by one.
    ///
    /// Everything else that reaches ``defaultVisit(_:)`` has no visitor of its own and is not a
    /// container the renderer knows, so it becomes one unsupported value instead of having its
    /// descendants silently substituted for it.
    private func isKnownContainer(_ markup: Markup) -> Bool {
        switch markup {
        case is Document, is Paragraph, is Heading, is Table.Cell, is Strong, is Emphasis,
             is Strikethrough, is Link, is Image:
            true
        default:
            false
        }
    }

    /// The one extraction result every presentation policy of this node will show.
    private func unsupported(_ markup: Markup) -> FlatMarkRenderUnsupportedContent {
        FlatMarkRenderUnsupportedContent(
            literalText: FlatMarkUnsupportedContentExtractor.literal(from: markup, source: source)
        )
    }
}
