import FlatMark
import FlatMarkFixtures
import Foundation
import Testing

// MARK: - FlatMarkDocumentTests

/// The public surface of a retained document: what it holds and when two of them are the same.
struct FlatMarkDocumentTests {
    private static let source = "Before **bold**, @jane, and [linked text](../other.md)."

    private static let baseURL = URL(string: "https://example.com/docs/readme.md")

    @Test
    func `default construction preserves the snapshot and yields equal documents`() {
        let document = FlatMarkDocument(markdown: Self.source)

        #expect(document.markdown == Self.source)
        #expect(document.baseURL == nil)
        #expect(document == FlatMarkDocument(markdown: Self.source))
    }

    @Test(arguments: [
        (source + "\n\n- [ ] Task added afterwards", nil),
        (source, baseURL),
    ])
    func `changing any equality input yields a different document`(
        markdown: String, baseURL: URL?
    ) {
        let reference = FlatMarkDocument(markdown: Self.source)
        let changed = FlatMarkDocument(markdown: markdown, baseURL: baseURL)

        #expect(reference != changed)
    }
}

#if os(macOS)
    import AppKit
    import SwiftUI

    // MARK: - FlatMarkDocumentRenderingTests

    /// What a retained document draws, compared against the same source given as a string.
    @MainActor
    struct FlatMarkDocumentRenderingTests {
        private static let source = """
        # Release notes

        Before **bold**, @jane, and [linked text](../other.md).

        - [ ] Review the pull request
        - [x] Ship the release

        > Quoted note about @jane.

        | Owner | State |
        | --- | --- |
        | Noemi | In progress |
        """

        private static let baseURL = URL(string: "https://example.com/docs/readme.md")

        private static let plainText = "Release notesBefore bold, @jane, and linked text."
            + "Review the pull requestShip the releaseQuoted note about @jane."
            + "OwnerStateNoemiIn progress"

        @Test
        func `a retained document renders the same content as the same source given as a string`() async throws {
            let document = FlatMarkDocument(markdown: Self.source, baseURL: Self.baseURL)
            let retained = await mountTestView(
                FlatMarkView(document: document, linkActivationAction: { _ in .handled })
            )
            defer { retained.close() }
            let stringBacked = await mountTestView(
                FlatMarkView(
                    markdown: Self.source,
                    baseURL: Self.baseURL,
                    linkActivationAction: { _ in .handled }
                )
            )
            defer { stringBacked.close() }

            _ = try await visibleText(showing: "Release notes", in: retained)
            _ = try await visibleText(showing: "Release notes", in: stringBacked)
            let retainedText = try retained.visibleAttributedText
            let stringBackedText = try stringBacked.visibleAttributedText

            #expect(retainedText.string == Self.plainText)
            #expect(stringBackedText.string == Self.plainText)
            #expect(renderSignature(of: retainedText) == renderSignature(of: stringBackedText))
        }

        @Test
        func `recipe initializers stay equivalent after edits`() async throws {
            let model = FlatMarkCustomFixtureModel()
            model.policyKind = .omit
            let retained = await mountTestView(ScrollView {
                FlatMarkCustomDocumentFixture(model: model, usesRetainedDocument: true)
                    .fixedSize(horizontal: false, vertical: true)
            })
            defer { retained.close() }
            let stringBacked = await mountTestView(ScrollView {
                FlatMarkCustomDocumentFixture(model: model, usesRetainedDocument: false)
                    .fixedSize(horizontal: false, vertical: true)
            })
            defer { stringBacked.close() }

            let retainedScroll = try #require(verticalScrollView(in: retained.view))
            let stringScroll = try #require(verticalScrollView(in: stringBacked.view))

            for edited in [false, true] {
                if edited {
                    model.markdown += "\n\n- [ ] Try olives next Sunday"
                }
                // Compare each realized viewport, including the ends, rather than treating a
                // native selection export as an eager, whole-document representation.
                var offset: CGFloat = 0
                var reachedBottom = false
                for page in 0 ..< 50 {
                    for _ in 0 ..< 5 {
                        for scroll in [retainedScroll, stringScroll] {
                            scroll.layoutSubtreeIfNeeded()
                            let height = try #require(scroll.documentView).bounds.height
                            let target = min(offset, max(0, height - scroll.contentView.bounds.height))
                            scroll.contentView.scroll(to: CGPoint(x: 0, y: target))
                            scroll.reflectScrolledClipView(scroll.contentView)
                        }
                        await settleMountedRendering()
                    }
                    let retainedText = try recipeViewportText(in: retainedScroll)
                    let stringText = try recipeViewportText(in: stringScroll)
                    #expect(renderSignature(of: retainedText) == renderSignature(of: stringText))
                    #expect(abs(retainedScroll.contentView.bounds.minY - stringScroll.contentView.bounds.minY) < 1)
                    if page == 0 {
                        #expect(retainedText.string.contains("Sunday focaccia"))
                    }
                    let height = try #require(retainedScroll.documentView).bounds.height
                    let viewport = retainedScroll.contentView.bounds.height
                    try #require(viewport > 0)
                    reachedBottom = abs(retainedScroll.contentView.bounds.minY - max(0, height - viewport)) < 1
                    if reachedBottom {
                        if edited {
                            #expect(retainedText.string.contains("Try olives next Sunday"))
                        }
                        break
                    }
                    offset += viewport
                }
                #expect(reachedBottom, "Initializer parity must cover the document end")
                #expect(model.document.markdown == model.markdown)
            }

            let snapshot = model.document
            model.refreshRequests += 1
            await settleMountedRendering()
            #expect(model.document == snapshot)
            #expect(try recipeViewportText(in: retainedScroll).string.contains("Try olives next Sunday"))
        }

        /// Lazy stacks retain offscreen native regions and can reorder their subviews. Read only
        /// regions intersecting the viewport, in layout order, without claiming pixel visibility.
        private func recipeViewportText(in scroll: NSScrollView) throws -> NSAttributedString {
            let clip = scroll.contentView
            let document = try #require(scroll.documentView)
            var regions: [(view: NSView, frame: CGRect)] = []
            func collect(_ view: NSView) {
                guard !view.isHiddenOrHasHiddenAncestor else { return }
                if view.responds(to: #selector(NSText.selectAll(_:))),
                   view.responds(to: #selector(NSServicesMenuRequestor.writeSelection(to:types:))) {
                    let frame = clip.convert(view.bounds, from: view)
                    if !view.visibleRect.isEmpty, frame.intersects(clip.bounds) {
                        regions.append((view, document.convert(view.bounds, from: view)))
                    }
                    return
                }
                for child in view.subviews { collect(child) }
            }
            collect(document)
            try #require(!regions.isEmpty, "Viewport must expose native text selection")
            regions.sort {
                let firstY = document.isFlipped ? $0.frame.minY : -$0.frame.maxY
                let secondY = document.isFlipped ? $1.frame.minY : -$1.frame.maxY
                return firstY == secondY ? $0.frame.minX < $1.frame.minX : firstY < secondY
            }
            let result = NSMutableAttributedString(string: "")
            for region in regions { result.append(try selectedText(in: region.view)) }
            return result
        }

        private func verticalScrollView(in view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView, scroll.hasVerticalScroller { return scroll }
            return view.subviews.lazy.compactMap { verticalScrollView(in: $0) }.first
        }

        /// Each exported run with the styling and destination this reader can observe, so parity
        /// covers wording and attributes rather than only a concatenated string.
        private func renderSignature(of text: NSAttributedString) -> [String] {
            var signature: [String] = []
            text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attributes, range, _ in
                let traits = (attributes[.font] as? NSFont).map { NSFontManager.shared.traits(of: $0) } ?? []
                let fragments = [
                    traits.contains(.boldFontMask) ? "bold" : "",
                    traits.contains(.italicFontMask) ? "italic" : "",
                    attributes[.strikethroughStyle] == nil ? "" : "strikethrough",
                    (attributes[.link] as? URL).map { "link=\($0.absoluteString)" } ?? "",
                ]
                let styles = fragments
                    .filter { !$0.isEmpty }
                    .joined(separator: ",")

                signature.append("\(styles)|\((text.string as NSString).substring(with: range))")
            }

            return signature
        }
    }
#endif
