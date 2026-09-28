/// The parsed-tree and source-text position of a rendered Markdown element.
struct TodoMarkdownSemanticID: Hashable, Sendable {
    struct SourceRange: Hashable, Sendable {
        struct Location: Hashable, Sendable {
            let line: Int
            let column: Int
        }

        let lowerBound: Location
        let upperBound: Location
    }

    let path: [Int]
    let sourceRange: SourceRange
}
