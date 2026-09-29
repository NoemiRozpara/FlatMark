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
        #expect(entries.compactMap(row).map { String($0.content.characters) } == ["Ordered", "Done", "Pending"])
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
    func `projects fallback content visibly when source content is empty`() throws {
        let image = try #require(paragraphContent(in: "![](https://example.com/diagram.png)"))
        #expect(text(of: image) == "Image: image (https://example.com/diagram.png)")

        let html = FlatMarkRenderProjector.project(markdown: "<!-- -->")
        let unknown = FlatMarkRenderProjector.project(markdown: "@Unknown {}")
        let htmlFallback = fallbackText(in: html)
        let unknownFallback = fallbackText(in: unknown)

        #expect(!htmlFallback.isEmpty)
        #expect(htmlFallback.allSatisfy { !$0.isEmpty })
        #expect(!unknownFallback.isEmpty)
        #expect(unknownFallback.allSatisfy { !$0.isEmpty })
    }

    @Test
    func `projects unsupported nodes as labeled readable content`() {
        let document = FlatMarkRenderProjector.project(markdown: """
        @Unknown {
        Visible descendant
        }
        """)

        guard case let .fallback(type, content) = document.blocks.first?.kind else {
            Issue.record("Expected a fallback block")
            return
        }

        #expect(type == "BlockDirective")
        #expect(content == "Visible descendant")
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

        #expect(String(content.characters) ==
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
    func `projects images as readable text without loading them`() throws {
        let content = try #require(paragraphContent(in: "![Architecture diagram](https://example.com/diagram.png)"))

        #expect(String(content.characters) == "Image: Architecture diagram (https://example.com/diagram.png)")
    }

    @Test
    func `projects indented code headings and empty unsupported nodes readably`() {
        let document = FlatMarkRenderProjector.project(markdown: """
        #### Heading

            let value = 1

        @Unknown {}
        """)

        #expect(document.blocks[0].kind == .heading(level: 4, content: "Heading"))
        #expect(document.blocks[1].kind == .codeBlock("let value = 1\n"))

        guard case let .fallback(type, content) = document.blocks[2].kind else {
            Issue.record("Expected a fallback block")
            return
        }

        #expect(type == "BlockDirective")
        #expect(String(content.characters) == "[BlockDirective]")
    }
}

private func paragraphContent(in markdown: String) -> AttributedString? {
    let document = FlatMarkRenderProjector.project(markdown: markdown)

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

private func run(
    containing text: String,
    in attributedString: AttributedString
) -> AttributedString.Runs.Element? {
    attributedString.runs.first { run in
        String(attributedString[run.range].characters).contains(text)
    }
}
