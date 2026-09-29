import Foundation
import Markdown

// MARK: - FlatMarkRenderDocument

/// Value-only input for the native Markdown renderer.
struct FlatMarkRenderDocument: Equatable, Sendable {
    let blocks: [FlatMarkRenderBlock]
}

// MARK: - FlatMarkRenderBlock

struct FlatMarkRenderBlock: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case paragraph(AttributedString)
        case heading(level: Int, content: AttributedString)
        case codeBlock(String)
        case blockQuote([FlatMarkRenderBlock])
        case list([FlatMarkListRenderEntry])
        case thematicBreak
        case table(FlatMarkRenderTable)
        case fallback(type: String, content: AttributedString)
    }

    let id: FlatMarkRenderNodeID
    let kind: Kind
}

// MARK: - FlatMarkRenderTable

/// A rectangular, renderer-only table projection.
struct FlatMarkRenderTable: Equatable, Sendable {
    struct Row: Identifiable, Equatable, Sendable {
        let id: String
        let cells: [Cell]
    }

    struct Cell: Identifiable, Equatable, Sendable {
        let id: String
        let content: AttributedString
        let colspan: Int
    }

    let header: [Cell]
    let rows: [Row]
}

// MARK: - FlatMarkListMarker

enum FlatMarkListMarker: Equatable, Sendable {
    case unordered
    case ordered(index: Int)
    case task(isChecked: Bool)
}

// MARK: - FlatMarkListRenderRow

/// A flattened list item identified by its parsed location in the Markdown source.
struct FlatMarkListRenderRow: Identifiable, Equatable, Sendable {
    let id: FlatMarkRenderNodeID
    let indentation: Int
    let marker: FlatMarkListMarker
    let content: AttributedString
}

// MARK: - FlatMarkListRenderEntry

/// An ordered list rendering event. Nested rows remain siblings in this flat sequence.
enum FlatMarkListRenderEntry: Identifiable, Equatable, Sendable {
    case row(FlatMarkListRenderRow)
    case childBlock(FlatMarkListChildRenderBlock)

    var id: FlatMarkRenderNodeID {
        switch self {
        case let .row(row):
            row.id
        case let .childBlock(childBlock):
            childBlock.block.id
        }
    }
}

// MARK: - FlatMarkListChildRenderBlock

struct FlatMarkListChildRenderBlock: Equatable, Sendable {
    let indentation: Int
    let block: FlatMarkRenderBlock
}

// MARK: - FlatMarkRenderProjector

enum FlatMarkRenderProjector {
    static func project(markdown: String) -> FlatMarkRenderDocument {
        let document = Document(parsing: markdown, options: [.parseBlockDirectives])
        return FlatMarkRenderDocument(
            blocks: projectChildren(of: document, path: [], indentation: 0)
        )
    }
}

private extension FlatMarkRenderProjector {
    static func projectChildren(
        of markup: some Markup,
        path: [Int],
        indentation: Int
    ) -> [FlatMarkRenderBlock] {
        markup.children.enumerated().map { index, child in
            project(child, path: path + [index], indentation: indentation)
        }
    }

    static func project(
        _ markup: any Markup,
        path: [Int],
        indentation: Int
    ) -> FlatMarkRenderBlock {
        let id = id(for: markup, path: path)
        let structuralID = path.map(String.init).joined(separator: ".")

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
                kind: .blockQuote(projectChildren(of: blockQuote, path: path, indentation: indentation))
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
                kind: .table(tableProjection(from: table, id: structuralID))
            )

        case let htmlBlock as HTMLBlock:
            return FlatMarkRenderBlock(
                id: id,
                kind: .fallback(type: nodeType(of: htmlBlock), content: htmlFallbackContent(for: htmlBlock))
            )

        default:
            return FlatMarkRenderBlock(
                id: id,
                kind: .fallback(type: nodeType(of: markup), content: fallbackContent(for: markup))
            )
        }
    }

    static func listBlock(
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
            id: id(for: list, path: path),
            kind: .list(rows)
        )
    }

    static func listRows(
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
                id: id(for: item, path: itemPath),
                indentation: indentation,
                marker: marker,
                content: firstParagraphContent(of: item) ?? AttributedString()
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

    static func listItemEntries(
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

    static func listMarker(for item: ListItem, orderedIndex: Int?) -> FlatMarkListMarker {
        switch item.checkbox {
        case .checked:
            .task(isChecked: true)
        case .unchecked:
            .task(isChecked: false)
        case nil:
            orderedIndex.map(FlatMarkListMarker.ordered) ?? .unordered
        }
    }

    static func firstParagraphContent(of item: ListItem) -> AttributedString? {
        guard let paragraph = item.child(at: 0) as? Paragraph else {
            return nil
        }

        return inlineContent(of: paragraph)
    }

    static func tableProjection(from table: Table, id: String) -> FlatMarkRenderTable {
        let sourceHeader = Array(table.head.cells)
        let sourceRows = table.body.rows.map { Array($0.cells) }
        let columnCount = ([sourceHeader.count] + sourceRows.map(\.count)).max() ?? 0
        let header = tableCells(
            from: sourceHeader,
            idPrefix: "\(id).header",
            columnCount: columnCount
        )
        let rows = sourceRows.enumerated().map { index, sourceCells in
            FlatMarkRenderTable.Row(
                id: "\(id).row.\(index)",
                cells: tableCells(
                    from: sourceCells,
                    idPrefix: "\(id).row.\(index)",
                    columnCount: columnCount
                )
            )
        }

        return FlatMarkRenderTable(header: header, rows: rows)
    }

    static func tableCells(
        from sourceCells: [Table.Cell],
        idPrefix: String,
        columnCount: Int
    ) -> [FlatMarkRenderTable.Cell] {
        let cells = sourceCells.enumerated().map { index, cell in
            let colspan = Int(cell.colspan)
            let isSpanContinuation = colspan == 0 || Int(cell.rowspan) == 0
            return FlatMarkRenderTable.Cell(
                id: "\(idPrefix).cell.\(index)",
                content: isSpanContinuation ? AttributedString() : inlineContent(of: cell),
                colspan: colspan
            )
        }
        let fillerCells = (cells.count ..< columnCount).map { index in
            FlatMarkRenderTable.Cell(
                id: "\(idPrefix).cell.\(index)",
                content: AttributedString(),
                colspan: 1
            )
        }

        return cells + fillerCells
    }

    static func inlineContent(of markup: some Markup) -> AttributedString {
        var projector = FlatMarkInlineAttributedStringProjector()
        return projector.project(markup)
    }

    static func readableText(of markup: any Markup) -> String {
        switch markup {
        case let text as Text:
            text.string
        case let inlineCode as InlineCode:
            inlineCode.code
        case let html as InlineHTML:
            html.rawHTML
        case is SoftBreak, is LineBreak:
            "\n"
        default:
            markup.children.map(readableText).joined()
        }
    }

    static func fallbackContent(for markup: any Markup) -> AttributedString {
        let content = readableText(of: markup)
        return AttributedString(content.isEmpty ? "[\(nodeType(of: markup))]" : content)
    }

    static func htmlFallbackContent(for htmlBlock: HTMLBlock) -> AttributedString {
        let content = htmlBlock.rawHTML
        return AttributedString(content.isEmpty ? "[HTMLBlock]" : content)
    }

    static func nodeType(of markup: any Markup) -> String {
        String(describing: type(of: markup))
    }

    static func id(for markup: some Markup, path: [Int]) -> FlatMarkRenderNodeID {
        guard let sourceRange = markup.range else {
            preconditionFailure("Parsed Markdown elements must have source ranges.")
        }

        return FlatMarkRenderNodeID(path: path, sourceRange: sourceRange)
    }
}

private extension FlatMarkRenderNodeID {
    init(path: [Int], sourceRange: Markdown.SourceRange) {
        self.init(
            path: path,
            sourceRange: SourceRange(
                lowerBound: .init(line: sourceRange.lowerBound.line, column: sourceRange.lowerBound.column),
                upperBound: .init(line: sourceRange.upperBound.line, column: sourceRange.upperBound.column)
            )
        )
    }
}
