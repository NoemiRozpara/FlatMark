import Foundation
import Markdown

// MARK: - FlatMarkRenderDocument

/// Value-only input for the native Markdown renderer.
struct FlatMarkRenderDocument: Equatable, Sendable {
    let blocks: [FlatMarkRenderBlock]
}

// MARK: - FlatMarkRenderImage

struct FlatMarkRenderImage: Equatable, Sendable {
    let url: URL?
    /// Keep description nodes until presentation so unsupported wording follows the host policy.
    let altContent: FlatMarkRenderInlineContent
    let link: URL?

    init(url: URL?, altContent: FlatMarkRenderInlineContent, link: URL? = nil) {
        self.url = url
        self.altContent = altContent
        self.link = link
    }

    init(url: URL?, altText: String, link: URL? = nil) {
        self.init(url: url, altContent: FlatMarkRenderInlineContent(text: AttributedString(altText)), link: link)
    }
}

// MARK: - FlatMarkRenderInlineContent

struct FlatMarkRenderInlineContent: Equatable, Sendable, ExpressibleByStringLiteral {
    enum Component: Equatable, Sendable {
        case text(AttributedString)
        case image(FlatMarkRenderImage)
        case unsupported(FlatMarkRenderUnsupportedContent)

        /// `true` for the content this renderer has no native view for.
        var isUnsupported: Bool {
            if case .unsupported = self {
                return true
            }

            return false
        }
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

    /// The literal plain text, with every unsupported node contributing its own extracted text.
    var plainText: String {
        Self.plainText(of: components) { $0.literalText }
    }

    /// The plain text of one component list, with unsupported nodes resolved by `unsupportedText`.
    static func plainText(
        of components: [Component],
        unsupportedText: (FlatMarkRenderUnsupportedContent) -> AttributedString
    ) -> String {
        components.map { component -> String in
            switch component {
            case let .text(text):
                return String(text.characters)
            case let .image(image):
                let altText = Self.plainText(of: image.altContent.components, unsupportedText: unsupportedText)
                return altText.isEmpty ? "Image" : altText
            case let .unsupported(unsupported):
                return String(unsupportedText(unsupported).characters)
            }
        }
        .joined()
    }

    /// Whether omission leaves this span with nothing to present.
    ///
    /// `true` only when every component is content the renderer has no native view for, so a
    /// supported space, break, or image is still content and a span that was already empty is not
    /// an emptied shell.
    var isEmptiedByOmission: Bool {
        !components.isEmpty && components.allSatisfy(\.isUnsupported)
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
                    altContent: image.altContent,
                    link: url
                ))
            case let .unsupported(unsupported):
                var linked = unsupported
                linked.literalText.link = url
                return .unsupported(linked)
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
                return .text(transform(text))
            case .image:
                return component
            case var .unsupported(unsupported):
                unsupported.literalText = transform(unsupported.literalText)
                return .unsupported(unsupported)
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
        case unsupported(FlatMarkRenderUnsupportedContent)
    }

    let id: FlatMarkRenderNodeID
    let kind: Kind
}

// MARK: - FlatMarkRenderTable

/// A rectangular, renderer-only table projection.
struct FlatMarkRenderTable: Equatable, Sendable {
    struct Row: Identifiable, Equatable, Sendable {
        let id: FlatMarkRenderNodeID
        let cells: [Cell]
    }

    struct Cell: Identifiable, Equatable, Sendable {
        let id: FlatMarkRenderNodeID
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

    /// A GFM task marker and the editing address of its state byte, or `nil` when the parser
    /// gave this item no source coordinates and the row can only be static content.
    case task(isChecked: Bool, sourceRange: FlatMarkSourceRange?)
}

// MARK: - FlatMarkListRenderRow

/// A flattened list item identified by its position in the parsed tree.
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

/// Projects the block values of one Markdown snapshot.
///
/// The snapshot and the base address are read-only state that every destination and every
/// unsupported-content extraction needs, so the projector holds them instead of threading
/// them through each call.
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

    /// The one extraction result every presentation policy of this node will show.
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
