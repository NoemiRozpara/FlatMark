import Foundation
import Testing
@testable import FlatMark

// MARK: - FlatMarkRenderProjectorTests

struct FlatMarkRenderProjectorTests {
    @Test
    func `projects basic blocks with stable structural paths`() {
        let document = FlatMarkRenderProjector.project(markdown: """
        # Title

        A paragraph.

        > Quoted text.

        ```swift
        print("Hello")
        ```

        ---
        """)

        #expect(document.blocks.map(\.id.path) == [[0], [1], [2], [3], [4]])
        #expect(document.blocks[0].kind == .heading(level: 1, content: "Title"))
        #expect(document.blocks[1].kind == .paragraph("A paragraph."))
        guard case let .blockQuote(quotedBlocks) = document.blocks[2].kind else {
            Issue.record("Expected a block quote")
            return
        }

        #expect(quotedBlocks.map(\.id.path) == [[2, 0]])
        #expect(quotedBlocks.map(\.kind) == [.paragraph("Quoted text.")])
        #expect(document.blocks[3].kind == .codeBlock("print(\"Hello\")\n"))
        #expect(document.blocks[4].kind == .thematicBreak)
    }

    @Test
    func `projects a source position for every nested render block`() {
        let document = FlatMarkRenderProjector.project(markdown: """
        > Quoted text.
        >
        > - List item
        >
        >   Follow-up paragraph.
        """)

        #expect(allBlocks(in: document).map(\.id.sourceRange).count == allBlocks(in: document).count)
    }

    @Test
    func `flattens mixed list rows with structural paths indentation and markers`() {
        let document = FlatMarkRenderProjector.project(markdown: """
        3. Ordered
           - [x] Done
           - [ ] Pending
        """)

        let entries = listEntries(in: document)

        #expect(document.blocks.map(\.id.path) == [[0]])
        #expect(entries.map(\.id.path) == [[0, 0], [0, 0, 1, 0], [0, 0, 1, 1]])
        #expect(entries.compactMap(row).map(\.indentation) == [0, 1, 1])
        #expect(entries.compactMap(row).map(\.marker) == [
            .ordered(index: 3),
            .task(isChecked: true),
            .task(isChecked: false),
        ])
        #expect(entries.compactMap(row).map(\.content.plainText) == ["Ordered", "Done", "Pending"])
    }

    @Test
    func `retains rich non-list item children without nesting list rows`() {
        let document = FlatMarkRenderProjector.project(markdown: """
        - > Quoted text.

          Follow-up paragraph.

          ```swift
          let isReady = true
          ```
        """)

        guard case let .list(entries) = document.blocks.first?.kind else {
            Issue.record("Expected a flattened list")
            return
        }

        #expect(entries.map(\.id.path) == [[0, 0], [0, 0, 0], [0, 0, 1], [0, 0, 2]])
        #expect(entries.map(entryKind) == ["row", "child block", "child block", "child block"])
        #expect(entries.compactMap(childBlock).map(\.indentation) == [1, 1, 1])
        #expect(entries.compactMap(childBlock).map(\.block.kind) == [
            .blockQuote([allBlocks(in: document)[2]]),
            .paragraph("Follow-up paragraph."),
            .codeBlock("let isReady = true\n"),
        ])
    }

    @Test
    func `preserves a continuation block after its nested list`() {
        let document = FlatMarkRenderProjector.project(markdown: """
        - Parent
          - Child

          Follow-up paragraph.
        """)

        let entries = listEntries(in: document)

        #expect(entries.map(\.id.path) == [[0, 0], [0, 0, 1, 0], [0, 0, 2]])
        #expect(entries.map(entryKind) == ["row", "row", "child block"])
    }

    @Test
    func `projects tables with ordered attributed header and body cells`() throws {
        let document = FlatMarkRenderProjector.project(markdown: """
        | **Name** | State |
        | --- | --- |
        | Alpha | Ready |
        | Beta | Done |
        """)
        let table = try #require(table(in: document))

        #expect(table.rows.map(\.id) == ["0.row.0", "0.row.1"])
        #expect(table.header.map { text(of: $0.content) } == ["Name", "State"])
        #expect(table.rows.map { $0.cells.map { text(of: $0.content) } } == [
            ["Alpha", "Ready"],
            ["Beta", "Done"],
        ])
        #expect(run(containing: "Name", in: table.header[0].content)?.inlinePresentationIntent?
            .contains(.stronglyEmphasized) == true)
        #expect(table.header.allSatisfy { $0.colspan == 1 })
    }

    @Test
    func `projects a header-only GFM table`() throws {
        let document = FlatMarkRenderProjector.project(markdown: """
        | Name | State |
        | --- | --- |
        """)
        let table = try #require(table(in: document))

        #expect(table.header.map { text(of: $0.content) } == ["Name", "State"])
        #expect(table.rows.isEmpty)
    }

    @Test
    func `decodes native table spans without exposing continuation markers`() throws {
        let document = FlatMarkRenderProjector.project(markdown: """
        | First | Second | Third |
        | --- | --- | --- |
        | Wide || End |
        | Tall | Middle | End |
        | ^ | Next | Last |
        """)
        let table = try #require(table(in: document))
        let wideRow = try #require(table.rows.first)
        let tallRow = try #require(table.rows.dropFirst().first)
        let continuationRow = try #require(table.rows.dropFirst(2).first)

        #expect(wideRow.cells[0].colspan == 2)
        #expect(text(of: wideRow.cells[0].content) == "Wide")
        #expect(text(of: wideRow.cells[1].content).isEmpty)
        #expect(tallRow.cells[0].colspan == 1)
        #expect(text(of: continuationRow.cells[0].content).isEmpty)
        #expect(table.rows.flatMap(\.cells).allSatisfy {
            !text(of: $0.content).contains("^") && !text(of: $0.content).contains("||")
        })
    }

    @Test
    func `keeps authored blank cells distinct from span fillers and projects uneven input safely`() throws {
        let blankAndSpanned = FlatMarkRenderProjector.project(markdown: """
        | A | B | C |
        | --- | --- | --- |
        | | Value | End |
        | Wide || End |
        """)
        let projectedTable = try #require(table(in: blankAndSpanned))
        let blank = projectedTable.rows[0].cells[0]
        let spanFiller = projectedTable.rows[1].cells[1]
        let uneven = try #require(table(in: FlatMarkRenderProjector.project(markdown: """
        | A | B | C |
        | --- | --- | --- |
        | One |
        | Two | Three | Four |
        """)))

        #expect(text(of: blank.content).isEmpty)
        #expect(blank.colspan == 1)
        #expect(text(of: spanFiller.content).isEmpty)
        #expect(uneven.header.count == 3)
        #expect(uneven.rows.allSatisfy { $0.cells.count == 3 })
        #expect(FlatMarkRenderProjector.project(markdown: "").blocks.isEmpty)
    }

    @Test
    func `projects HTML fallback content visibly when source content is empty`() throws {
        let image = try #require(paragraphContent(in: "![](https://example.com/diagram.png)"))
        #expect(text(of: image) == "Image")

        let html = FlatMarkRenderProjector.project(markdown: "<!-- -->")
        let htmlFallback = fallbackText(in: html)

        #expect(!htmlFallback.isEmpty)
        #expect(htmlFallback.allSatisfy { !$0.isEmpty })
    }

    @Test
    func `treats directive-like text as an ordinary GFM paragraph`() throws {
        let content = try #require(paragraphContent(in: """
        @Unknown {
        Visible descendant
        }
        """))

        #expect(content.plainText == "@Unknown {\nVisible descendant\n}")
    }

    @Test
    func `retains raw HTML in the unsupported fallback`() {
        let document = FlatMarkRenderProjector.project(markdown: "<details>Visible literal</details>")

        #expect(document.blocks.first?.kind ==
            .fallback(type: "HTMLBlock", content: "<details>Visible literal</details>\n"))
    }

    @Test
    func `projects nested inline formatting links and both break types`() throws {
        let markdown = "**Bold and _italic_** with ~~strike~~ and `code` [link](https://example.com).\nSoft break\nhard break\u{20}\u{20}\nnext line"
        let content = try #require(paragraphContent(in: markdown))

        #expect(content.plainText ==
            "Bold and italic with strike and code link.\nSoft break\nhard break\nnext line")
        #expect(run(containing: "Bold and ", in: content)?.inlinePresentationIntent?
            .contains(.stronglyEmphasized) == true)

        let nestedRun = try #require(run(containing: "italic", in: content))
        #expect(nestedRun.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
        #expect(nestedRun.inlinePresentationIntent?.contains(.emphasized) == true)
        #expect(run(containing: "strike", in: content)?.inlinePresentationIntent?.contains(.strikethrough) == true)
        #expect(run(containing: "code", in: content)?.inlinePresentationIntent?.contains(.code) == true)
        #expect(run(containing: "link", in: content)?.link == URL(string: "https://example.com"))
    }

    @Test
    func `projects images as explicit renderer values`() throws {
        let content = try #require(paragraphContent(in: "![Architecture diagram](https://example.com/diagram.png)"))
        let component = try #require(content.components.first)

        #expect(component == .image(FlatMarkRenderImage(
            url: URL(string: "https://example.com/diagram.png"),
            altText: "Architecture diagram"
        )))
    }

    @Test
    func `retains a resolved link on a linked image`() throws {
        let content = try #require(paragraphContent(
            in: "[![Diagram](diagram.png)](details.html)",
            baseURL: URL(string: "https://example.com/docs/")
        ))
        let component = try #require(content.components.first)

        #expect(component == .image(FlatMarkRenderImage(
            url: URL(string: "https://example.com/docs/diagram.png"),
            altText: "Diagram",
            link: URL(string: "https://example.com/docs/details.html")
        )))
    }

    @Test
    func `does not promote linked image destinations to the surrounding paragraph`() throws {
        let content = try #require(paragraphContent(
            in: "Before [![A](a.png)](one) after [![B](b.png)](two)",
            baseURL: URL(string: "https://example.com/")
        ))

        #expect(content.standaloneLinkedImageDestination == nil)
        #expect(content.components.compactMap(image).compactMap(\.link) == [
            URL(string: "https://example.com/one"),
            URL(string: "https://example.com/two"),
        ])
    }

    @Test
    func `exposes a standalone linked image destination`() throws {
        let content = try #require(paragraphContent(
            in: "[![A](a.png)](one)",
            baseURL: URL(string: "https://example.com/")
        ))

        #expect(content.standaloneLinkedImageDestination ==
            URL(string: "https://example.com/one"))
    }

    @Test
    func `projects indented code headings and directive-like text as GFM`() {
        let document = FlatMarkRenderProjector.project(markdown: """
        #### Heading

            let value = 1

        @Unknown {}
        """)

        #expect(document.blocks[0].kind == .heading(level: 4, content: "Heading"))
        #expect(document.blocks[1].kind == .codeBlock("let value = 1\n"))

        #expect(document.blocks[2].kind == .paragraph("@Unknown {}"))
    }
}

private func paragraphContent(
    in markdown: String,
    baseURL: URL? = nil
) -> FlatMarkRenderInlineContent? {
    let document = FlatMarkRenderProjector.project(markdown: markdown, baseURL: baseURL)

    guard case let .paragraph(content) = document.blocks.first?.kind else {
        return nil
    }

    return content
}

private func listEntries(in document: FlatMarkRenderDocument) -> [FlatMarkListRenderEntry] {
    guard case let .list(entries) = document.blocks.first?.kind else {
        return []
    }

    return entries
}

private func entryKind(_ entry: FlatMarkListRenderEntry) -> String {
    switch entry {
    case .row:
        "row"
    case .childBlock:
        "child block"
    }
}

private func row(in entry: FlatMarkListRenderEntry) -> FlatMarkListRenderRow? {
    guard case let .row(row) = entry else {
        return nil
    }

    return row
}

private func childBlock(in entry: FlatMarkListRenderEntry) -> FlatMarkListChildRenderBlock? {
    guard case let .childBlock(childBlock) = entry else {
        return nil
    }

    return childBlock
}

private func allBlocks(in document: FlatMarkRenderDocument) -> [FlatMarkRenderBlock] {
    allBlocks(in: document.blocks)
}

private func allBlocks(in blocks: [FlatMarkRenderBlock]) -> [FlatMarkRenderBlock] {
    blocks.flatMap { block -> [FlatMarkRenderBlock] in
        switch block.kind {
        case let .blockQuote(children):
            return [block] + allBlocks(in: children)
        case let .list(entries):
            let childBlocks: [FlatMarkRenderBlock] = entries.compactMap { entry in
                guard case let .childBlock(childBlock) = entry else {
                    return nil
                }

                return childBlock.block
            }
            return [block] + allBlocks(in: childBlocks)
        default:
            return [block]
        }
    }
}

private func fallbackText(in document: FlatMarkRenderDocument) -> [String] {
    allBlocks(in: document).compactMap { block -> String? in
        guard case let .fallback(_, content) = block.kind else {
            return nil
        }

        return text(of: content)
    }
}

private func table(in document: FlatMarkRenderDocument) -> FlatMarkRenderTable? {
    guard case let .table(table) = document.blocks.first?.kind else {
        return nil
    }

    return table
}

private func text(of content: AttributedString) -> String {
    String(content.characters)
}

private func text(of content: FlatMarkRenderInlineContent) -> String {
    content.plainText
}

private func image(
    from component: FlatMarkRenderInlineContent.Component
) -> FlatMarkRenderImage? {
    guard case let .image(image) = component else {
        return nil
    }

    return image
}

private func run(
    containing text: String,
    in content: FlatMarkRenderInlineContent
) -> AttributedString.Runs.Element? {
    content.components.lazy.compactMap(attributedText).compactMap { attributedText in
        run(containing: text, in: attributedText)
    }.first
}

private func attributedText(
    from component: FlatMarkRenderInlineContent.Component
) -> AttributedString? {
    guard case let .text(text) = component else {
        return nil
    }

    return text
}

private func run(
    containing text: String,
    in attributedString: AttributedString
) -> AttributedString.Runs.Element? {
    attributedString.runs.first { run in
        String(attributedString[run.range].characters).contains(text)
    }
}
