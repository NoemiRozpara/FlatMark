@testable import FlatMark
import Foundation
import SwiftUI
import Testing

@MainActor
struct FlatMarkInlineViewTests {
    @Test func emptyHTMLPairComposesWithoutAddedSpaces() throws {
        let document = FlatMarkRenderProjector.project(markdown: "a<u></u>b")
        guard case let .paragraph(content) = try #require(document.blocks.first).kind else {
            Issue.record("Expected a paragraph")
            return
        }
        let policies: [(FlatMarkUnsupportedContentPolicy, String)] = [
            (.literal, "a<u></u>b"), (.omit, "ab"),
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
