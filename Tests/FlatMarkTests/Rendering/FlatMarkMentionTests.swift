#if os(macOS)
    import AppKit
    import FlatMark
    import FlatMarkFixtures
    import SwiftUI
    import Testing

    @MainActor
    struct FlatMarkMentionTests {
        @Test
        func `mounted text reader observes selectable SwiftUI text independently of FlatMark`() async throws {
            let mounted = await mountTestView(Text("hello-probe").textSelection(.enabled))
            defer { mounted.close() }
            #expect(try mounted.visibleAttributedText.string == "hello-probe")
        }

        @Test
        func `unavailable selection throws instead of pretending wording is slow to render`() async {
            let mounted = await mountTestView(EmptyView())
            defer { mounted.close() }
            await #expect(throws: MountedTextObservationError.selectionUnavailable) {
                try await visibleText(showing: "missing", in: mounted)
            }
        }

        @Test
        func `recipe mention detection updates without replacing its source`() async throws {
            let model = FlatMarkCustomFixtureModel()
            let mounted = await mountTestView(FlatMarkCustomDocumentFixture(model: model))
            defer { mounted.close() }
            _ = try await visibleText(showing: "@jane.doe", in: mounted)
            let enabled = try mounted.visibleAttributedText
            #expect(boldText(in: enabled).contains("@jane.doe"))
            #expect(!attributeText(.link, in: enabled).contains("@jane.doe"))

            model.detectMentions = false
            await settleMountedRendering()
            let disabled = try mounted.visibleAttributedText
            #expect(disabled.string.contains("@jane.doe"))
            #expect(!boldText(in: disabled).contains("@jane.doe"))
            #expect(model.markdown == FlatMarkRecipeSample.markdown)
        }

        @Test
        func `opted in mentions render the entire token bold without a link`() async throws {
            let mounted = await mountTestView(FlatMarkView(markdown: "Before @jane after", detectMentions: true))
            defer { mounted.close() }
            _ = try await visibleText(showing: "Before @jane after", in: mounted)
            let text = try mounted.visibleAttributedText
            #expect(text.string == "Before @jane after")
            #expect(boldText(in: text) == "@jane")
            #expect(attributeText(.link, in: text).isEmpty)
        }

        @Test(arguments: [
            ("@ja*ne*", "@jane", "@ja", "ne"),
            ("*@ja*ne", "@jane", "@ja", "@ja"),
            ("*@jane*", "@jane", "@jane", "@jane"),
            ("e*mail*@example.com", "email@example.com", "@example.com", "mail"),
            ("*email*@example.com", "email@example.com", "@example.com", "email"),
            ("a**b**@jane", "ab@jane", "b@jane", ""),
        ])
        func `formatting is a hard boundary for independent text node detection`(
            markdown: String, plain: String, bold: String, italic: String
        ) async throws {
            let mounted = await mountTestView(FlatMarkView(markdown: markdown, detectMentions: true))
            defer { mounted.close() }
            _ = try await visibleText(showing: plain, in: mounted)
            let text = try mounted.visibleAttributedText
            #expect(text.string == plain)
            #expect(boldText(in: text) == bold)
            #expect(fontText(with: .italicFontMask, in: text) == italic)
        }

        @Test(arguments: [
            ("`@jane`", "@jane", "", ""),
            ("```\n@jane\n```", "@jane\n", "", ""),
            ("[@ja*ne*](https://example.com)", "@jane", "", "@jane"),
            ("[@jane](relative)", "@jane", "", ""),
            ("**[@jane](https://example.com)**", "@jane", "@jane", "@jane"),
            ("@ja`ne`", "@jane", "@ja", ""),
            ("`a`@jane", "a@jane", "@jane", ""),
            ("@ja[ne](relative)", "@jane", "@ja", ""),
            ("[a](relative)@jane", "a@jane", "@jane", ""),
            ("@ja[](https://example.com)ne", "@jane", "@ja", ""),
            ("a[](relative)@jane", "a@jane", "@jane", ""),
        ])
        func `code and link content are excluded and cannot be crossed`(
            markdown: String, plain: String, bold: String, linked: String
        ) async throws {
            let mounted = await mountTestView(FlatMarkView(markdown: markdown, detectMentions: true))
            defer { mounted.close() }
            _ = try await visibleText(showing: plain, in: mounted)
            let text = try mounted.visibleAttributedText
            #expect(text.string == plain)
            #expect(boldText(in: text) == bold)
            #expect(attributeText(.link, in: text) == linked)
        }

        @Test(arguments: [
            ("@jane @jane.doe @jane-doe @jane_2", "@jane@jane.doe@jane-doe@jane_2"),
            ("see @jane. (@other), @third!", "@jane@other@third"),
            ("email@example.com a@jane 2@jane _@jane", ""),
            ("@jane..doe @jane–doe @jane.-doe @jane-", "@jane@jane@jane@jane"),
            ("@ @é @用户 @janeé é@jane", "@jane@jane"),
            ("@0 @_ @UNKNOWN_99 @a.b-c_d", "@0@_@UNKNOWN_99@a.b-c_d"),
            ("@jane@other /@third", "@jane@third"),
        ])
        func `mention grammar uses ASCII handles and excludes punctuation and email boundaries`(
            source: String, bold: String
        ) async throws {
            let mounted = await mountTestView(FlatMarkView(markdown: source, detectMentions: true))
            defer { mounted.close() }
            _ = try await visibleText(showing: source, in: mounted)
            let text = try mounted.visibleAttributedText
            #expect(text.string == source)
            #expect(boldText(in: text) == bold)
            #expect(attributeText(.link, in: text).isEmpty)
        }

        @Test(arguments: [false, true])
        func `omitted and explicitly disabled detection preserve existing rendering`(omitFlag: Bool) async throws {
            let source = "@jane *italic* **bold** [normal](https://example.com)"
            let view = omitFlag ? FlatMarkView(markdown: source) : FlatMarkView(markdown: source, detectMentions: false)
            let mounted = await mountTestView(view)
            defer { mounted.close() }
            _ = try await visibleText(showing: "@jane italic bold normal", in: mounted)
            let text = try mounted.visibleAttributedText
            #expect(text.string == "@jane italic bold normal")
            #expect(boldText(in: text) == "bold")
            #expect(fontText(with: .italicFontMask, in: text) == "italic")
            #expect(attributeText(.link, in: text) == "normal")
        }

        @Test(arguments: [
            ("# Title @jane", "Title @jane", "Title @jane"),
            ("- before *@jane* after", "•before @jane after", "@jane"),
            ("1. before @jane after", "1.before @jane after", "@jane"),
            ("| Header |\n| --- |\n| before *@jane* after |", "Headerbefore @jane after", "Header@jane"),
            ("> before @jane after", "before @jane after", "@jane"),
        ])
        func `mentions render in headings list rows table cells and quotes`(
            markdown: String, plain: String, bold: String
        ) async throws {
            let mounted = await mountTestView(FlatMarkView(markdown: markdown, detectMentions: true))
            defer { mounted.close() }
            _ = try await visibleText(showing: "@jane", in: mounted)
            let text = try mounted.visibleAttributedText
            #expect(text.string == plain)
            #expect(boldText(in: text) == bold)
            #expect(attributeText(.link, in: text).isEmpty)
        }

        @Test
        func `mention styling preserves whitespace surrounding text and other attributes`() async throws {
            let source = "Before  ~~*@jane*~~ after\nnext  [normal](https://example.com) @other."
            let mounted = await mountTestView(
                FlatMarkView(markdown: source, detectMentions: true),
                size: .init(width: 150, height: 700)
            )
            defer { mounted.close() }
            _ = try await visibleText(showing: "@other.", in: mounted)
            let text = try mounted.visibleAttributedText
            #expect(text.string == "Before  @jane after\nnext  normal @other.")
            #expect(boldText(in: text) == "@jane@other")
            #expect(fontText(with: .italicFontMask, in: text) == "@jane")
            #expect(attributeText(.strikethroughStyle, in: text) == "@jane")
            #expect(attributeText(.link, in: text) == "normal")
            #expect(mounted.showsContent)
        }

        private func boldText(in text: NSAttributedString) -> String {
            fontText(with: .boldFontMask, in: text)
        }

        private func fontText(with trait: NSFontTraitMask, in text: NSAttributedString) -> String {
            var result = ""
            text.enumerateAttribute(.font, in: NSRange(location: 0, length: text.length)) { value, range, _ in
                if let font = value as? NSFont, NSFontManager.shared.traits(of: font).contains(trait) {
                    result += (text.string as NSString).substring(with: range)
                }
            }
            return result
        }

        private func attributeText(_ key: NSAttributedString.Key, in text: NSAttributedString) -> String {
            var result = ""
            text.enumerateAttribute(key, in: NSRange(location: 0, length: text.length)) { value, range, _ in
                if value != nil {
                    result += (text.string as NSString).substring(with: range)
                }
            }
            return result
        }
    }
#endif
