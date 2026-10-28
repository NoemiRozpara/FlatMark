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
        #expect(!document.detectMentions)
        #expect(document == FlatMarkDocument(markdown: Self.source))
    }

    @Test(arguments: [
        (source + "\n\n- [ ] Task added afterwards", nil, false),
        (source, baseURL, false),
        (source, nil, true),
    ])
    func `changing any equality input yields a different document`(
        markdown: String, baseURL: URL?, detectMentions: Bool
    ) {
        let reference = FlatMarkDocument(markdown: Self.source)
        let changed = FlatMarkDocument(markdown: markdown, baseURL: baseURL, detectMentions: detectMentions)

        #expect(reference != changed)
    }
}

#if os(macOS)
    import AppKit

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
            let document = FlatMarkDocument(markdown: Self.source, baseURL: Self.baseURL, detectMentions: true)
            let retained = await mountTestView(
                FlatMarkView(document: document, linkActivationAction: { _ in .handled })
            )
            defer { retained.close() }
            let stringBacked = await mountTestView(
                FlatMarkView(
                    markdown: Self.source,
                    baseURL: Self.baseURL,
                    linkActivationAction: { _ in .handled },
                    detectMentions: true
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
        func `recipe initializers stay equivalent after edits and mention changes`() async throws {
            let model = FlatMarkCustomFixtureModel()
            model.policyKind = .omit
            let retained = await mountTestView(FlatMarkCustomDocumentFixture(model: model, usesRetainedDocument: true))
            defer { retained.close() }
            let stringBacked = await mountTestView(FlatMarkCustomDocumentFixture(model: model, usesRetainedDocument: false))
            defer { stringBacked.close() }

            for edited in [false, true] {
                if edited {
                    model.markdown += "\n\n- [ ] Try olives next Sunday"
                    model.detectMentions = false
                }
                await settleMountedRendering()
                let retainedText = try retained.visibleAttributedText
                let stringText = try stringBacked.visibleAttributedText
                #expect(retainedText.string.contains("Sunday focaccia"))
                #expect(renderSignature(of: retainedText) == renderSignature(of: stringText))
                #expect(model.document.markdown == model.markdown)
                #expect(model.document.detectMentions == model.detectMentions)
            }

            let snapshot = model.document
            model.refreshRequests += 1
            await settleMountedRendering()
            #expect(model.document == snapshot)
            #expect(try retained.visibleAttributedText.string.contains("Try olives next Sunday"))
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
