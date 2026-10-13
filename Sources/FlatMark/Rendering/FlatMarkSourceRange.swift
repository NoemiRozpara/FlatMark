// MARK: - FlatMarkSourceRange

/// Half-open coordinates of one region of a Markdown snapshot.
///
/// Coordinates follow the GFM line rules and swift-markdown's `SourceLocation`: lines and
/// columns are one-based, columns are measured in UTF-8 bytes, and the region spans
/// `lowerBound` inclusive to `upperBound` exclusive.
///
/// FlatMark uses these coordinates for exactly one purpose: addressing one task marker's
/// state byte when the viewer toggles it. They belong to the snapshot the marker was projected
/// from, and no other snapshot is addressed. A task marker the parser gave no coordinates to
/// is rendered as static content that no host callback can change.
struct FlatMarkSourceRange: Equatable, Sendable {
    struct Location: Equatable, Sendable {
        /// One-based line number.
        let line: Int
        /// One-based column, measured in UTF-8 bytes.
        let column: Int
    }

    /// Inclusive start of the region.
    let lowerBound: Location
    /// Exclusive end of the region.
    let upperBound: Location
}
