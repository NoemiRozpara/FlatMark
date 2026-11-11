import Foundation

/// The semantic typographic role one inline span resolves its base font from.
///
/// A role carries system-resolved typography only; it never fixes a point size. Every span the
/// native paragraph path composes gets a role, including inline images in every phase. Inline
/// emphasis, strong text, mentions, and inline code derive their traits from the resolved role
/// font. Explicit host font and color attributes stay authoritative on their own run.
enum FlatMarkTextRole: Equatable, Sendable {
    case body
    case heading(level: Int)
    case tableHeader

    /// Whether the role adds its own bold emphasis on top of inline intents.
    ///
    /// Headings and table headers resolve a bold base font, and inline code in those roles keeps
    /// that bold weight.
    var includesBoldEmphasis: Bool {
        switch self {
        case .body:
            false
        case .heading, .tableHeader:
            true
        }
    }
}
