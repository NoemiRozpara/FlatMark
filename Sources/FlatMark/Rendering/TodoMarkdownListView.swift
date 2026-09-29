import SwiftUI

// MARK: - MarkdownListContentAlignment

private enum MarkdownListContentAlignment: AlignmentID {
    static func defaultValue(in dimensions: ViewDimensions) -> CGFloat {
        dimensions[.leading]
    }
}

private extension HorizontalAlignment {
    static let markdownListContent = HorizontalAlignment(MarkdownListContentAlignment.self)
}

private extension View {
    func markdownListIndentation(
        _ indentation: Int,
        spacing: CGFloat,
        layoutDirection: LayoutDirection
    ) -> some View {
        let offset = CGFloat(indentation) * spacing
        let directionalOffset = layoutDirection == .leftToRight ? -offset : offset

        return alignmentGuide(.markdownListContent) { dimensions in
            dimensions[.markdownListContent] + directionalOffset
        }
    }
}

// MARK: - FlatMarkListView

struct FlatMarkListView: View {
    let entries: [FlatMarkListRenderEntry]
    var taskToggleAction: ((FlatMarkRenderNodeID) -> Void)? = nil

    var body: some View {
        VStack(alignment: .markdownListContent, spacing: 8) {
            ForEach(entries) { entry in
                switch entry {
                case let .row(row):
                    FlatMarkListRowView(
                        row: row,
                        taskToggleAction: taskToggleAction
                    )
                case let .childBlock(childBlock):
                    FlatMarkListChildBlockView(
                        childBlock: childBlock,
                        taskToggleAction: taskToggleAction
                    )
                }
            }
        }
    }
}

// MARK: - FlatMarkListChildBlockView

private struct FlatMarkListChildBlockView: View {
    @Environment(\.layoutDirection) private var layoutDirection

    let childBlock: FlatMarkListChildRenderBlock
    var taskToggleAction: ((FlatMarkRenderNodeID) -> Void)? = nil

    var body: some View {
        FlatMarkBlockView(
            block: childBlock.block,
            taskToggleAction: taskToggleAction
        )
        .alignmentGuide(.markdownListContent) { dimensions in
            dimensions[.leading]
        }
        .markdownListIndentation(
            childBlock.indentation - 1,
            spacing: 8,
            layoutDirection: layoutDirection
        )
    }
}

// MARK: - FlatMarkListRowView

private struct FlatMarkListRowView: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.layoutDirection) private var layoutDirection

    let row: FlatMarkListRenderRow
    var taskToggleAction: ((FlatMarkRenderNodeID) -> Void)? = nil

    private var isTaskActionEnabled: Bool {
        isEnabled && taskToggleAction != nil
    }

    var body: some View {
        if case let .task(isChecked) = row.marker {
            Button(action: { taskToggleAction?(row.id) }) {
                rowContent()
            }
            .buttonStyle(.plain)
            .disabled(!isTaskActionEnabled)
            .accessibilityValue(isChecked ? "Checked" : "Unchecked")
        } else {
            rowContent()
        }
    }

    private func rowContent() -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            marker()
            Text(row.content)
                .alignmentGuide(.markdownListContent) { dimensions in
                    dimensions[.leading]
                }
        }
        .markdownListIndentation(
            row.indentation,
            spacing: 8,
            layoutDirection: layoutDirection
        )
    }

    @ViewBuilder
    private func marker() -> some View {
        switch row.marker {
        case .unordered:
            Text("•")
                .foregroundStyle(.secondary)

        case let .ordered(index):
            Text("\(index).")
                .foregroundStyle(.secondary)

        case let .task(isChecked):
            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                .font(.body)
                .foregroundStyle(
                    isTaskActionEnabled
                        ? (isChecked ? .green : .secondary)
                        : .gray.opacity(0.4)
                )
                .accessibilityHidden(true)
        }
    }
}

#Preview("Task List") {
    let taskListMarkdown = """
    - [x] Ship the markdown renderer
    - [ ] Review the task list layout Review the task list layout Review the task list layout Review the task list layout 
        - [ ] Nested task inside a subtask
    """

    VStack(alignment: .leading, spacing: 32) {
        FlatMarkView(markdown: taskListMarkdown)
        FlatMarkView(markdown: taskListMarkdown, taskToggleAction: { _ in })
    }
    .padding()
}
