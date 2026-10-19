@testable import FlatMark
import Foundation
import Markdown
import Testing

// MARK: - FlatMarkOmittedContentTests

/// The `.omit` policy, which removes unsupported content instead of showing it.
///
/// Most checks here read projection values: the blocks, spans, markers, and IDs one snapshot
/// projects, plus what `presents` and `plainText` decide about them. One check builds the native
/// inline element list a text view would display. No check in this suite mounts a view, so none of
/// them says what a screen showed, and the layout an omitted node used to occupy is stated by
/// `presents`, not measured.
struct FlatMarkOmittedContentTests {
    @MainActor
    @Test(arguments: [
        ("before <u>important</u> after", ["before ", "important", " after"]),
        ("a<u></u>b", ["a", "b"]),
        ("a <u></u> b", ["a ", " b"]),
        (
            "before <a href=\"javascript:go()\" onclick=\"go()\">tap</a> after",
            ["before ", "tap", " after"]
        ),
        (
            "before <img src=\"https://evil.example/x.png\" onerror=\"go()\"> after",
            ["before ", " after"]
        ),
        ("before <span>safe</span> after", ["before ", "safe", " after"]),
        ("before <u>unclosed", ["before ", "unclosed"]),
    ] as [(String, [String])])
    func `omits inline HTML tags and keeps every authored space`(
        markdown: String,
        fragments: [String]
    ) throws {
        let content = try #require(paragraphContent(in: markdown))

        // Every text run the reader gets is a supported one: the tag runs are simply absent.
        #expect(FlatMarkInlineView.inlineElements(for: content, policy: .omit).map(plainFragment) == fragments)
    }

    @Test(arguments: [
        ("![before <u>x</u> after](image.png)", "before x after"),
        ("![a<u></u>b](image.png)", "ab"),
        ("![a <u></u> b](image.png)", "a  b"),
        ("![<u></u>](image.png)", "Image"),
        ("![`<u>`](image.png)", "<u>"),
        ("![outer ![<u>inner</u>](nested.png)](image.png)", "outer inner"),
    ] as [(String, String)])
    func `image descriptions apply omission without removing the image`(markdown: String, expected: String) throws {
        let document = FlatMarkRenderProjector.project(
            markdown: markdown,
            baseURL: URL(string: "https://example.com/")
        )
        let content = try #require(paragraphContent(of: document))

        #expect(omit.plainText(for: content) == expected)
        #expect(omit.presents(document.blocks[0]))
        guard case let .image(image)? = content.components.first else {
            Issue.record("Expected a supported image")
            return
        }

        #expect(image.url == URL(string: "https://example.com/image.png"))
    }

    @Test
    func `image description omits unknown inline nodes without trimming supported spaces`() throws {
        let markdown = "![see ``Foo`` after](image.png)"
        let document = FlatMarkRenderProjector.project(
            Document(parsing: markdown, options: [.parseSymbolLinks]),
            source: markdown
        )
        let content = try #require(paragraphContent(of: document))
        #expect(omit.plainText(for: content) == "see  after")
        #expect(FlatMarkUnsupportedContentPolicy.literal.plainText(for: content) == "see ``Foo`` after")
    }

    @Test
    func `task image description omits tags and preserves its link and editing address`() throws {
        let markdown = "- [ ] [![before <u>x</u> after](image.png)](https://example.com/details)"
        let entries = try #require(listEntries(in: markdown))
        let row = try #require(entries.first.flatMap(row(of:)))
        #expect(omit.plainText(for: row.content) == "before x after")
        #expect(FlatMarkUnsupportedContentPolicy.literal.plainText(for: row.content) == "before <u>x</u> after")
        #expect(row.content.standaloneLinkedImageDestination == URL(string: "https://example.com/details"))
        guard case let .task(_, sourceRange) = row.marker else {
            Issue.record("Expected a task marker")
            return
        }

        #expect(try FlatMarkTaskMarkerToggle.toggledMarkdown(
            in: markdown,
            sourceRange: #require(sourceRange)
        ) == markdown.replacingOccurrences(of: "[ ]", with: "[x]"))
    }

    @Test
    func `omits a standalone HTML block but keeps the supported paragraphs around it`() {
        let blocks = FlatMarkRenderProjector.project(markdown: "before\n\n<div>hide</div>\n\nafter").blocks

        #expect(blocks.count == 3)
        #expect(blocks.map { omit.presents($0) } == [true, false, true])
        // Survivors keep the tree path they had in the unfiltered document.
        #expect(blocks.filter { omit.presents($0) }.map(\.id) == [
            FlatMarkRenderNodeID(path: [0]),
            FlatMarkRenderNodeID(path: [2]),
        ])
    }

    @Test(arguments: [
        "before\n\n<u></u>\n\nafter",
        "before\n\n# <u></u>\n\nafter",
        "before\n\n> <u></u>\n\nafter",
        "before\n\n> > <u></u>\n\nafter",
    ] as [String])
    func `removes a block that only carried omitted content`(markdown: String) {
        let blocks = FlatMarkRenderProjector.project(markdown: markdown).blocks
        let presented = blocks.filter { omit.presents($0) }

        #expect(blocks.count == 3)
        #expect(presented.count == 2)
        #expect(presented.map(\.id) == [blocks[0].id, blocks[2].id])
    }

    @Test(arguments: [
        "> - <u></u>\n",
        "> ***\n",
        "> `visible`\n",
    ] as [String])
    func `keeps a quote that still carries supported structure`(markdown: String) throws {
        let quote = try #require(FlatMarkRenderProjector.project(markdown: markdown).blocks.first)

        #expect(quote.kind.isBlockQuote)
        #expect(omit.presents(quote))
    }

    @Test
    func `leaves a quote that was already empty alone`() {
        let document = FlatMarkRenderProjector.project(Document(BlockQuote([])), source: "")

        #expect(omit.presents(document.blocks[0]))
    }

    @Test(arguments: ["space", "soft break", "hard break"])
    func `supported whitespace and breaks prevent omission from emptying a shell`(kind: String) throws {
        let supported: any InlineMarkup =
            switch kind {
            case "space": Text(" ")
            case "soft break": SoftBreak()
            default: LineBreak()
            }
        let children: [any InlineMarkup] = [InlineHTML("<u>"), supported, InlineHTML("</u>")]
        let document = FlatMarkRenderProjector.project(
            Document([Paragraph(children), Heading(level: 1, children)] as [any BlockMarkup]),
            source: ""
        )

        #expect(document.blocks.map { omit.presents($0) } == [true, true])
        let content = try #require(paragraphContent(of: document))
        #expect(omit.plainText(for: content) == (kind == "space" ? " " : "\n"))
    }

    @Test
    func `pre-existing empty paragraphs and headings survive omission`() {
        let document = FlatMarkRenderProjector.project(
            Document([Paragraph([]), Heading(level: 1, [])] as [any BlockMarkup]), source: ""
        )

        #expect(document.blocks.map { omit.presents($0) } == [true, true])
    }

    @Test
    func `empty-extraction unknown nodes disappear without renumbering survivors`() throws {
        let document = FlatMarkRenderProjector.project(Document([
            Paragraph([Text("before")]),
            CustomBlock([]),
            Paragraph([SymbolLink(destination: "Symbol")]),
            BlockQuote([CustomBlock([])]),
            Paragraph([Text("after")]),
        ] as [any BlockMarkup]), source: "")

        #expect(document.blocks.map { omit.presents($0) } == [true, false, false, false, true])
        #expect(document.blocks.filter { omit.presents($0) }.map(\.id) == [
            FlatMarkRenderNodeID(path: [0]), FlatMarkRenderNodeID(path: [4]),
        ])
        guard case let .unsupported(unknown) = document.blocks[1].kind else {
            Issue.record("Expected an unsupported block")
            return
        }

        #expect(unknown.literalText.characters.isEmpty)
        let content = try #require(paragraphContent(of: FlatMarkRenderDocument(blocks: [document.blocks[2]])))
        #expect(content.plainText.isEmpty)
        #expect(!content.components.isEmpty)
    }

    @Test
    func `keeps ordered numbering when omission empties the text beside it`() throws {
        let document = FlatMarkRenderProjector.project(markdown: "7. <u></u>\n8. keep")
        let entries = try #require(listEntries(in: document))
        let rows = entries.compactMap(row(of:))

        #expect(entries.count == 2)
        #expect(rows.map { markerText($0.marker) } == ["7.", "8."])
        #expect(omit.plainText(for: rows[0].content) == "")
        #expect(omit.plainText(for: rows[1].content) == "keep")
        #expect(try omit.presents(#require(document.blocks.first)))
    }

    @Test
    func `keeps a task control whose only content is omitted`() throws {
        let markdown = "- [ ] <u></u>\n"
        let entries = try #require(listEntries(in: markdown))
        let row = try #require(entries.first.flatMap(row(of:)))

        guard case let .task(isChecked, sourceRange) = row.marker else {
            Issue.record("Expected a task marker")
            return
        }

        // The control and the byte it edits are the item's own, not the omitted tag's.
        #expect(!isChecked)
        #expect(try #require(sourceRange).text(in: markdown) != nil)
        #expect(try FlatMarkTaskMarkerToggle.toggledMarkdown(
            in: markdown,
            sourceRange: #require(sourceRange)
        ) == "- [x] <u></u>\n")
        #expect(omit.plainText(for: row.content) == "")
        #expect(FlatMarkUnsupportedContentPolicy.literal.plainText(for: row.content) == "<u></u>")
    }

    @Test
    func `keeps table rows, columns, and cells whose text is omitted`() throws {
        let document = FlatMarkRenderProjector.project(markdown: "| A | B |\n| --- | --- |\n| <u></u> | keep |")
        let table = try #require(table(in: document))
        let body = try #require(table.rows.first)

        #expect(table.header.count == 2)
        #expect(body.cells.count == 2)
        #expect(omit.plainText(for: body.cells[0].content) == "")
        #expect(omit.plainText(for: body.cells[1].content) == "keep")
        #expect(try omit.presents(#require(document.blocks.first)))
    }

    @Test
    func `omits an unsupported block instead of its readable descendants`() {
        // A block directive is one unsupported node that happens to carry readable paragraphs
        // inside. Omission removes the node whole; nothing from inside it comes back.
        let markdown = "@Foo(bar) {\n**hidden**\n}\n"
        let document = FlatMarkRenderProjector.project(
            Document(parsing: markdown, options: [.parseBlockDirectives]),
            source: markdown
        )

        #expect(document.blocks.count == 1)
        #expect(!omit.presents(document.blocks[0]))
    }

    @MainActor
    @Test
    func `omits an inline unknown node and the block that only carried it`() throws {
        let children: [any InlineMarkup] = [
            Text("before "),
            InlineAttributes(attributes: "{}", Text("inner")),
            Text(" after"),
        ]
        let span = try #require(paragraphContent(of: FlatMarkRenderProjector.project(
            Document(Paragraph(children)),
            source: ""
        )))
        let shellChildren: [any InlineMarkup] = [SymbolLink(destination: "Symbol")]
        let shell = try #require(FlatMarkRenderProjector.project(
            Document(Paragraph(shellChildren)),
            source: ""
        )
        .blocks
        .first)

        #expect(FlatMarkInlineView.inlineElements(for: span, policy: .omit).map(plainFragment) == [
            "before ",
            " after",
        ])
        #expect(!omit.presents(shell))
    }

    @Test(arguments: [
        ("before\n\n- item\n\n  <div>hide</div>\n", "before\n\n- item\n"),
        (
            "- item\n\n  > > <u></u>\n\n  > keep\n  >\n  > - <u></u>\n  > - sibling\n\n  <div>hide</div>\n\n  after",
            "- item\n\n  > keep\n  >\n  > - \n  > - sibling\n\n  after"
        ),
        (
            "> <u></u>\n>\n> | A | B |\n> | --- | --- |\n> | <u></u> | keep |\n>\n> ***",
            "> | A | B |\n> | --- | --- |\n> | | keep |\n>\n> ***"
        ),
        (
            "> <u></u>\n>\n> ```\n> <div>code</div>\n> ```\n>\n> ![Image](image.png)",
            "> ```\n> <div>code</div>\n> ```\n>\n> ![Image](image.png)"
        ),
    ] as [(String, String)])
    func `omits content so the reader gets the document typed without it`(
        markdown: String,
        reference: String
    ) throws {
        let omitted = FlatMarkRenderProjector.project(
            markdown: markdown,
            baseURL: URL(string: "https://example.com/")
        )
        let typed = FlatMarkRenderProjector.project(
            markdown: reference,
            baseURL: URL(string: "https://example.com/")
        )

        // What omission leaves is the same document, typed by hand with the content left out. Both
        // sides get the same policy, so a survivor's own wording decides the comparison; whether a
        // survivor sits in a tighter slot is layout, which no tree comparison measures. These are
        // the container cases, where nothing else states the result: one continuation block and the
        // three containers whose remaining supported content has to survive the walk. The inline,
        // image, marker, cell, and shell cases are each stated by the direct value checks above.
        #expect(visibleDocument(omitted, policy: .omit) == visibleDocument(typed, policy: .omit))
    }
}

// MARK: - Fixture helpers

private var omit: FlatMarkUnsupportedContentPolicy {
    .omit
}

private extension FlatMarkRenderBlock.Kind {
    var isBlockQuote: Bool {
        if case .blockQuote = self {
            return true
        }

        return false
    }
}

private func paragraphContent(of document: FlatMarkRenderDocument) -> FlatMarkRenderInlineContent? {
    guard case let .paragraph(content)? = document.blocks.first?.kind else {
        return nil
    }

    return content
}

private func paragraphContent(in markdown: String) -> FlatMarkRenderInlineContent? {
    paragraphContent(of: FlatMarkRenderProjector.project(markdown: markdown))
}

private func table(in document: FlatMarkRenderDocument) -> FlatMarkRenderTable? {
    guard case let .table(table)? = document.blocks.first?.kind else {
        return nil
    }

    return table
}

private func listEntries(in document: FlatMarkRenderDocument) -> [FlatMarkListRenderEntry]? {
    listEntries(in: document.blocks.first)
}

private func listEntries(in block: FlatMarkRenderBlock?) -> [FlatMarkListRenderEntry]? {
    guard case let .list(entries)? = block?.kind else {
        return nil
    }

    return entries
}

private func listEntries(in markdown: String) -> [FlatMarkListRenderEntry]? {
    listEntries(in: FlatMarkRenderProjector.project(markdown: markdown))
}

private func row(of entry: FlatMarkListRenderEntry) -> FlatMarkListRenderRow? {
    guard case let .row(row) = entry else {
        return nil
    }

    return row
}

private func markerText(_ marker: FlatMarkListMarker) -> String {
    switch marker {
    case .unordered:
        "•"
    case let .ordered(index):
        "\(index)."
    case let .task(isChecked, _):
        isChecked ? "checked" : "unchecked"
    }
}

private func plainFragment(_ element: FlatMarkInlineView.InlineElement) -> String {
    switch element.content {
    case let .text(text):
        return String(text.characters)
    case .lineBreak:
        return "\n"
    case let .image(_, image):
        return FlatMarkUnsupportedContentPolicy.omit.imageLabel(for: image)
    case .custom:
        Issue.record("Built-in policy must not produce a custom element")
        return ""
    }
}
