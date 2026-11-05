@testable import FlatMark
import Foundation
import Testing

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
    func `projects path-typed identity for every nested render block`() {
        let document = FlatMarkRenderProjector.project(markdown: """
        > Quoted text.
        >
        > - List item
        >
        >   Follow-up paragraph.
        """)

        let blocks = allBlocks(in: document)
        #expect(!blocks.isEmpty)

        // Identity is built from the tree alone: a fresh value made from the path alone equals
        // the projected one, so a missing parser range cannot change or abort identity.
        #expect(blocks.allSatisfy { FlatMarkRenderNodeID(path: $0.id.path) == $0.id })
        #expect(Set(blocks.map(\.id)).count == blocks.count)
        #expect(blocks.map(\.id.path) == [[0], [0, 0], [0, 1], [0, 1, 0, 1]])
    }

    @Test
    func `gives each rendered element of a mixed document its own identity`() throws {
        let document = FlatMarkRenderProjector.project(markdown: """
        # Title

        A paragraph.

        > Quoted text.
        >
        > - Quoted item

        - [ ] Task
          - Nested item

          > Quote inside the task.

          Continuation paragraph.

        | Name | State | Notes |
        | --- | --- | --- |
        | Wide || End |
        | Plain |
        """)

        // Check shape before uniqueness so omitted nested or table content cannot pass.
        #expect(document.blocks.map(blockKindName) == ["heading(1)", "paragraph", "blockQuote", "list", "table"])

        let entries = try #require({
            if case let .list(entries) = document.blocks[3].kind {
                return entries
            }
            return nil
        }())
        #expect(entries.compactMap(row).contains { $0.indentation > 0 })
        #expect(entries.compactMap(childBlock).contains {
            if case .blockQuote = $0.block.kind {
                return true
            }
            return false
        })
        let projectedTable = try #require(table(in: .init(blocks: [document.blocks[4]])))
        #expect(projectedTable.header.count == 3)
        #expect(projectedTable.rows[0].cells[1].colspan == 0)
        #expect(projectedTable.rows[0].cells[1].content.plainText.isEmpty)
        #expect(projectedTable.rows[1].cells.count == 3)
        #expect(projectedTable.rows[1].cells[2].content.plainText.isEmpty)
        #expect(projectedTable.rows[1].cells[2].colspan == 1)

        // A child-block entry and the block it renders share one identity, so each rendered
        // element of the document appears exactly once.
        let paths = renderIDs(in: document).map(\.path)
        for path in [
            [2, 1, 0],
            [3, 0],
            [3, 0, 1, 0],
            [3, 0, 2],
            [3, 0, 2, 0],
            [3, 0, 3],
            [4],
            [4, 0, 2],
            [4, 1, 0, 1],
            [4, 1, 1, 2],
        ] {
            #expect(paths.contains(path), "missing rendered element at \(path)")
        }

        #expect(Set(paths).count == paths.count)
    }

    @Test
    func `a structure-preserving source edit keeps render IDs and refreshes task editing addresses`() throws {
        let tasks = """
        - [ ] Alpha
          - [ ] Beta
            continues below.
        - [ ] Gamma
        """
        let snapshotA = "Intro\n\nPreamble text that is short.\n\n" + tasks
        // The same tree, with a longer preamble that moves every later byte position.
        let snapshotB = "Intro\n\n"
            + "A preamble that spans several source lines so every\n"
            + "byte position below it moves, while the parsed tree\n"
            + "keeps the shape of the snapshot above.\n\n" + tasks

        let documentA = FlatMarkRenderProjector.project(markdown: snapshotA)
        let documentB = FlatMarkRenderProjector.project(markdown: snapshotB)

        #expect(renderIDs(in: documentA).count > 1)
        #expect(renderIDs(in: documentB) == renderIDs(in: documentA))

        let addressesA = taskAddresses(in: documentA.blocks)
        let addressesB = taskAddresses(in: documentB.blocks)
        #expect(addressesA.count == 3)
        #expect(zip(addressesA, addressesB).allSatisfy { $0.path == $1.path })
        #expect(zip(addressesA, addressesB).allSatisfy { $0.sourceRange != $1.sourceRange })

        // The shifted snapshot's own address rewrites exactly Alpha's state byte.
        let alpha = try #require(addressesB.first)
        let toggled = try #require(
            FlatMarkTaskMarkerToggle.toggledMarkdown(in: snapshotB, sourceRange: alpha.sourceRange)
        )
        let originalBytes = Array(snapshotB.utf8)
        let toggledBytes = Array(toggled.utf8)
        let stateOffset = try #require(firstByteIndex(of: "- [ ] Alpha", in: originalBytes)) + 3

        #expect(toggledBytes.count == originalBytes.count)
        #expect(originalBytes.indices.filter { originalBytes[$0] != toggledBytes[$0] } == [stateOffset])
        #expect(toggledBytes[stateOffset] == UInt8(ascii: "x"))
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
        #expect(entries.compactMap(row).map(markerShape) == [
            "ordered(3)",
            "task(isChecked: true, addressed: true)",
            "task(isChecked: false, addressed: true)",
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

        #expect(table.rows.map(\.id.path) == [[0, 1, 0], [0, 1, 1]])
        #expect(table.header.map(\.id.path) == [[0, 0, 0], [0, 0, 1]])
        #expect(table.rows[0].cells.map(\.id.path) == [[0, 1, 0, 0], [0, 1, 0, 1]])
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
    func `renders HTML content literally without a fallback label`() throws {
        let commentLiteral = try #require(
            unsupportedLiteral(in: FlatMarkRenderProjector.project(markdown: "<!-- -->")).first
        )

        #expect(commentLiteral == "<!-- -->\n")
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

    @Test(arguments: [
        ("https://example.com/a", nil, "https://example.com/a"),
        ("http://example.com/a", nil, "http://example.com/a"),
        ("mailto:reader@example.com", nil, "mailto:reader@example.com"),
        ("reader:details", nil, "reader:details"),
        ("intro", "https://example.com/docs/page", "https://example.com/docs/intro"),
        ("intro", "https://example.com/docs/page/", "https://example.com/docs/page/intro"),
        ("../intro", "https://example.com/docs/page", "https://example.com/intro"),
        ("/intro", "https://example.com/docs/page", "https://example.com/intro"),
        ("?mode=read", "https://example.com/docs/page", "https://example.com/docs/page?mode=read"),
        ("#section", "https://example.com/docs/page", "https://example.com/docs/page#section"),
        ("//other.example/intro", "https://example.com/docs/page", "https://other.example/intro"),
        ("foo%20bar", "https://example.com/docs/page", "https://example.com/docs/foo%20bar"),
        ("intro", "file:///docs/page", "file:///docs/intro"),
        ("intro", nil, nil),
        ("#section", nil, nil),
        ("//example.com/intro", nil, nil),
        ("intro", "docs/page", nil),
        ("#section", "docs/page", nil),
        ("https://example.com/a", "docs/page", "https://example.com/a"),
        ("mailto:reader@example.com", "docs/page", "mailto:reader@example.com"),
        ("reader:details", "docs/page", "reader:details"),
        ("", "https://example.com/docs/page", nil),
        ("", nil, nil),
        ("http://[", nil, nil),
        ("https://example.com:bad/", "https://example.com/docs/page", nil),
    ] as [(String, String?, String?)])
    func `projects only absolute Foundation destinations`(
        destination: String, base: String?, expected: String?
    ) throws {
        let content = try #require(paragraphContent(
            in: "[**Label**](<\(destination)>)",
            baseURL: base.flatMap { URL(string: $0) }
        ))
        let label = try #require(run(containing: "Label", in: content))
        #expect(content.plainText == "Label")
        #expect(label.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
        #expect(label.link?.absoluteString == expected)
    }

    @Test(arguments: ["foo bar", "foo%zz", "https://example.com/a b"])
    func `uses Foundation normalization without additional validation`(destination: String) throws {
        let base = try #require(URL(string: "https://example.com/docs/page"))
        let expected = try #require(URL(string: destination, relativeTo: base)?.absoluteURL)
        let content = try #require(paragraphContent(in: "[Label](<\(destination)>)", baseURL: base))
        #expect(run(containing: "Label", in: content)?.link == expected)
    }

    @Test(arguments: [nil, "docs/page", "https://example.com/docs/page"] as [String?])
    func `reference links tables and nested blocks share destination eligibility`(base: String?) throws {
        let document = FlatMarkRenderProjector.project(markdown: """
        | [**Header**][target] |
        | --- |
        | [Cell][target] |

        > [Quote][target]
        >
        > - [Item][target]

        [target]: intro
        """, baseURL: base.flatMap { URL(string: $0) })
        let projectedTable = try #require(table(in: document))
        let quote = try #require(allBlocks(in: document)
            .compactMap { block -> FlatMarkRenderInlineContent? in
                if case let .paragraph(content) = block.kind {
                    return content
                }
                return nil
            }
            .first)
        let list = try #require(allBlocks(in: document)
            .compactMap { block -> [FlatMarkListRenderEntry]? in
                if case let .list(entries) = block.kind {
                    return entries
                }
                return nil
            }
            .first)
        let item = try #require(list.compactMap(row).first)
        let expected = base == "https://example.com/docs/page" ? URL(string: "https://example.com/docs/intro") : nil
        for (content, label) in [(projectedTable.header[0].content, "Header"),
                                 (projectedTable.rows[0].cells[0].content, "Cell"),
                                 (quote, "Quote"), (item.content, "Item")]
        {
            #expect(content.plainText == label)
            #expect(run(containing: label, in: content)?.link == expected)
        }
        #expect(run(containing: "Header", in: projectedTable.header[0].content)?
            .inlinePresentationIntent?
            .contains(.stronglyEmphasized) == true)
    }

    @Test(arguments: [
        ("<https://example.com>", "https://example.com", "https://example.com"),
        ("<reader@example.com>", "reader@example.com", "mailto:reader@example.com"),
        ("<reader:details>", "reader:details", "reader:details"),
        ("[Label][ref]\n\n[ref]: mailto:reader@example.com", "Label", "mailto:reader@example.com"),
        ("[Label][]\n\n[Label]: reader:details", "Label", "reader:details"),
        ("[Label]\n\n[Label]: https://example.com", "Label", "https://example.com"),
    ])
    func `parser supported autolinks and reference forms retain destinations`(
        markdown: String, label: String, destination: String
    ) throws {
        let content = try #require(paragraphContent(in: markdown))
        #expect(content.plainText == label)
        #expect(run(containing: label, in: content)?.link == URL(string: destination))
    }

    @Test(arguments: ["", "intro", "http://["])
    func `inert linked images retain their source and alt text`(destination: String) throws {
        let content = try #require(paragraphContent(
            in: "[![Diagram](https://example.com/diagram.png)](<\(destination)>)",
            baseURL: URL(string: "docs/page")
        ))
        #expect(content.components == [.image(FlatMarkRenderImage(
            url: URL(string: "https://example.com/diagram.png"), altText: "Diagram"
        ))])
    }

    @Test
    func `navigation schemes do not grant image fetching permission`() throws {
        let content = try #require(paragraphContent(
            in: "[![Diagram](reader:image)](reader:details)"
        ))
        let projectedImage = try #require(content.components.compactMap(image).first)
        #expect(projectedImage.link == URL(string: "reader:details"))
        #expect(try FlatMarkImageRequest.resolve(url: projectedImage.url, policy: .webOnly)
            == .rejected(#require(URL(string: "reader:image"))))
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

        #expect(content.components.compactMap(image).compactMap(\.link) == [
            URL(string: "https://example.com/one"),
            URL(string: "https://example.com/two"),
        ])
    }

    @Test
    func `official Setext headings preserve levels and inline emphasis`() throws {
        // GFM 0.29-gfm, example 50, unchanged.
        let document = FlatMarkRenderProjector.project(markdown:
            "Foo *bar*\n=========\n\nFoo *bar*\n---------\n")
        #expect(document.blocks.count == 2)
        for (index, block) in document.blocks.enumerated() {
            guard case let .heading(level, content) = block.kind else {
                Issue.record("Expected Setext heading")
                continue
            }
            #expect(level == index + 1)
            #expect(content.plainText == "Foo bar")
            #expect(run(containing: "bar", in: content)?.inlinePresentationIntent?.contains(.emphasized) == true)
        }
    }

    @Test(arguments: [
        // GFM 0.29-gfm, examples 658 and 659, unchanged.
        "foo  \nbaz\n", "foo\\\nbaz\n",
    ])
    func `official hard break forms project the same native newline`(markdown: String) throws {
        let content = try #require(paragraphContent(in: markdown))
        #expect(content.plainText == "foo\nbaz")
    }

    @Test
    func `official escaped punctuation does not introduce emphasis`() throws {
        // GFM 0.29-gfm, example 311, unchanged: escaped backslash followed by emphasis.
        let content = try #require(paragraphContent(in: "\\\\*emphasis*\n"))
        #expect(content.plainText == "\\emphasis")
        #expect(run(containing: "\\", in: content)?.inlinePresentationIntent?.contains(.emphasized) != true)
        #expect(run(containing: "emphasis", in: content)?.inlinePresentationIntent?.contains(.emphasized) == true)
    }

    @Test(arguments: [
        // GFM 0.29-gfm, examples 321, 322 and 323, unchanged.
        ("&nbsp; &amp; &copy; &AElig; &Dcaron;\n&frac34; &HilbertSpace; &DifferentialD;\n&ClockwiseContourIntegral; &ngE;\n",
         "\u{00A0} & © Æ Ď\n¾ ℋ ⅆ\n∲ ≧̸"),
        ("&#35; &#1234; &#992; &#0;\n", "# Ӓ Ϡ �"),
        ("&#X22; &#XD06; &#xcab;\n", "\" ആ ಫ"),
    ])
    func `official character references project decoded text`(markdown: String, expected: String) throws {
        #expect(try #require(paragraphContent(in: markdown)).plainText == expected)
    }

    @Test
    func `container integration keeps rich linked images formatting and breaks`() throws {
        // Adapted integration fixture, not an unchanged official example:
        // GFM 0.29-gfm examples 50 (heading), 526 (linked image), 664 (emphasized break).
        let document = FlatMarkRenderProjector.project(markdown: """
        > - [**Label _nested_**](details) [![foo *bar*](image.png "omitted")](details)
        >
        >   | Heading | Image |
        >   | --- | --- |
        >   | [~~Cell~~](details) | ![Alt](image.png) |
        >
        >   *foo\\
        >   bar*
        """, baseURL: URL(string: "https://example.com/docs/"))
        guard case let .blockQuote(children) = try #require(document.blocks.first).kind,
              case let .list(entries) = try #require(children.first).kind else {
            Issue.record("Expected quote containing list")
            return
        }
        let item = try #require(entries.compactMap(row).first)
        let nested = try #require(run(containing: "nested", in: item.content))
        #expect(nested.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
        #expect(nested.inlinePresentationIntent?.contains(.emphasized) == true)
        #expect(nested.link == URL(string: "https://example.com/docs/details"))
        let linkedImage = try #require(item.content.components.compactMap(image).first)
        #expect(linkedImage.url == URL(string: "https://example.com/docs/image.png"))
        #expect(linkedImage.link == nested.link)
        #expect(linkedImage.altContent.plainText == "foo bar")
        #expect(run(containing: "bar", in: linkedImage.altContent)?.inlinePresentationIntent?
            .contains(.emphasized) == true)
        let continuations = entries.compactMap(childBlock)
        #expect(continuations.count == 2)
        guard case let .table(projectedTable) = continuations[0].block.kind,
              case let .paragraph(breakContent) = continuations[1].block.kind else {
            Issue.record("Expected table then paragraph continuation")
            return
        }
        let cell = projectedTable.rows[0].cells[0].content
        #expect(cell.plainText == "Cell")
        #expect(run(containing: "Cell", in: cell)?.link == nested.link)
        #expect(run(containing: "Cell", in: cell)?.inlinePresentationIntent?.contains(.strikethrough) == true)
        let cellImage = try #require(projectedTable.rows[0].cells[1].content.components.compactMap(image).first)
        #expect(cellImage.url == linkedImage.url)
        #expect(cellImage.altContent.plainText == "Alt")
        #expect(cellImage.link == nil)
        #expect(breakContent.plainText == "foo\nbar")
        #expect(run(containing: "foo", in: breakContent)?.inlinePresentationIntent?.contains(.emphasized) == true)
        #expect(run(containing: "bar", in: breakContent)?.inlinePresentationIntent?.contains(.emphasized) == true)
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

private func blockKindName(_ block: FlatMarkRenderBlock) -> String {
    switch block.kind {
    case .paragraph:
        "paragraph"
    case let .heading(level, _):
        "heading(\(level))"
    case .codeBlock:
        "codeBlock"
    case .blockQuote:
        "blockQuote"
    case .list:
        "list"
    case .thematicBreak:
        "thematicBreak"
    case .table:
        "table"
    case .unsupported:
        "unsupported"
    }
}

private func renderIDs(in document: FlatMarkRenderDocument) -> [FlatMarkRenderNodeID] {
    renderIDs(in: document.blocks)
}

/// Every represented identity in render order, including continuation and padding cells.
private func renderIDs(in blocks: [FlatMarkRenderBlock]) -> [FlatMarkRenderNodeID] {
    blocks.flatMap { block -> [FlatMarkRenderNodeID] in
        var ids = [block.id]

        switch block.kind {
        case let .blockQuote(children):
            ids += renderIDs(in: children)
        case let .list(entries):
            for entry in entries {
                switch entry {
                case let .row(row):
                    ids.append(row.id)
                case let .childBlock(childBlock):
                    ids += renderIDs(in: [childBlock.block])
                }
            }
        case let .table(table):
            ids += table.header.map(\.id)
            for row in table.rows {
                ids.append(row.id)
                ids += row.cells.map(\.id)
            }
        default:
            break
        }

        return ids
    }
}

/// One projected task row's structural path and the editing address its marker carries.
private typealias TaskAddress = (path: [Int], sourceRange: FlatMarkSourceRange)

private func taskAddresses(in blocks: [FlatMarkRenderBlock]) -> [TaskAddress] {
    blocks.flatMap { block -> [TaskAddress] in
        switch block.kind {
        case let .blockQuote(children):
            return taskAddresses(in: children)

        case let .list(entries):
            return entries.flatMap { entry -> [TaskAddress] in
                switch entry {
                case let .row(row):
                    guard case let .task(_, sourceRange) = row.marker, let sourceRange else {
                        return []
                    }

                    return [(path: row.id.path, sourceRange: sourceRange)]

                case let .childBlock(childBlock):
                    return taskAddresses(in: [childBlock.block])
                }
            }

        default:
            return []
        }
    }
}

private func firstByteIndex(of pattern: String, in bytes: [UInt8]) -> Int? {
    let needle = Array(pattern.utf8)
    var start = 0
    while start + needle.count <= bytes.count {
        if Array(bytes[start ..< start + needle.count]) == needle {
            return start
        }
        start += 1
    }

    return nil
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

private func markerShape(_ row: FlatMarkListRenderRow) -> String {
    switch row.marker {
    case .unordered:
        "unordered"
    case let .ordered(index):
        "ordered(\(index))"
    case let .task(isChecked, sourceRange):
        "task(isChecked: \(isChecked), addressed: \(sourceRange != nil))"
    }
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

private func unsupportedLiteral(in document: FlatMarkRenderDocument) -> [String] {
    allBlocks(in: document).compactMap { block -> String? in
        guard case let .unsupported(content) = block.kind else {
            return nil
        }

        return text(of: content.literalText)
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
    content.components
        .lazy
        .compactMap(attributedText)
        .compactMap { attributedText in
            run(containing: text, in: attributedText)
        }
        .first
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
