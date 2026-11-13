import Foundation
import Markdown

// MARK: - FlatMarkRenderProjector

enum FlatMarkRenderProjector {
    static func project(
        markdown: String,
        baseURL: URL? = nil
    ) -> FlatMarkRenderDocument {
        project(Document(parsing: markdown), source: markdown, baseURL: baseURL)
    }

    /// Projects a document the caller already parsed, against the snapshot it was parsed from.
    ///
    /// Lets fixtures supply node kinds absent from production parsing. Production views reuse
    /// the projection retained by ``FlatMarkDocument``.
    static func project(
        _ document: Document,
        source: String,
        baseURL: URL? = nil
    ) -> FlatMarkRenderDocument {
        FlatMarkDocumentProjector(source: source, baseURL: baseURL).document(from: document)
    }
}

// MARK: - FlatMarkDocumentProjector

/// Projects block values using one snapshot and base URL for source extraction and resolution.
private struct FlatMarkDocumentProjector {
    let source: String
    let baseURL: URL?

    func document(from markup: some Markup) -> FlatMarkRenderDocument {
        FlatMarkRenderDocument(blocks: projectChildren(of: markup, path: [], indentation: 0))
    }

    func projectChildren(of markup: some Markup, path: [Int], indentation: Int) -> [FlatMarkRenderBlock] {
        markup.children.enumerated().map { index, child in
            project(child, path: path + [index], indentation: indentation)
        }
    }

    func project(_ markup: any Markup, path: [Int], indentation: Int) -> FlatMarkRenderBlock {
        let id = id(path: path)

        switch markup {
        case let paragraph as Paragraph:
            return FlatMarkRenderBlock(
                id: id,
                kind: .paragraph(inlineContent(of: paragraph))
            )

        case let heading as Heading:
            return FlatMarkRenderBlock(
                id: id,
                kind: .heading(level: heading.level, content: inlineContent(of: heading))
            )

        case let codeBlock as CodeBlock:
            return FlatMarkRenderBlock(
                id: id,
                kind: .codeBlock(codeBlock.code)
            )

        case let blockQuote as BlockQuote:
            return FlatMarkRenderBlock(
                id: id,
                kind: .blockQuote(projectChildren(
                    of: blockQuote,
                    path: path,
                    indentation: indentation
                ))
            )

        case let orderedList as OrderedList:
            return listBlock(
                orderedList,
                startIndex: Int(orderedList.startIndex),
                path: path,
                indentation: indentation
            )

        case let unorderedList as UnorderedList:
            return listBlock(
                unorderedList,
                startIndex: nil,
                path: path,
                indentation: indentation
            )

        case is ThematicBreak:
            return FlatMarkRenderBlock(
                id: id,
                kind: .thematicBreak
            )

        case let table as Table:
            return FlatMarkRenderBlock(
                id: id,
                kind: .table(tableProjection(from: table, path: path))
            )

        case let htmlBlock as HTMLBlock:
            return FlatMarkRenderBlock(
                id: id,
                kind: .unsupported(unsupported(htmlBlock))
            )

        default:
            return FlatMarkRenderBlock(
                id: id,
                kind: .unsupported(unsupported(markup))
            )
        }
    }

    func listBlock(
        _ list: some Markup,
        startIndex: Int?,
        path: [Int],
        indentation: Int
    ) -> FlatMarkRenderBlock {
        let rows = listRows(
            from: list,
            startIndex: startIndex,
            path: path,
            indentation: indentation
        )

        return FlatMarkRenderBlock(
            id: id(path: path),
            kind: .list(rows)
        )
    }

    func listRows(
        from list: some Markup,
        startIndex: Int?,
        path: [Int],
        indentation: Int
    ) -> [FlatMarkListRenderEntry] {
        list.children.enumerated().flatMap { index, child -> [FlatMarkListRenderEntry] in
            guard let item = child as? ListItem else {
                return []
            }

            let itemPath = path + [index]
            let marker = listMarker(for: item, orderedIndex: startIndex.map { $0 + index })
            let row = FlatMarkListRenderRow(
                id: id(path: itemPath),
                indentation: indentation,
                marker: marker,
                content: firstParagraphContent(of: item) ?? FlatMarkRenderInlineContent()
            )
            let children = item.children.enumerated().flatMap { childIndex, child in
                listItemEntries(
                    from: child,
                    at: childIndex,
                    itemPath: itemPath,
                    indentation: indentation + 1
                )
            }

            return [.row(row)] + children
        }
    }

    func listItemEntries(
        from markup: any Markup,
        at index: Int,
        itemPath: [Int],
        indentation: Int
    ) -> [FlatMarkListRenderEntry] {
        guard !(index == 0 && markup is Paragraph) else {
            return []
        }

        let path = itemPath + [index]
        return switch markup {
        case let orderedList as OrderedList:
            listRows(
                from: orderedList,
                startIndex: Int(orderedList.startIndex),
                path: path,
                indentation: indentation
            )

        case let unorderedList as UnorderedList:
            listRows(
                from: unorderedList,
                startIndex: nil,
                path: path,
                indentation: indentation
            )

        default:
            [
                FlatMarkListRenderEntry.childBlock(
                    FlatMarkListChildRenderBlock(
                        indentation: indentation,
                        block: project(markup, path: path, indentation: indentation)
                    )
                ),
            ]
        }
    }

    func listMarker(for item: ListItem, orderedIndex: Int?) -> FlatMarkListMarker {
        switch item.checkbox {
        case .checked:
            .task(isChecked: true, sourceRange: item.range.map { FlatMarkSourceRange($0) })
        case .unchecked:
            .task(isChecked: false, sourceRange: item.range.map { FlatMarkSourceRange($0) })
        case nil:
            orderedIndex.map(FlatMarkListMarker.ordered) ?? .unordered
        }
    }

    func firstParagraphContent(of item: ListItem) -> FlatMarkRenderInlineContent? {
        guard let paragraph = item.child(at: 0) as? Paragraph else {
            return nil
        }

        return inlineContent(of: paragraph)
    }

    func tableProjection(from table: Table, path: [Int]) -> FlatMarkRenderTable {
        // swift-markdown stores Head at child 0 and Body at child 1; continuation
        // cells are real children and retain their indices within those branches.
        let sourceHeader = Array(table.head.cells)
        let sourceRows = table.body.rows.map { Array($0.cells) }
        let columnCount = ([sourceHeader.count] + sourceRows.map(\.count)).max() ?? 0
        let header = tableCells(
            from: sourceHeader,
            path: path + [0],
            columnCount: columnCount
        )
        let rows = sourceRows.enumerated().map { index, sourceCells in
            FlatMarkRenderTable.Row(
                id: id(path: path + [1, index]),
                cells: tableCells(
                    from: sourceCells,
                    path: path + [1, index],
                    columnCount: columnCount
                )
            )
        }

        return FlatMarkRenderTable(header: header, rows: rows)
    }

    func tableCells(
        from sourceCells: [Table.Cell],
        path: [Int],
        columnCount: Int
    ) -> [FlatMarkRenderTable.Cell] {
        let cells = sourceCells.enumerated().map { index, cell in
            let colspan = Int(cell.colspan)
            let isSpanContinuation = colspan == 0 || Int(cell.rowspan) == 0
            return FlatMarkRenderTable.Cell(
                id: id(path: path + [index]),
                content: isSpanContinuation
                    ? FlatMarkRenderInlineContent()
                    : inlineContent(of: cell),
                colspan: colspan
            )
        }
        // Synthetic padding follows every real child under the same parent.
        let fillerCells = (cells.count ..< columnCount).map { index in
            FlatMarkRenderTable.Cell(
                id: id(path: path + [index]),
                content: FlatMarkRenderInlineContent(),
                colspan: 1
            )
        }

        return cells + fillerCells
    }

    func inlineContent(of markup: some Markup) -> FlatMarkRenderInlineContent {
        var projector = FlatMarkInlineAttributedStringProjector(
            source: source,
            baseURL: baseURL
        )

        return projector.project(markup)
    }

    /// Extracts literal text once, before render-time policy decisions.
    func unsupported(_ markup: any Markup) -> FlatMarkRenderUnsupportedContent {
        FlatMarkRenderUnsupportedContent(
            literalText: FlatMarkUnsupportedContentExtractor.literal(from: markup, source: source)
        )
    }

    /// Identity comes from the tree alone, so a missing parser range cannot abort projection.
    func id(path: [Int]) -> FlatMarkRenderNodeID {
        FlatMarkRenderNodeID(path: path)
    }
}
