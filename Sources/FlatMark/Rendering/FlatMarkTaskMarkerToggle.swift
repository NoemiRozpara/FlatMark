// MARK: - FlatMarkTaskMarkerToggle

/// A narrow source-preserving operation for one current Markdown task marker.
enum FlatMarkTaskMarkerToggle {
    /// Returns the Markdown with the task addressed by `sourceRange` toggled, or nil when the
    /// coordinates cannot be mapped or no supported marker is found in the range.
    ///
    /// Requires `sourceRange` to have been projected from the unchanged `markdown` snapshot.
    /// Snapshot freshness is not validated: applying a stale range to different Markdown can
    /// toggle an unrelated marker rather than return nil. FlatMarkView keeps the range and source
    /// paired by projecting the same immutable Markdown value captured by its toggle action.
    ///
    /// Only the selected marker's state byte is replaced; every other byte, including line
    /// terminators and Unicode, is left untouched.
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
        guard let lowerBound = FlatMarkSourceRange.utf8Offset(for: sourceRange.lowerBound, in: markdown),
              let upperBound = FlatMarkSourceRange.utf8Offset(for: sourceRange.upperBound, in: markdown),
              lowerBound <= upperBound
        else {
            return nil
        }

        return lowerBound ..< upperBound
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
