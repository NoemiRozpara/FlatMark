@testable import FlatMark
import Foundation
import Markdown
import Testing

// MARK: - FlatMarkUnsupportedContentTests

/// The default literal behavior for content the parser reports as unsupported.
///
/// Most checks here read projection values: the blocks and spans the projector produces for one
/// snapshot. Two exceptions state what they observe: one builds the native inline element list a
/// text view would display, and one constructs every `FlatMarkView` initializer to keep the API
/// source-compatible. No check in this suite mounts a view, so none of them says what a screen
/// showed.
struct FlatMarkUnsupportedContentTests {
    @Test
    func `keeps each inline HTML tag distinct and styled inside strong emphasis`() throws {
        let content = try #require(paragraphContent(in: "**before <u>x</u> after**"))

        #expect(content.plainText == "before <u>x</u> after")
        #expect(content.components.count == 5)
        for tag in ["<u>", "</u>"] {
            let tagRun = try #require(run(containing: tag, in: content))
            #expect(tagRun.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
        }
    }

    @Test
    func `applies the enclosing Markdown link to literal tags without reading HTML attributes`() throws {
        let content = try #require(paragraphContent(in: """
        [before <u>x</u> after](https://example.com/md) before <a href="https://evil.example">x</a> after
        """))
        let linked = try #require(run(containing: "<u>", in: content))
        let inert = try #require(run(containing: "<a href", in: content))

        #expect(content.plainText ==
            "before <u>x</u> after before <a href=\"https://evil.example\">x</a> after")
        #expect(linked.link == URL(string: "https://example.com/md"))
        #expect(inert.link == nil)
    }

    /// The wording the corpus's attribute-bearing and unclosed inline HTML keeps under the literal
    /// policy: what the parser reported, in its authored order, with nothing re-serialized from it.
    @Test(arguments: [
        (
            "before <a href=\"javascript:go()\" onclick=\"go()\">tap</a> after",
            "before <a href=\"javascript:go()\" onclick=\"go()\">tap</a> after"
        ),
        (
            "before <img src=\"https://evil.example/x.png\" onerror=\"go()\"> after",
            "before <img src=\"https://evil.example/x.png\" onerror=\"go()\"> after"
        ),
        ("before <span>safe</span> after", "before <span>safe</span> after"),
        ("before <u>unclosed", "before <u>unclosed"),
    ] as [(String, String)])
    func `prints attribute-bearing and unclosed inline HTML from its own source`(
        markdown: String,
        source: String
    ) throws {
        let content = try #require(paragraphContent(in: markdown))

        #expect(content.plainText == source)
    }

    /// Supported presentation and navigation that legitimately enclose the corpus's attribute-bearing
    /// nodes stay on the runs that carry them, while the HTML attributes beside them stay unread.
    @Test
    func `keeps Markdown emphasis and links that enclose HTML attributes and reads neither of them`() throws {
        let document = FlatMarkRenderProjector.project(markdown: """
        **before <img src="https://evil.example/x.png" onclick="go()"> after**

        [linked <a href="javascript:go()" onclick="go()">tap</a> now](https://example.com/md)
        """)
        let emphasized = try #require(
            paragraphContent(of: FlatMarkRenderDocument(blocks: [document.blocks[0]]))
        )
        let linked = try #require(
            paragraphContent(of: FlatMarkRenderDocument(blocks: [document.blocks[1]]))
        )
        let destination = try #require(URL(string: "https://example.com/md"))

        // Inside the emphasis, the literal tag and the supported run beside it both keep it, and no
        // HTML src becomes an image or a link.
        for wording in ["<img src", "before", "after"] {
            #expect(
                run(containing: wording, in: emphasized)?.inlinePresentationIntent?
                    .contains(.stronglyEmphasized) == true
            )
        }
        #expect(images(in: emphasized).isEmpty)
        #expect(runs(in: emphasized).compactMap(\.link).isEmpty)

        // The Markdown link encloses the literal tag exactly as it encloses its supported text, and
        // never takes the destination one of its own href attributes spells.
        for wording in ["linked ", "tap", "<a href"] {
            #expect(run(containing: wording, in: linked)?.link == destination)
        }
        #expect(Set(runs(in: linked).compactMap(\.link)) == [destination])
    }

    /// A whole HTML block is one node for every policy: inert exact text, no layout slot left behind
    /// by omission, and exactly one host position where the block itself sat.
    @Test(arguments: [
        ("<script>go()</script>", "<script>go()</script>\n"),
        ("<iframe src=\"https://evil.example/e\"></iframe>", "<iframe src=\"https://evil.example/e\"></iframe>\n"),
    ] as [(String, String)])
    func `treats one whole HTML block as one node for every policy`(
        markdown: String,
        rawHTML: String
    ) throws {
        let document = FlatMarkRenderProjector.project(markdown: markdown)
        let block = try #require(document.blocks.first)

        #expect(block.kind == .unsupported(literal(rawHTML)))
        #expect(!FlatMarkUnsupportedContentPolicy.omit.presents(block))
        #expect(customHosts(in: document) == [host(rawHTML, path: [0])])
    }

    @Test
    func `renders a standalone HTML block as its exact literal source`() {
        let document = FlatMarkRenderProjector.project(markdown: "<details>Visible literal</details>")

        #expect(document.blocks.first?.kind ==
            .unsupported(literal("<details>Visible literal</details>\n")))
    }

    @Test(arguments: [
        ("see ``Foo`` here", 1, "see ``Foo`` here"),
        ("before\n``Foo``", 1, "before\n``Foo``"),
        ("café 🧪 ``你好`` after", 1, "café 🧪 ``你好`` after"),
    ])
    func `extracts an unknown inline node from its exact source slice`(
        markdown: String, unsupportedCount: Int, expectedText: String
    ) throws {
        // ``.parseSymbolLinks`` is the narrow way this build turns a span into a node kind the
        // renderer has no view for; production parsing never requests it.
        let document = FlatMarkRenderProjector.project(
            Document(parsing: markdown, options: [.parseSymbolLinks]),
            source: markdown
        )
        let content = try #require(paragraphContent(of: document))

        #expect(content.components.flatMap(unsupportedValues).count == unsupportedCount)
        #expect(content.plainText == expectedText)
    }

    @Test(arguments: ["\n", "\r\n", "\r"])
    func `extracts an unknown multiline block with original Unicode and line endings`(newline: String) {
        let markdown = "café 🧪" + newline + newline + "@Foo(bar) {" + newline + "你好" + newline + "}"
        let document = FlatMarkRenderProjector.project(
            Document(parsing: markdown, options: [.parseBlockDirectives]),
            source: markdown
        )

        let expected = "@Foo(bar) {" + newline + "你好" + newline + "}"
        #expect(document.blocks.last?.kind == .unsupported(literal(expected)))
    }

    @Test
    func `falls back to readable descendants when a parsed range cannot address the source`() throws {
        // Deliberately unavailable source in this synthetic fixture makes the parsed range
        // unusable. Production projection always supplies the original snapshot.
        let parsed = Document(parsing: "@Foo {\n**café** `你好` <u>x</u>\n}", options: [.parseBlockDirectives])
        let directive = try #require(parsed.child(at: 0) as? BlockDirective)
        #expect(directive.range != nil)
        let document = FlatMarkRenderProjector.project(parsed, source: "")

        #expect(document.blocks.first?.kind == .unsupported(literal("café 你好 <u>x</u>")))
    }

    @Test
    func `empty unsupported blocks and raw HTML keep empty literal values`() throws {
        let document = FlatMarkRenderProjector.project(
            Document([CustomBlock([]), HTMLBlock("")] as [any BlockMarkup]), source: ""
        )
        #expect(document.blocks.map(\.kind) == [.unsupported(literal("")), .unsupported(literal(""))])
        let content = try #require(paragraphContent(of: FlatMarkRenderProjector.project(
            Document(Paragraph(InlineHTML(""))), source: ""
        )))
        #expect(content.components == [.unsupported(literal(""))])
    }

    @Test
    func `reads an unknown inline node without a source range from its readable descendants`() throws {
        // A rangeless fixture addresses no snapshot, so the snapshot it is projected against is
        // never read.
        let children: [any InlineMarkup] = [
            Text("Before "),
            InlineAttributes(attributes: "{}", Text("inner")),
            Text(" after"),
        ]
        let content = try #require(
            paragraphContent(of: FlatMarkRenderProjector.project(Document(Paragraph(children)), source: ""))
        )

        #expect(content.components.count == 3)
        #expect(content.components.flatMap(unsupportedValues).count == 1)
        #expect(content.plainText == "Before inner after")
    }

    @Test
    func `uses empty literal text when an unknown inline node has neither range nor children`() throws {
        let children: [any InlineMarkup] = [
            Text("Before "),
            SymbolLink(destination: "Symbol"),
            Text(" after"),
        ]
        let content = try #require(
            paragraphContent(of: FlatMarkRenderProjector.project(Document(Paragraph(children)), source: ""))
        )
        let middle = try #require(content.components[1].unsupportedContent)

        #expect(middle.literalText.characters.isEmpty)
        #expect(content.plainText == "Before  after")
    }

    @Test
    func `reads an unknown block without a source range from its readable descendants`() {
        let document = FlatMarkRenderProjector.project(
            Document(CustomBlock([Paragraph([Text("Visible descendant")])])),
            source: ""
        )

        #expect(document.blocks.first?.kind == .unsupported(literal("Visible descendant")))
    }

    @Test
    func `reads a code-block descendant of a rangeless unknown block from its exact code text`() {
        // A code block keeps its content in ``code``, not in readable children, so an extraction
        // that only follows children hands back nothing. Ordinary parsing never nests a code block
        // inside an unknown block, so this fixture addresses that leaf directly.
        let code = "café 🧪\n你好\nlet answer = 42\n"
        let document = FlatMarkRenderProjector.project(
            Document(CustomBlock([CodeBlock(language: "swift", code)])),
            source: ""
        )

        #expect(document.blocks.first?.kind == .unsupported(literal(code)))
    }

    @Test
    func `reads an HTML-block descendant of a rangeless unknown block from its exact raw HTML`() {
        let html = "<details>\n<summary>café 🧪</summary>\n</details>\n"
        let document = FlatMarkRenderProjector.project(
            Document(CustomBlock([HTMLBlock(html)])),
            source: ""
        )

        #expect(document.blocks.first?.kind == .unsupported(literal(html)))
    }

    @Test
    func `keeps mixed readable descendants of a rangeless unknown block in source order`() {
        // Text, a code block, an HTML block, and inline code, each in the slot the fixture put it
        // in: nothing about one leaf's shape may silently drop another's.
        let children: [any BlockMarkup] = [
            Paragraph([Text("café ")]),
            CodeBlock("你好\n"),
            HTMLBlock("<u>🧪</u>\n"),
            Paragraph([InlineCode("tail")]),
        ]
        let document = FlatMarkRenderProjector.project(
            Document(CustomBlock(children)),
            source: ""
        )

        #expect(document.blocks.first?.kind == .unsupported(literal("café 你好\n<u>🧪</u>\ntail")))
    }

    @Test
    func `hands a custom host the same corrected block extraction as the literal policy`() {
        let code = "café 🧪\n你好\n"
        let document = FlatMarkRenderProjector.project(
            Document(CustomBlock([CodeBlock(language: "swift", code)])),
            source: ""
        )

        // One extraction serves every policy: what a host view is handed is the text the literal
        // policy prints, which is the literal text this projection already carries.
        #expect(document.blocks.map(\.kind) == [.unsupported(literal(code))])
        #expect(customHosts(in: document) == [host(code, path: [0])])
    }

    @Test(arguments: [
        // Half-open coordinates: one-based lines, UTF-8 byte columns, lower inclusive and upper
        // exclusive. A nil result is a range that addresses nothing usable.
        ("before <u>x</u> after", 1, 1, 1, 8, "before "),
        ("before\nafter", 1, 1, 2, 6, "before\nafter"),
        ("a\r\nb", 1, 1, 2, 2, "a\r\nb"),
        ("a\rb", 1, 1, 2, 2, "a\rb"),
        ("héllo", 1, 1, 1, 4, "hé"),
        ("héllo\no", 2, 1, 2, 2, "o"),
        ("abc", 1, 1, 1, 4, "abc"),
        ("", 1, 1, 1, 1, ""),
        ("héllo", 1, 1, 1, 3, nil),
        ("héllo", 1, 3, 1, 5, nil),
        ("abc", 1, 1, 1, 5, nil),
        ("abc", 5, 1, 5, 2, nil),
        ("abc", 1, 0, 1, 2, nil),
        ("abc", 1, 3, 1, 2, nil),
    ] as [(String, Int, Int, Int, Int, String?)])
    func `slices only the exact region one valid range addresses`(
        markdown: String,
        lowerLine: Int,
        lowerColumn: Int,
        upperLine: Int,
        upperColumn: Int,
        expected: String?
    ) {
        let range = FlatMarkSourceRange(
            lowerBound: .init(line: lowerLine, column: lowerColumn),
            upperBound: .init(line: upperLine, column: upperColumn)
        )

        #expect(range.text(in: markdown) == expected)
    }

    @Test(arguments: [
        ("before <u>x</u> after", "before <u>x</u> after"),
        ("# before <u>x</u>", "before <u>x</u>"),
        ("- before <u>x</u> after", "before <u>x</u> after"),
        ("> before <u>x</u> after", "before <u>x</u> after"),
        ("> > before <u>x</u> after", "before <u>x</u> after"),
        ("| a <u>b</u> |\n| - |\n| c |", "a <u>b</u>c"),
    ] as [(String, String)])
    func `projects literal inline HTML in every supported placement`(
        markdown: String,
        visibleText: String
    ) {
        // The fixture must really contain two inline-HTML nodes before its output is judged.
        #expect(inlineHTMLNodeCount(in: markdown) == 2)
        let blocks = FlatMarkRenderProjector.project(markdown: markdown).blocks

        #expect(unsupportedValues(in: blocks).map(unsupportedLiteralString) == ["<u>", "</u>"])
        #expect(renderedText(in: blocks) == visibleText)
    }

    @MainActor
    @Test
    func `renders literal inline HTML through native text elements`() throws {
        let content = try #require(paragraphContent(in: "before <u>important</u> after"))
        #expect(flatMarkNativeInlineText(content).string == "before <u>important</u> after")
    }

    @MainActor
    @Test
    func `keeps every existing initializer form while accepting the policy`() {
        let markdown = "# Title"
        let plain = FlatMarkView(markdown: markdown)
        let withBase = FlatMarkView(markdown: markdown, baseURL: nil)
        let withImages = FlatMarkView(markdown: markdown, imageLoader: nil, imageURLPolicy: .webOnly)
        let withLinkTrailingClosure = FlatMarkView(markdown: markdown) { _ in .handled }
        let withTaskToggle = FlatMarkView(markdown: markdown, taskToggleAction: { _ in })
        // A trailing closure that follows a labeled link action keeps resolving to the
        // task-toggle parameter.
        let withToggleTrailingClosure = FlatMarkView(
            markdown: markdown,
            linkActivationAction: { _ in .handled }
        ) { updatedMarkdown in _ = updatedMarkdown.count }
        let withPolicy = FlatMarkView(markdown: markdown, unsupportedContentPolicy: .literal)
        let withPolicyAndToggle = FlatMarkView(
            markdown: markdown,
            unsupportedContentPolicy: .literal,
            linkActivationAction: { _ in .handled }
        ) { updatedMarkdown in _ = updatedMarkdown.count }
        let forms = [
            plain, withBase, withImages, withLinkTrailingClosure, withTaskToggle,
            withToggleTrailingClosure, withPolicy, withPolicyAndToggle,
        ]
        // These constructions are source-compatibility checks, not rendering observations.
        _ = forms
    }

    @Test(arguments: [
        "> see ``Foo`` here\n",
        "- see ``Foo`` here\n",
        "# see ``Foo`` here\n",
        "| see ``Foo`` here |\n| - |\n",
        "> > see ``Foo`` here\n",
    ] as [String])
    func `treats an unknown inline node as unsupported at every supported nesting depth`(
        markdown: String
    ) {
        let document = FlatMarkRenderProjector.project(
            Document(parsing: markdown, options: [.parseSymbolLinks]),
            source: markdown
        )
        let values = unsupportedValues(in: document.blocks)

        #expect(values.count == 1)
        #expect(values.first.map { String($0.literalText.characters) } == "``Foo``")
    }

    @Test(arguments: [
        ("before \\<u>important</u> after", 1, "before <u>important</u> after"),
        ("```\n<div>not html</div>\n```", 0, "<div>not html</div>\n"),
        ("text `<u>x</u>` here", 0, "text <u>x</u> here"),
        ("before <not a tag after", 0, "before <not a tag after"),
        ("`` `<u>` ``", 0, "`<u>`"),
    ] as [(String, Int, String)])
    func `escapes, code, and malformed tags retain existing Markdown semantics`(
        markdown: String,
        unsupportedCount: Int,
        expected: String
    ) {
        let blocks = FlatMarkRenderProjector.project(markdown: markdown).blocks

        #expect(unsupportedValues(in: blocks).count == unsupportedCount)
        #expect(renderedText(in: blocks) == expected)
    }

    @Test(arguments: [
        ("text\n\n> quoted\n>\n> <div>block</div>\n", "textquoted<div>block</div>\n"),
        ("- item\n\n  <div>block</div>\n", "item<div>block</div>\n"),
    ])
    func `projects exact HTML blocks inside quotes and list continuations`(
        markdown: String, expected: String
    ) throws {
        let parsed = Document(parsing: markdown)
        let container = try #require(Array(parsed.children).last)
        let html: HTMLBlock
        if let quote = container as? BlockQuote {
            html = try #require(quote.child(at: 1) as? HTMLBlock)
        } else {
            let list = try #require(container as? UnorderedList)
            let item = try #require(list.child(at: 0) as? ListItem)
            html = try #require(item.child(at: 1) as? HTMLBlock)
        }
        #expect(html.rawHTML == "<div>block</div>\n")
        let blocks = FlatMarkRenderProjector.project(markdown: markdown).blocks
        let block = try #require(blocks.last)
        switch block.kind {
        case let .blockQuote(children):
            #expect(children.last?.kind == .unsupported(literal(html.rawHTML)))
        case let .list(entries):
            let entry = try #require(entries.last)
            guard case let .childBlock(child) = entry else {
                Issue.record("Expected list continuation block")
                return
            }

            #expect(child.block.kind == .unsupported(literal(html.rawHTML)))
        default:
            Issue.record("Expected quote or list container")
        }
        #expect(unsupportedValues(in: blocks).map(unsupportedLiteralString) == [html.rawHTML])
        #expect(renderedText(in: blocks) == expected)
    }

    @Test
    func `projects HTML attributes without link or image metadata`() {
        let document = FlatMarkRenderProjector.project(markdown: """
        ![Diagram](https://example.com/diagram.png)

        <img src="https://evil.example/x.png" onload="go()">
        <script>go()</script>
        <iframe src="https://evil.example/e"></iframe>
        <a href="javascript:go()">tap</a>
        """)
        let blocks = document.blocks
        let links = inlineContents(in: blocks).flatMap(runs(in:)).compactMap { $0.link }

        // A supported Markdown image keeps its destination, while nothing that came from an HTML
        // attribute becomes a link or a request of its own.
        #expect(inlineContents(in: blocks).flatMap(images(in:)).map(\.url) ==
            [URL(string: "https://example.com/diagram.png")])
        #expect(links.isEmpty)
        #expect(renderedText(in: blocks).contains("<img src=\"https://evil.example/x.png\" onload=\"go()\">"))
        #expect(renderedText(in: blocks).contains("<a href=\"javascript:go()\">tap</a>"))
    }
}

/// Every inline content a block tree displays, at any supported nesting depth, in source order.
private func inlineContents(in blocks: [FlatMarkRenderBlock]) -> [FlatMarkRenderInlineContent] {
    blocks.flatMap { block -> [FlatMarkRenderInlineContent] in
        switch block.kind {
        case let .paragraph(content), let .heading(_, content):
            [content]
        case let .blockQuote(children):
            inlineContents(in: children)
        case let .list(entries):
            entries.flatMap { entry -> [FlatMarkRenderInlineContent] in
                switch entry {
                case let .row(row):
                    [row.content]
                case let .childBlock(childBlock):
                    inlineContents(in: [childBlock.block])
                }
            }
        case let .table(table):
            table.header.map(\.content) + table.rows.flatMap { $0.cells.map(\.content) }
        case .codeBlock, .thematicBreak, .unsupported:
            []
        }
    }
}

private func runs(in content: FlatMarkRenderInlineContent) -> [AttributedSubstring] {
    content.components.flatMap { component -> [AttributedSubstring] in
        guard let text = literalText(from: component) else {
            return []
        }

        return text.runs.map { run in text[run.range] }
    }
}

private func images(in content: FlatMarkRenderInlineContent) -> [FlatMarkRenderImage] {
    content.components.compactMap { component in
        guard case let .image(image) = component else {
            return nil
        }

        return image
    }
}

private func unsupportedValues(in blocks: [FlatMarkRenderBlock]) -> [FlatMarkRenderUnsupportedContent] {
    blocks.flatMap { block -> [FlatMarkRenderUnsupportedContent] in
        switch block.kind {
        case let .unsupported(content):
            [content]
        case let .blockQuote(children):
            unsupportedValues(in: children)
        case let .list(entries):
            entries.flatMap { entry -> [FlatMarkRenderUnsupportedContent] in
                switch entry {
                case let .row(row):
                    row.content.components.flatMap(unsupportedValues)
                case let .childBlock(childBlock):
                    unsupportedValues(in: [childBlock.block])
                }
            }
        case let .table(table):
            (table.header.map(\.content) + table.rows.flatMap { $0.cells.map(\.content) })
                .flatMap { content in content.components.flatMap(unsupportedValues) }
        case let .heading(_, content), let .paragraph(content):
            content.components.flatMap(unsupportedValues)
        case .codeBlock, .thematicBreak:
            []
        }
    }
}

/// Every inline-HTML node the parser produced, so a fixture is checked before its output is.
private func inlineHTMLNodeCount(in markdown: String) -> Int {
    func count(_ markup: Markup) -> Int {
        (markup is InlineHTML ? 1 : 0) + markup.children.map(count).reduce(0, +)
    }

    return count(Document(parsing: markdown))
}

/// What the literal policy reads in these blocks, in source order: supported text, the exact
/// replacement for every unsupported node, and code. Only wording: no structure and no geometry.
private func renderedText(in blocks: [FlatMarkRenderBlock]) -> String {
    blocks.map { block -> String in
        switch block.kind {
        case let .unsupported(content):
            unsupportedLiteralString(content)
        case let .paragraph(content), let .heading(_, content):
            content.plainText
        case let .blockQuote(children):
            renderedText(in: children)
        case let .list(entries):
            entries.map { entry -> String in
                switch entry {
                case let .row(row):
                    row.content.plainText
                case let .childBlock(childBlock):
                    renderedText(in: [childBlock.block])
                }
            }
            .joined()
        case let .table(table):
            (table.header.map(\.content) + table.rows.flatMap { $0.cells.map(\.content) })
                .map(\.plainText)
                .joined()
        case let .codeBlock(code):
            code
        case .thematicBreak:
            ""
        }
    }
    .joined()
}

private func unsupportedLiteralString(_ content: FlatMarkRenderUnsupportedContent) -> String {
    String(content.literalText.characters)
}

private func unsupportedValues(
    _ component: FlatMarkRenderInlineContent.Component
) -> [FlatMarkRenderUnsupportedContent] {
    guard case let .unsupported(content) = component else {
        return []
    }

    return [content]
}

private extension FlatMarkRenderInlineContent.Component {
    var unsupportedContent: FlatMarkRenderUnsupportedContent? {
        guard case let .unsupported(content) = self else {
            return nil
        }

        return content
    }
}

private func paragraphContent(of document: FlatMarkRenderDocument) -> FlatMarkRenderInlineContent? {
    guard case let .paragraph(content) = document.blocks.first?.kind else {
        return nil
    }

    return content
}

/// The literal text of one unsupported block kind.
private func literal(_ source: String) -> FlatMarkRenderUnsupportedContent {
    FlatMarkRenderUnsupportedContent(literalText: AttributedString(source))
}

private func run(
    containing text: String,
    in content: FlatMarkRenderInlineContent
) -> AttributedString.Runs.Element? {
    content.components
        .lazy
        .compactMap(literalText)
        .compactMap { attributed in
            attributed.runs.first { run in
                String(attributed[run.range].characters).contains(text)
            }
        }
        .first
}

/// The attributed text a component carries, whether supported or literal unsupported content.
private func literalText(
    from component: FlatMarkRenderInlineContent.Component
) -> AttributedString? {
    switch component {
    case let .text(text):
        text
    case .image:
        nil
    case let .unsupported(unsupported):
        unsupported.literalText
    }
}

private func paragraphContent(in markdown: String) -> FlatMarkRenderInlineContent? {
    paragraphContent(of: FlatMarkRenderProjector.project(markdown: markdown))
}
