import Foundation

// MARK: - FlatMarkDocument

/// An immutable Markdown snapshot with its parsed and projected content.
///
/// For live previews and long documents, retain one value and pass it to ``FlatMarkView``'s
/// `document:` initializer to render repeatedly without reparsing. Changing the source,
/// or base URL requires a new document.
///
/// Task toggles use this snapshot, not newer Markdown the host may hold.
public struct FlatMarkDocument: Equatable, Sendable {
    /// The Markdown source that was parsed, unchanged.
    public let markdown: String

    /// The base URL used to resolve relative links and images.
    public let baseURL: URL?

    /// The retained projection used by the renderer.
    let renderDocument: FlatMarkRenderDocument

    /// Parses and projects a Markdown snapshot.
    ///
    /// - Parameters:
    ///   - markdown: The source to parse once and retain unchanged.
    ///   - baseURL: Resolves relative links and images using Foundation's file/directory semantics.
    public init(markdown: String, baseURL: URL? = nil) {
        self.markdown = markdown
        self.baseURL = baseURL
        renderDocument = FlatMarkRenderProjector.project(
            markdown: markdown,
            baseURL: baseURL
        )
    }

    /// Compares exact source bytes and base URL, preserving byte-sensitive task snapshots.
    public static func == (lhs: FlatMarkDocument, rhs: FlatMarkDocument) -> Bool {
        lhs.baseURL == rhs.baseURL && lhs.markdown.utf8.elementsEqual(rhs.markdown.utf8)
    }
}
