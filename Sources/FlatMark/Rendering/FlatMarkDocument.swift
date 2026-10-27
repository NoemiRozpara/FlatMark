import Foundation

// MARK: - FlatMarkDocument

/// An immutable Markdown snapshot with its parsed and projected content.
///
/// For live previews and long documents, retain one value and pass it to ``FlatMarkView``'s
/// `document:` initializer to render repeatedly without reparsing. Changing the source,
/// base URL, or mention detection requires a new document.
///
/// Task toggles use this snapshot, not newer Markdown the host may hold.
public struct FlatMarkDocument: Equatable, Sendable {
    /// The Markdown source that was parsed, unchanged.
    public let markdown: String

    /// The base URL used to resolve relative links and images.
    public let baseURL: URL?

    /// Whether lexical `@username` tokens are rendered in bold.
    public let detectMentions: Bool

    /// The retained projection used by the renderer.
    let renderDocument: FlatMarkRenderDocument

    /// Parses and projects a Markdown snapshot.
    ///
    /// - Parameters:
    ///   - markdown: The source to parse once and retain unchanged.
    ///   - baseURL: Resolves relative links and images using Foundation's file/directory semantics.
    ///   - detectMentions: Whether to render lexical `@username` tokens in bold.
    public init(markdown: String, baseURL: URL? = nil, detectMentions: Bool = false) {
        self.markdown = markdown
        self.baseURL = baseURL
        self.detectMentions = detectMentions
        renderDocument = FlatMarkRenderProjector.project(
            markdown: markdown,
            baseURL: baseURL,
            detectMentions: detectMentions
        )
    }

    /// Compares source, base URL, and mention detection settings.
    public static func == (lhs: FlatMarkDocument, rhs: FlatMarkDocument) -> Bool {
        lhs.markdown == rhs.markdown && lhs.baseURL == rhs.baseURL && lhs.detectMentions == rhs.detectMentions
    }
}
