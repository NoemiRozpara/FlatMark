// MARK: - TodoMarkdownTaskToggleOperation

/// A narrow source-preserving operation for one current Markdown task marker.
enum TodoMarkdownTaskToggleOperation {
    static func toggledMarkdown(in markdown: String, id: TodoMarkdownSemanticID) -> String? {
        guard let range = utf8Range(for: id.sourceRange, in: markdown),
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
        for sourceRange: TodoMarkdownSemanticID.SourceRange,
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

    /// Semantic locations use swift-markdown's one-based lines and UTF-8 columns.
    private static func utf8Offset(
        for location: TodoMarkdownSemanticID.SourceRange.Location,
        in markdown: String
    ) -> Int? {
        guard location.line > 0, location.column > 0 else {
            return nil
        }

        let bytes = Array(markdown.utf8)
        var line = 1
        var lineStart = 0
        var lineEnd = bytes.count

        for index in bytes.indices {
            guard line < location.line else {
                break
            }

            if bytes[index] == 10 {
                line += 1
                lineStart = index + 1
            }
        }

        guard line == location.line else {
            return nil
        }

        if let newline = bytes[lineStart...].firstIndex(of: 10) {
            lineEnd = newline
        }

        let offset = lineStart + location.column - 1
        guard offset <= lineEnd else {
            return nil
        }

        return offset
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
