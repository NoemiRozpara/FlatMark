import Foundation

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
