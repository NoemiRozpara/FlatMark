@testable import FlatMark
import Foundation
import SwiftUI
import Testing

// MARK: - FlatMarkInlineViewTests

@MainActor
struct FlatMarkInlineViewTests {
    @Test
    func `custom text keeps supported attributes breaks and image positions`() throws {
        let document = FlatMarkRenderProjector.project(
            markdown: "**before <u>x</u>**\n[linked <u>y</u>](https://example.com/md) ![alt](https://example.com/image.png)"
        )
        guard case let .paragraph(content) = try #require(document.blocks.first).kind else {
            Issue.record("Expected a paragraph")
            return
        }

        let policy = FlatMarkUnsupportedContentPolicy.custom(inline: { source in AttributedString("custom(\(source))") })
        let view = FlatMarkInlineView(
            content: content,
            context: FlatMarkRenderContext(unsupportedContentPolicy: policy)
        )
        let elements = FlatMarkInlineView.inlineElements(for: content, policy: policy)
        let text = elements.compactMap { element -> AttributedString? in
            if case let .text(text) = element.content {
                text
            } else {
                nil
            }
        }
        let replacements = text.map { String($0.characters) }.filter { $0.hasPrefix("custom(") }
        #expect(content.containsImages)
        #expect(view.renderingMode == .inlineText)
        #expect(replacements == ["custom(<u>)", "custom(</u>)", "custom(<u>)", "custom(</u>)"])
        #expect(text.first?
            .runs
            .allSatisfy { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true } == true)
        let linked = try #require(text.first { String($0.characters) == "linked " })
        #expect(linked.runs.allSatisfy { $0.link == URL(string: "https://example.com/md") })
        #expect(elements.contains { $0.content == .lineBreak })
        guard case let .image(index, image) = try #require(elements.last).content else {
            Issue.record("Expected the unaffected image after the replacements")
            return
        }

        #expect(index == content.components.count - 1)
        #expect(image.url == URL(string: "https://example.com/image.png"))
    }

    /// Both tags of an HTML pair that carries nothing between them stay two positions under every
    /// policy, with the supported text on either side of them in its own slot.
    ///
    /// Empty replacements contribute no element. This checks composition, not visible geometry.
    @Test
    func `keeps an empty HTML pair in two inline positions for every policy`() throws {
        let document = FlatMarkRenderProjector.project(markdown: "a<u></u>b")
        guard case let .paragraph(content) = try #require(document.blocks.first).kind else {
            Issue.record("Expected a paragraph")
            return
        }

        let policies: [(FlatMarkUnsupportedContentPolicy, [String])] = [
            (.literal, ["a", "<u>", "</u>", "b"]),
            (.omit, ["a", "b"]),
            (.custom(inline: { AttributedString("custom(\($0))") }), ["a", "custom(<u>)", "custom(</u>)", "b"]),
            (.custom(inline: { _ in AttributedString() }), ["a", "b"]),
        ]

        #expect(!content.containsImages)
        for (policy, expected) in policies {
            #expect(FlatMarkInlineView.inlineElements(for: content, policy: policy).map(shaped) == expected)
            #expect(policy.plainText(for: content) == expected.joined())
            #expect(FlatMarkInlineView(
                content: content,
                context: FlatMarkRenderContext(unsupportedContentPolicy: policy)
            ).renderingMode == .inlineText)
        }
    }

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
        let elements = FlatMarkInlineView.inlineElements(
            for: .init(components: [
                .text(AttributedString("Several words before ")),
                .image(image),
                .text(AttributedString(" and several words after")),
            ]),
            policy: .literal
        )

        #expect(elements.count == 3)
        #expect(elements[0].content == .text(AttributedString("Several words before ")))
        #expect(elements[1].content == .image(componentIndex: 1, image: image))
        #expect(elements[2].content == .text(AttributedString(" and several words after")))
    }

    @Test
    func `linked image flow preserves explicit line breaks`() {
        let elements = FlatMarkInlineView.inlineElements(
            for: .init(components: [
                .text(AttributedString("Before\nafter")),
                .image(FlatMarkRenderImage(
                    url: nil,
                    altText: "Diagram",
                    link: URL(string: "https://example.com/details")
                )),
            ]),
            policy: .literal
        )

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
            context: .readOnly
        )
    }

    /// What one inline element contributes, spelled so one expectation reads the same way under all
    /// three policies, including host-returned text.
    private func shaped(_ element: FlatMarkInlineView.InlineElement) -> String {
        switch element.content {
        case let .text(text):
            String(text.characters)
        case .lineBreak:
            "line break"
        case .image:
            "image"
        }
    }
}
