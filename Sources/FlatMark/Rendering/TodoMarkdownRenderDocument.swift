import Foundation
import Markdown

// MARK: - TodoMarkdownRenderDocument

/// Value-only input for the native Markdown renderer.
struct TodoMarkdownRenderDocument: Equatable, Sendable {
    let blocks: [TodoMarkdownRenderBlock]
}

// MARK: - TodoMarkdownRenderBlock

struct TodoMarkdownRenderBlock: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case paragraph(AttributedString)
        case heading(level: Int, content: AttributedString)
        case code(String)
        case blockQuote([TodoMarkdownRenderBlock])
        case list([TodoMarkdownListEntry])
        case thematicBreak
        case table(TodoMarkdownTable)
        case unsupported(type: String, content: AttributedString)
    }

    let id: TodoMarkdownSemanticID
    let kind: Kind
}

// MARK: - TodoMarkdownTable

/// A rectangular, renderer-only table projection.
struct TodoMarkdownTable: Equatable, Sendable {
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

// MARK: - TodoMarkdownListMarker

enum TodoMarkdownListMarker: Equatable, Sendable {
    case unordered
    case ordered(index: Int)
    case task(isChecked: Bool)
}

// MARK: - TodoMarkdownListRow

/// A flattened list item identified by its parsed location in the Markdown source.
struct TodoMarkdownListRow: Identifiable, Equatable, Sendable {
    let id: TodoMarkdownSemanticID
    let indentation: Int
    let marker: TodoMarkdownListMarker
    let content: AttributedString
}

// MARK: - TodoMarkdownListEntry

/// An ordered list rendering event. Nested rows remain siblings in this flat sequence.
enum TodoMarkdownListEntry: Identifiable, Equatable, Sendable {
    case row(TodoMarkdownListRow)
    case childBlock(TodoMarkdownListChildBlock)

    var id: TodoMarkdownSemanticID {
        switch self {
        case let .row(row):
            row.id
        case let .childBlock(childBlock):
            childBlock.block.id
        }
    }
}

// MARK: - TodoMarkdownListChildBlock

struct TodoMarkdownListChildBlock: Equatable, Sendable {
    let indentation: Int
    let block: TodoMarkdownRenderBlock
}

// MARK: - TodoMarkdownProjector

enum TodoMarkdownProjector {
    static func project(markdown: String) -> TodoMarkdownRenderDocument {
        let document = Document(parsing: markdown, options: [.parseBlockDirectives])
        return TodoMarkdownRenderDocument(
            blocks: projectChildren(of: document, path: [], indentation: 0)
        )
    }
}

private extension TodoMarkdownProjector {
    static func projectChildren(
        of markup: some Markup,
        path: [Int],
        indentation: Int
    ) -> [TodoMarkdownRenderBlock] {
        markup.children.enumerated().map { index, child in
            project(child, path: path + [index], indentation: indentation)
        }
    }

    static func project(
        _ markup: any Markup,
        path: [Int],
        indentation: Int
    ) -> TodoMarkdownRenderBlock {
        let id = id(for: markup, path: path)
        let structuralID = path.map(String.init).joined(separator: ".")

        switch markup {
        case let paragraph as Paragraph:
            return TodoMarkdownRenderBlock(
                id: id,
                kind: .paragraph(inlineContent(of: paragraph))
            )

        case let heading as Heading:
            return TodoMarkdownRenderBlock(
                id: id,
                kind: .heading(level: heading.level, content: inlineContent(of: heading))
            )

        case let codeBlock as CodeBlock:
            return TodoMarkdownRenderBlock(
                id: id,
                kind: .code(codeBlock.code)
            )

        case let blockQuote as BlockQuote:
            return TodoMarkdownRenderBlock(
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
            return TodoMarkdownRenderBlock(
                id: id,
                kind: .thematicBreak
            )

        case let table as Table:
            return TodoMarkdownRenderBlock(
                id: id,
                kind: .table(tableProjection(from: table, id: structuralID))
            )

        case let htmlBlock as HTMLBlock:
            return TodoMarkdownRenderBlock(
                id: id,
                kind: .unsupported(type: nodeType(of: htmlBlock), content: htmlFallbackContent(for: htmlBlock))
            )

        default:
            return TodoMarkdownRenderBlock(
                id: id,
                kind: .unsupported(type: nodeType(of: markup), content: fallbackContent(for: markup))
            )
        }
    }

    static func listBlock(
        _ list: some Markup,
        startIndex: Int?,
        path: [Int],
        indentation: Int
    ) -> TodoMarkdownRenderBlock {
        let rows = listRows(
            from: list,
            startIndex: startIndex,
            path: path,
            indentation: indentation
        )

        return TodoMarkdownRenderBlock(
            id: id(for: list, path: path),
            kind: .list(rows)
        )
    }

    static func listRows(
        from list: some Markup,
        startIndex: Int?,
        path: [Int],
        indentation: Int
    ) -> [TodoMarkdownListEntry] {
        list.children.enumerated().flatMap { index, child -> [TodoMarkdownListEntry] in
            guard let item = child as? ListItem else {
                return []
            }

            let itemPath = path + [index]
            let marker = marker(for: item, orderedIndex: startIndex.map { $0 + index })
            let row = TodoMarkdownListRow(
                id: id(for: item, path: itemPath),
                indentation: indentation,
                marker: marker,
                content: primaryContent(of: item) ?? AttributedString()
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
    ) -> [TodoMarkdownListEntry] {
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
                TodoMarkdownListEntry.childBlock(
                    TodoMarkdownListChildBlock(
                        indentation: indentation,
                        block: project(markup, path: path, indentation: indentation)
                    )
                ),
            ]
        }
    }

    static func marker(for item: ListItem, orderedIndex: Int?) -> TodoMarkdownListMarker {
        switch item.checkbox {
        case .checked:
            .task(isChecked: true)
        case .unchecked:
            .task(isChecked: false)
        case nil:
            orderedIndex.map(TodoMarkdownListMarker.ordered) ?? .unordered
        }
    }

    static func primaryContent(of item: ListItem) -> AttributedString? {
        guard let paragraph = item.child(at: 0) as? Paragraph else {
            return nil
        }

        return inlineContent(of: paragraph)
    }

    static func tableProjection(from table: Table, id: String) -> TodoMarkdownTable {
        let sourceHeader = Array(table.head.cells)
        let sourceRows = table.body.rows.map { Array($0.cells) }
        let columnCount = ([sourceHeader.count] + sourceRows.map(\.count)).max() ?? 0
        let header = tableCells(
            from: sourceHeader,
            idPrefix: "\(id).header",
            columnCount: columnCount
        )
        let rows = sourceRows.enumerated().map { index, sourceCells in
            TodoMarkdownTable.Row(
                id: "\(id).row.\(index)",
                cells: tableCells(
                    from: sourceCells,
                    idPrefix: "\(id).row.\(index)",
                    columnCount: columnCount
                )
            )
        }

        return TodoMarkdownTable(header: header, rows: rows)
    }

    static func tableCells(
        from sourceCells: [Table.Cell],
        idPrefix: String,
        columnCount: Int
    ) -> [TodoMarkdownTable.Cell] {
        let cells = sourceCells.enumerated().map { index, cell in
            let colspan = Int(cell.colspan)
            let isSpanContinuation = colspan == 0 || Int(cell.rowspan) == 0
            return TodoMarkdownTable.Cell(
                id: "\(idPrefix).cell.\(index)",
                content: isSpanContinuation ? AttributedString() : inlineContent(of: cell),
                colspan: colspan
            )
        }
        let fillerCells = (cells.count ..< columnCount).map { index in
            TodoMarkdownTable.Cell(
                id: "\(idPrefix).cell.\(index)",
                content: AttributedString(),
                colspan: 1
            )
        }

        return cells + fillerCells
    }

    static func inlineContent(of markup: some Markup) -> AttributedString {
        var projector = TodoMarkdownInlineProjector()
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

    static func id(for markup: some Markup, path: [Int]) -> TodoMarkdownSemanticID {
        guard let sourceRange = markup.range else {
            preconditionFailure("Parsed Markdown elements must have source ranges.")
        }

        return TodoMarkdownSemanticID(path: path, sourceRange: sourceRange)
    }
}

private extension TodoMarkdownSemanticID {
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
