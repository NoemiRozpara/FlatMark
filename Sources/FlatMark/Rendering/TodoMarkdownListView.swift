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
    let imageLoader: FlatMarkImageLoader?
    let imageURLPolicy: FlatMarkImageURLPolicy
    var taskToggleAction: ((FlatMarkRenderNodeID) -> Void)? = nil

    var body: some View {
        VStack(alignment: .markdownListContent, spacing: 8) {
            ForEach(entries) { entry in
                switch entry {
                case let .row(row):
                    FlatMarkListRowView(
                        row: row,
                        imageLoader: imageLoader,
                        imageURLPolicy: imageURLPolicy,
                        taskToggleAction: taskToggleAction
                    )
                case let .childBlock(childBlock):
                    FlatMarkListChildBlockView(
                        childBlock: childBlock,
                        imageLoader: imageLoader,
                        imageURLPolicy: imageURLPolicy,
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
    let imageLoader: FlatMarkImageLoader?
    let imageURLPolicy: FlatMarkImageURLPolicy
    var taskToggleAction: ((FlatMarkRenderNodeID) -> Void)? = nil

    var body: some View {
        FlatMarkBlockView(
            block: childBlock.block,
            imageLoader: imageLoader,
            imageURLPolicy: imageURLPolicy,
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
    @Environment(\.layoutDirection) private var layoutDirection

    let row: FlatMarkListRenderRow
    let imageLoader: FlatMarkImageLoader?
    let imageURLPolicy: FlatMarkImageURLPolicy
    var taskToggleAction: ((FlatMarkRenderNodeID) -> Void)? = nil

    var body: some View {
        if case let .task(isChecked) = row.marker {
            taskRow(isChecked: isChecked)
        } else {
            rowContent()
        }
    }

    @ViewBuilder
    private func taskRow(isChecked: Bool) -> some View {
        if let taskToggleAction {
            Toggle(
                isOn: Binding(
                    get: { isChecked },
                    set: { _ in taskToggleAction(row.id) }
                )
            ) {
                inlineContent
            }
            #if os(macOS)
            .toggleStyle(.checkbox)
            #endif
            .accessibilityLabel(taskAccessibilityLabel)
            .markdownListIndentation(
                row.indentation,
                spacing: 8,
                layoutDirection: layoutDirection
            )
        } else {
            rowContent()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(taskAccessibilityLabel)
                .accessibilityValue(isChecked ? "Checked" : "Unchecked")
        }
    }

    private func rowContent() -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            marker()
            inlineContent
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

    private var taskAccessibilityLabel: String {
        "Level \(row.indentation + 1) task: \(row.content.plainText)"
    }

    private var inlineContent: some View {
        FlatMarkInlineView(
            content: row.content,
            imageLoader: imageLoader,
            imageURLPolicy: imageURLPolicy
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
                .foregroundStyle(isChecked ? .green : .secondary)
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
