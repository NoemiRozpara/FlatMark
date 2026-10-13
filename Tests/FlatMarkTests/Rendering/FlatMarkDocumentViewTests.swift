import Foundation
import Testing
@testable import FlatMark

// MARK: - FlatMarkTableViewTests

@MainActor
struct FlatMarkTableViewTests {
    @Test
    func `renders a table with a header and no body rows`() {
        let view = FlatMarkTableView(
            table: FlatMarkRenderTable(
                header: [
                    .init(id: "header.name", content: "Name", colspan: 1),
                ],
                rows: []
            )
        )

        #expect(view.rendersTable)
    }

    @Test
    func `does not render an empty table`() {
        let view = FlatMarkTableView(
            table: FlatMarkRenderTable(header: [], rows: [])
        )

        #expect(!view.rendersTable)
    }
}

// MARK: - FlatMarkInlineViewTests

@MainActor
struct FlatMarkInlineViewTests {
    @Test
    func `ordinary images use native selectable inline text`() {
        let view = inlineView(components: [
            .text(AttributedString("Before ")),
            .image(FlatMarkRenderImage(url: nil, altText: "Diagram")),
            .text(AttributedString(" after")),
        ])

        #expect(view.renderingMode == .inlineText)
    }

    @Test
    func `text links and hard breaks keep ordinary images in native inline text`() {
        var linkedText = AttributedString("Read details")
        linkedText.link = URL(string: "https://example.com/details")
        let view = inlineView(components: [
            .text(linkedText + AttributedString("\n")),
            .image(FlatMarkRenderImage(url: nil, altText: "Diagram")),
        ])

        #expect(view.renderingMode == .inlineText)
    }

    @Test
    func `mixed linked images use independent controls`() {
        let view = inlineView(components: [
            .text(AttributedString("Before ")),
            .image(FlatMarkRenderImage(
                url: nil,
                altText: "Diagram",
                link: URL(string: "https://example.com/details")
            )),
            .text(AttributedString(" after")),
        ])

        #expect(view.renderingMode == .linkedImageFlow)
    }

    @Test
    func `linked image flow groups text on either side of an image`() {
        let image = FlatMarkRenderImage(
            url: URL(string: "https://example.com/image.png"),
            altText: "Diagram",
            link: URL(string: "https://example.com/details")
        )
        let elements = FlatMarkInlineView.inlineElements(for: .init(components: [
            .text(AttributedString("Several words before ")),
            .image(image),
            .text(AttributedString(" and several words after")),
        ]))

        #expect(elements.count == 3)
        #expect(elements[0].content == .text(AttributedString("Several words before ")))
        #expect(elements[1].content == .image(componentIndex: 1, image: image))
        #expect(elements[2].content == .text(AttributedString(" and several words after")))
    }

    @Test
    func `linked image flow preserves explicit line breaks`() {
        let elements = FlatMarkInlineView.inlineElements(for: .init(components: [
            .text(AttributedString("Before\nafter")),
            .image(FlatMarkRenderImage(
                url: nil,
                altText: "Diagram",
                link: URL(string: "https://example.com/details")
            )),
        ]))

        #expect(elements.map(\.content) == [
            .text(AttributedString("Before")),
            .lineBreak,
            .text(AttributedString("after")),
            .image(
                componentIndex: 1,
                image: FlatMarkRenderImage(
                    url: nil,
                    altText: "Diagram",
                    link: URL(string: "https://example.com/details")
                )
            ),
        ])
    }

    @Test
    func `standalone linked image uses a surrounding link`() throws {
        let destination = try #require(URL(string: "https://example.com/details"))
        let view = inlineView(components: [
            .image(FlatMarkRenderImage(
                url: nil,
                altText: "Diagram",
                link: destination
            )),
        ])

        #expect(view.renderingMode == .standaloneLinkedImage(destination))
    }

    private func inlineView(
        components: [FlatMarkRenderInlineContent.Component]
    ) -> FlatMarkInlineView {
        FlatMarkInlineView(
            content: FlatMarkRenderInlineContent(components: components),
            imageLoader: nil,
            imageURLPolicy: .webOnly
        )
    }
}
