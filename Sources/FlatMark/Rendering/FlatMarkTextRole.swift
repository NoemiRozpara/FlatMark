import Foundation

/// The semantic typographic role one image-free inline span resolves its base font from.
///
/// A role carries system-resolved typography only; it never fixes a point size. Inline emphasis,
/// strong text, mentions, and inline code derive their traits from the resolved role font. Explicit
/// host font and color attributes stay authoritative on their own run. Image-bearing content keeps
/// the SwiftUI styling path instead of using a role.
enum FlatMarkTextRole: Equatable, Sendable {
    case body
    case heading(level: Int)
    case tableHeader

    /// Whether the role adds its own bold emphasis on top of inline intents.
    ///
    /// Headings and table headers keep the emphasis the SwiftUI path applied with `.bold()`.
    var includesBoldEmphasis: Bool {
        switch self {
        case .body:
            false
        case .heading, .tableHeader:
            true
        }
    }
}
