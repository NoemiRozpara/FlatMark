import Testing
@testable import FlatMark

struct TaskListMarkerToggleTests {
    @Test
    func `toggling nested task preserves all authored markdown except one marker state`() throws {
        let markdown = """
        # Plan ✅

        - [ ] Parent with ą Unicode
          - [x] Nested task
            continues on a second line with 你好.
        - [ ] Sibling  

        Keep  **this formatting** exactly.
        """
        let id = try #require(taskIDs(in: markdown).dropFirst().first)
        #expect(id.path == [1, 0, 1, 0])

        let updatedMarkdown = try #require(
            TaskListMarkerToggle.toggledMarkdown(in: markdown, id: id)
        )

        #expect(updatedMarkdown == markdown.replacingFirst("  - [x] Nested task", with: "  - [ ] Nested task"))
    }

    @Test
    func `task toggle accepts checked unchecked and uppercase markers and rejects invalid source positions`() {
        let unchecked = "- [ ] Pending"
        let checked = "- [x] Done"
        let uppercase = "- [X] Also done"

        #expect(toggledMarkdown(in: unchecked) == "- [x] Pending")
        #expect(toggledMarkdown(in: checked) == "- [ ] Done")
        #expect(toggledMarkdown(in: uppercase) == "- [ ] Also done")

        let invalidID = FlatMarkRenderNodeID(
            path: [99],
            sourceRange: .init(
                lowerBound: .init(line: 99, column: 1),
                upperBound: .init(line: 99, column: 2)
            )
        )
        #expect(TaskListMarkerToggle.toggledMarkdown(in: unchecked, id: invalidID) == nil)
    }
}

private func taskIDs(in markdown: String) -> [FlatMarkRenderNodeID] {
    FlatMarkRenderProjector.project(markdown: markdown).blocks.flatMap(taskIDs(in:))
}

private func toggledMarkdown(in markdown: String) -> String? {
    guard let id = taskIDs(in: markdown).first else {
        return nil
    }

    return TaskListMarkerToggle.toggledMarkdown(in: markdown, id: id)
}

private func taskIDs(in block: FlatMarkRenderBlock) -> [FlatMarkRenderNodeID] {
    switch block.kind {
    case let .blockQuote(blocks):
        blocks.flatMap(taskIDs(in:))
    case let .list(entries):
        entries.flatMap { entry -> [FlatMarkRenderNodeID] in
            switch entry {
            case let .row(row):
                if case .task = row.marker {
                    [row.id]
                } else {
                    []
                }
            case let .childBlock(childBlock):
                taskIDs(in: childBlock.block)
            }
        }
    default:
        []
    }
}

private extension String {
    func replacingFirst(_ old: String, with new: String) -> String {
        replacingOccurrences(of: old, with: new, options: [], range: range(of: old))
    }
}
