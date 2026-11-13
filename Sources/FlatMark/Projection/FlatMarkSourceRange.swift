import Markdown

// MARK: - FlatMarkSourceRange

/// Half-open coordinates of one region of a Markdown snapshot.
///
/// Coordinates follow the GFM line rules and swift-markdown's `SourceLocation`: lines and
/// columns are one-based, columns are measured in UTF-8 bytes, and the region spans
/// `lowerBound` inclusive to `upperBound` exclusive.
///
/// FlatMark uses these coordinates for two purposes: addressing one task marker's state byte
/// when the viewer toggles it, and slicing the exact source text of an unsupported node that
/// has no raw-HTML value of its own. They belong to the snapshot they were projected from, and
/// no other snapshot is addressed. A task marker the parser gave no coordinates to is rendered
/// as static content that no host callback can change.
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

// MARK: - Source coordinates

extension FlatMarkSourceRange {
    /// The exact text this range addresses in `markdown`, or `nil` when the coordinates do not
    /// address a usable region of that snapshot.
    ///
    /// An unusable range falls back to the caller instead of trapping, and never resolves to a
    /// different snapshot: coordinates are only meaningful for the string they were projected
    /// from. An offset that lands inside a UTF-8 sequence is rejected rather than repaired.
    func text(in markdown: String) -> String? {
        guard let start = Self.utf8Offset(for: lowerBound, in: markdown),
              let end = Self.utf8Offset(for: upperBound, in: markdown),
              start <= end
        else {
            return nil
        }

        let bytes = Array(markdown.utf8)
        guard isBoundary(bytes, at: start), isBoundary(bytes, at: end) else {
            return nil
        }

        return String(decoding: bytes[start ..< end], as: UTF8.self)
    }

    /// Maps one semantic source location onto a UTF-8 byte offset within the unchanged original
    /// Markdown snapshot from which it was projected.
    ///
    /// Combines two authorities:
    /// - GFM "Characters and lines": line ends are LF, standalone CR, or CRLF, with CRLF counted
    ///   as one line ending.
    /// - swift-markdown `SourceLocation`: one-based lines, one-based columns measured in UTF-8
    ///   bytes, and half-open source ranges.
    ///
    /// Returns nil for coordinates that do not exist in the snapshot: nonpositive lines or
    /// columns, nonexistent lines, and columns past a line's content length. A coordinate at the
    /// line's content end is accepted as a valid exclusive range endpoint.
    static func utf8Offset(for location: Location, in markdown: String) -> Int? {
        guard location.line > 0, location.column > 0 else {
            return nil
        }

        let bytes = Array(markdown.utf8)
        var line = 1
        var lineStart = 0
        var index = 0

        while index < bytes.count, line < location.line {
            if bytes[index] == 13 { // CR; with a following LF this is one CRLF line ending.
                if index + 1 < bytes.count, bytes[index + 1] == 10 {
                    index += 1
                }
            } else if bytes[index] != 10 { // Not LF; only the two terminator bytes advance lines.
                index += 1
                continue
            }
            line += 1
            lineStart = index + 1
            index += 1
        }

        guard line == location.line else {
            return nil
        }

        // A line beginning exactly at the snapshot's end is only the phantom line past a final terminator.
        guard lineStart < bytes.count || location.line == 1 else {
            return nil
        }

        // The line's content ends just before its first terminator byte, or at the snapshot's end.
        let lineEnd = bytes[lineStart...].firstIndex(where: { $0 == 13 || $0 == 10 }) ?? bytes.count
        guard location.column - 1 <= lineEnd - lineStart else {
            return nil
        }

        return lineStart + location.column - 1
    }

    /// Whether `offset` starts a UTF-8 code point rather than continuing one, treating the
    /// snapshot's own end as one.
    private func isBoundary(_ bytes: [UInt8], at offset: Int) -> Bool {
        offset == bytes.count || bytes[offset] & 0xC0 != 0x80
    }
}

extension FlatMarkSourceRange {
    init(_ sourceRange: Markdown.SourceRange) {
        self.init(
            lowerBound: .init(line: sourceRange.lowerBound.line, column: sourceRange.lowerBound.column),
            upperBound: .init(line: sourceRange.upperBound.line, column: sourceRange.upperBound.column)
        )
    }
}
