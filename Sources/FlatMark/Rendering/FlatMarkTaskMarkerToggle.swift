// MARK: - FlatMarkTaskMarkerToggle

/// A narrow source-preserving operation for one current Markdown task marker.
enum FlatMarkTaskMarkerToggle {
    /// Returns the Markdown with the task addressed by `sourceRange` toggled, or nil when the
    /// operation cannot be performed safely.
    ///
    /// The coordinates are interpreted against `markdown`, the unchanged original snapshot from
    /// which they were projected. Only the selected marker's state byte is replaced; every other
    /// byte, including line terminators and Unicode, is left untouched. Stale addresses from
    /// previously projected documents are not supported.
    static func toggledMarkdown(in markdown: String, sourceRange: FlatMarkSourceRange) -> String? {
        guard let range = utf8Range(for: sourceRange, in: markdown),
              let markerOffset = markerOffset(in: markdown, range: range),
              let isChecked = Array(markdown.utf8)[markerOffset + 1].asciiTaskState
        else {
            return nil
        }

        var result = markdown
        let utf8Index = result.utf8.index(result.utf8.startIndex, offsetBy: markerOffset + 1)
        guard let stateIndex = String.Index(utf8Index, within: result) else {
            return nil
        }

        result.replaceSubrange(stateIndex ... stateIndex, with: isChecked ? " " : "x")
        return result
    }

    private static func utf8Range(
        for sourceRange: FlatMarkSourceRange,
        in markdown: String
    ) -> Range<Int>? {
        guard let lowerBound = utf8Offset(for: sourceRange.lowerBound, in: markdown),
              let upperBound = utf8Offset(for: sourceRange.upperBound, in: markdown),
              lowerBound <= upperBound
        else {
            return nil
        }

        return lowerBound ..< upperBound
    }

    /// Maps one semantic source location onto a UTF-8 byte offset within the
    /// unchanged original Markdown snapshot from which it was projected.
    ///
    /// Combines two authorities:
    /// - GFM "Characters and lines": line ends are LF, standalone CR, or CRLF,
    ///   with CRLF counted as one line ending.
    /// - swift-markdown `SourceLocation`: one-based lines, one-based columns
    ///   measured in UTF-8 bytes, and half-open source ranges.
    ///
    /// Returns nil for coordinates that do not exist in the snapshot: nonpositive
    /// lines or columns, nonexistent lines, and columns past a line's content
    /// length. A coordinate at the line's content end is accepted as a valid
    /// exclusive range endpoint.
    static func utf8Offset(
        for location: FlatMarkSourceRange.Location,
        in markdown: String
    ) -> Int? {
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

    private static func markerOffset(in markdown: String, range: Range<Int>) -> Int? {
        let bytes = Array(markdown.utf8)
        guard range.upperBound <= bytes.count else {
            return nil
        }

        var offset = range.lowerBound
        while offset + 2 < range.upperBound {
            if bytes[offset] == 91,
               bytes[offset + 1].asciiTaskState != nil,
               bytes[offset + 2] == 93
            {
                return offset
            }
            offset += 1
        }
        return nil
    }
}

private extension UInt8 {
    var asciiTaskState: Bool? {
        switch self {
        case 32:
            false
        case 88, 120:
            true
        default:
            nil
        }
    }
}
