import Foundation
import Markdown

// MARK: - FlatMarkRenderDocument

/// Value-only input for the native Markdown renderer.
struct FlatMarkRenderDocument: Equatable, Sendable {
    let blocks: [FlatMarkRenderBlock]
}

// MARK: - FlatMarkRenderInlineContent

struct FlatMarkRenderImage: Equatable, Sendable {
    let url: URL?
    let altText: String
    let link: URL?

    init(url: URL?, altText: String, link: URL? = nil) {
        self.url = url
        self.altText = altText
        self.link = link
    }

    var accessibleLabel: String {
        altText.isEmpty ? "Image" : altText
    }
}

struct FlatMarkRenderInlineContent: Equatable, Sendable, ExpressibleByStringLiteral {
    enum Component: Equatable, Sendable {
        case text(AttributedString)
        case image(FlatMarkRenderImage)
    }

    private(set) var components: [Component] = []

    init() {}

    init(components: [Component]) {
        self.components = components
    }

    init(text: AttributedString) {
        components = text.characters.isEmpty ? [] : [.text(text)]
    }

    init(stringLiteral value: String) {
        self.init(text: AttributedString(value))
    }

    var plainText: String {
        components.map { component in
            switch component {
            case let .text(text):
                String(text.characters)
            case let .image(image):
                image.accessibleLabel
            }
        }.joined()
    }

    var standaloneLinkedImageDestination: URL? {
        guard components.count == 1,
              case let .image(image) = components[0]
        else {
            return nil
        }

        return image.link
    }

    mutating func append(contentsOf other: Self) {
        for component in other.components {
            if case let .text(text) = component,
               case let .text(previous)? = components.last
            {
                components[components.count - 1] = .text(previous + text)
            } else {
                components.append(component)
            }
        }
    }

    mutating func applyLink(_ url: URL) {
        components = components.map { component in
            switch component {
            case let .text(text):
                var linked = text
                linked.link = url
                return .text(linked)
            case let .image(image):
                return .image(FlatMarkRenderImage(
                    url: image.url,
                    altText: image.altText,
                    link: url
                ))
            }
        }
    }

    mutating func applyPresentationIntent(_ intent: InlinePresentationIntent) {
        transformText { text in
            var styled = text
            for run in styled.runs {
                let existingIntent = styled[run.range].inlinePresentationIntent ?? []
                styled[run.range].inlinePresentationIntent = existingIntent.union(intent)
            }
            return styled
        }
    }

    private mutating func transformText(
        _ transform: (AttributedString) -> AttributedString
    ) {
        components = components.map { component in
            switch component {
            case let .text(text):
                .text(transform(text))
            case .image:
                component
            }
        }
    }
}

// MARK: - FlatMarkRenderBlock

struct FlatMarkRenderBlock: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case paragraph(FlatMarkRenderInlineContent)
        case heading(level: Int, content: FlatMarkRenderInlineContent)
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
        let content: FlatMarkRenderInlineContent
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
    let content: FlatMarkRenderInlineContent
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
    static func project(markdown: String, baseURL: URL? = nil) -> FlatMarkRenderDocument {
        let document = Document(parsing: markdown)
        return FlatMarkRenderDocument(
            blocks: projectChildren(of: document, path: [], indentation: 0, baseURL: baseURL)
        )
    }
}

private extension FlatMarkRenderProjector {
    static func projectChildren(
        of markup: some Markup,
        path: [Int],
        indentation: Int,
        baseURL: URL?
    ) -> [FlatMarkRenderBlock] {
        markup.children.enumerated().map { index, child in
            project(child, path: path + [index], indentation: indentation, baseURL: baseURL)
        }
    }

    static func project(
        _ markup: any Markup,
        path: [Int],
        indentation: Int,
        baseURL: URL?
    ) -> FlatMarkRenderBlock {
        let id = id(for: markup, path: path)
        let structuralID = path.map(String.init).joined(separator: ".")

        switch markup {
        case let paragraph as Paragraph:
            return FlatMarkRenderBlock(
                id: id,
                kind: .paragraph(inlineContent(of: paragraph, baseURL: baseURL))
            )

        case let heading as Heading:
            return FlatMarkRenderBlock(
                id: id,
                kind: .heading(level: heading.level, content: inlineContent(of: heading, baseURL: baseURL))
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
                    indentation: indentation,
                    baseURL: baseURL
                ))
            )

        case let orderedList as OrderedList:
            return listBlock(
                orderedList,
                startIndex: Int(orderedList.startIndex),
                path: path,
                indentation: indentation,
                baseURL: baseURL
            )

        case let unorderedList as UnorderedList:
            return listBlock(
                unorderedList,
                startIndex: nil,
                path: path,
                indentation: indentation,
                baseURL: baseURL
            )

        case is ThematicBreak:
            return FlatMarkRenderBlock(
                id: id,
                kind: .thematicBreak
            )

        case let table as Table:
            return FlatMarkRenderBlock(
                id: id,
                kind: .table(tableProjection(from: table, id: structuralID, baseURL: baseURL))
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
        indentation: Int,
        baseURL: URL?
    ) -> FlatMarkRenderBlock {
        let rows = listRows(
            from: list,
            startIndex: startIndex,
            path: path,
            indentation: indentation,
            baseURL: baseURL
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
        indentation: Int,
        baseURL: URL?
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
                content: firstParagraphContent(of: item, baseURL: baseURL) ?? FlatMarkRenderInlineContent()
            )
            let children = item.children.enumerated().flatMap { childIndex, child in
                listItemEntries(
                    from: child,
                    at: childIndex,
                    itemPath: itemPath,
                    indentation: indentation + 1,
                    baseURL: baseURL
                )
            }

            return [.row(row)] + children
        }
    }

    static func listItemEntries(
        from markup: any Markup,
        at index: Int,
        itemPath: [Int],
        indentation: Int,
        baseURL: URL?
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
                indentation: indentation,
                baseURL: baseURL
            )

        case let unorderedList as UnorderedList:
            listRows(
                from: unorderedList,
                startIndex: nil,
                path: path,
                indentation: indentation,
                baseURL: baseURL
            )

        default:
            [
                FlatMarkListRenderEntry.childBlock(
                    FlatMarkListChildRenderBlock(
                        indentation: indentation,
                        block: project(markup, path: path, indentation: indentation, baseURL: baseURL)
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

    static func firstParagraphContent(
        of item: ListItem,
        baseURL: URL?
    ) -> FlatMarkRenderInlineContent? {
        guard let paragraph = item.child(at: 0) as? Paragraph else {
            return nil
        }

        return inlineContent(of: paragraph, baseURL: baseURL)
    }

    static func tableProjection(
        from table: Table,
        id: String,
        baseURL: URL?
    ) -> FlatMarkRenderTable {
        let sourceHeader = Array(table.head.cells)
        let sourceRows = table.body.rows.map { Array($0.cells) }
        let columnCount = ([sourceHeader.count] + sourceRows.map(\.count)).max() ?? 0
        let header = tableCells(
            from: sourceHeader,
            idPrefix: "\(id).header",
            columnCount: columnCount,
            baseURL: baseURL
        )
        let rows = sourceRows.enumerated().map { index, sourceCells in
            FlatMarkRenderTable.Row(
                id: "\(id).row.\(index)",
                cells: tableCells(
                    from: sourceCells,
                    idPrefix: "\(id).row.\(index)",
                    columnCount: columnCount,
                    baseURL: baseURL
                )
            )
        }

        return FlatMarkRenderTable(header: header, rows: rows)
    }

    static func tableCells(
        from sourceCells: [Table.Cell],
        idPrefix: String,
        columnCount: Int,
        baseURL: URL?
    ) -> [FlatMarkRenderTable.Cell] {
        let cells = sourceCells.enumerated().map { index, cell in
            let colspan = Int(cell.colspan)
            let isSpanContinuation = colspan == 0 || Int(cell.rowspan) == 0
            return FlatMarkRenderTable.Cell(
                id: "\(idPrefix).cell.\(index)",
                content: isSpanContinuation
                    ? FlatMarkRenderInlineContent()
                    : inlineContent(of: cell, baseURL: baseURL),
                colspan: colspan
            )
        }
        let fillerCells = (cells.count ..< columnCount).map { index in
            FlatMarkRenderTable.Cell(
                id: "\(idPrefix).cell.\(index)",
                content: FlatMarkRenderInlineContent(),
                colspan: 1
            )
        }

        return cells + fillerCells
    }

    static func inlineContent(
        of markup: some Markup,
        baseURL: URL?
    ) -> FlatMarkRenderInlineContent {
        var projector = FlatMarkInlineAttributedStringProjector(baseURL: baseURL)
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
