@testable import FlatMark
import Foundation
import SwiftUI
import Testing

@MainActor
struct FlatMarkInlineViewTests {
    @Test func customTextKeepsBreaksLinksAndImagePositions() throws {
        let document = FlatMarkRenderProjector.project(
            markdown: "**before <u>x</u>**\n[linked <u>y</u>](https://example.com/md) ![alt](https://example.com/image.png)"
        )
        guard case let .paragraph(content) = try #require(document.blocks.first).kind else {
            Issue.record("Expected a paragraph")
            return
        }
        let native = flatMarkNativeInlineText(content, policy: .custom { AttributedString("custom(\($0))") })
        #expect(native.string == "before custom(<u>)xcustom(</u>)\nlinked custom(<u>)ycustom(</u>) \u{FFFC} alt")
        let linked = (native.string as NSString).range(of: "linked ")
        #expect(native.attribute(.link, at: linked.location, effectiveRange: nil) as? URL
            == URL(string: "https://example.com/md"))
    }

    @Test func emptyHTMLPairComposesWithoutAddedSpaces() throws {
        let document = FlatMarkRenderProjector.project(markdown: "a<u></u>b")
        guard case let .paragraph(content) = try #require(document.blocks.first).kind else {
            Issue.record("Expected a paragraph")
            return
        }
        let policies: [(FlatMarkUnsupportedContentPolicy, String)] = [
            (.literal, "a<u></u>b"), (.omit, "ab"),
            (.custom { AttributedString("custom(\($0))") }, "acustom(<u>)custom(</u>)b"),
            (.custom { _ in AttributedString() }, "ab"),
        ]
        for (policy, expected) in policies {
            #expect(flatMarkNativeInlineText(content, policy: policy).string == expected)
        }
    }

    @Test func ordinaryAndImageLinksKeepIndependentNativeRangesAcrossBreaks() throws {
        let destination = try #require(URL(string: "https://example.com/details"))
        var text = AttributedString("Read details")
        text.link = URL(string: "https://example.com/page")
        let native = flatMarkNativeInlineText(.init(components: [
            .text(text + AttributedString("\n\n")),
            .image(.init(url: nil, altText: "Diagram", link: destination)),
            .text(AttributedString(" after")),
        ]))
        #expect(native.string == "Read details\n\n\u{FFFC} Diagram after")
        #expect(native.attribute(.link, at: 0, effectiveRange: nil) as? URL == URL(string: "https://example.com/page"))
        #expect(native.attribute(.link, at: 14, effectiveRange: nil) as? URL == destination)
        #expect(native.attribute(.link, at: native.length - 1, effectiveRange: nil) == nil)
    }
}

/// Shared native-storage boundary for cross-platform composition assertions.
@MainActor
func flatMarkNativeInlineText(
    _ content: FlatMarkRenderInlineContent,
    policy: FlatMarkUnsupportedContentPolicy = .literal
) -> NSAttributedString {
    #if os(macOS)
    FlatMarkParagraphText.attributedText(for: content, policy: policy,
        layoutDirection: .leftToRight, alignment: .leading)
    #else
    FlatMarkParagraphText.attributedText(for: content, policy: policy,
        dynamicTypeSize: .large, layoutDirection: .leftToRight, alignment: .leading)
    #endif
}
