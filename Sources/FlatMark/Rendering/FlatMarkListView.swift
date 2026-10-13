import SwiftUI

// MARK: - FlatMarkListContentAlignment

private enum FlatMarkListContentAlignment: AlignmentID {
    static func defaultValue(in dimensions: ViewDimensions) -> CGFloat {
        dimensions[.leading]
    }
}

private extension HorizontalAlignment {
    static let flatMarkListContent = HorizontalAlignment(FlatMarkListContentAlignment.self)
}

private extension View {
    func markdownListIndentation(
        _ indentation: Int,
        spacing: CGFloat,
        layoutDirection: LayoutDirection
    ) -> some View {
        let offset = CGFloat(indentation) * spacing
        let directionalOffset = layoutDirection == .leftToRight ? -offset : offset

        return alignmentGuide(.flatMarkListContent) { dimensions in
            dimensions[.flatMarkListContent] + directionalOffset
        }
    }
}

// MARK: - FlatMarkListView

struct FlatMarkListView: View {
    let entries: [FlatMarkListRenderEntry]
    let context: FlatMarkRenderContext

    var body: some View {
        VStack(alignment: .flatMarkListContent, spacing: 8) {
            ForEach(entries) { entry in
                switch entry {
                case let .row(row):
                    FlatMarkListRowView(row: row, context: context)
                case let .childBlock(childBlock):
                    FlatMarkListChildBlockView(childBlock: childBlock, context: context)
                }
            }
        }
    }
}

// MARK: - FlatMarkListChildBlockView

private struct FlatMarkListChildBlockView: View {
    @Environment(\.layoutDirection) private var layoutDirection

    let childBlock: FlatMarkListChildRenderBlock
    let context: FlatMarkRenderContext

    var body: some View {
        FlatMarkBlockView(block: childBlock.block, context: context)
        .alignmentGuide(.flatMarkListContent) { dimensions in
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

struct FlatMarkListRowView: View {
    @Environment(\.layoutDirection) private var layoutDirection

    let row: FlatMarkListRenderRow
    let context: FlatMarkRenderContext

    /// The change this row's checkbox performs, or `nil` when the row is static content.
    ///
    /// A task is interactive only when it has both a typed editing address and a host callback.
    /// Without either one the row keeps showing its checked state and offers no mutation, so the
    /// callback cannot be invoked for a marker that cannot be addressed safely.
    ///
    /// Handing an unaddressable task a callback is a renderer bug rather than a host choice:
    /// Markdown projected from a string always gives a task marker its address, so a `nil`
    /// address here means a render value was built without one. The debug build says so.
    var taskToggleAction: (() -> Void)? {
        guard case let .task(_, sourceRange) = row.marker else {
            return nil
        }

        guard let hostTaskToggleAction = context.taskToggleAction else {
            return nil
        }

        guard let sourceRange else {
            assertionFailure("A task row that offers a host toggle action must carry an editing address.")
            return nil
        }

        return { hostTaskToggleAction(sourceRange) }
    }

    var body: some View {
        if case let .task(isChecked, _) = row.marker {
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
                    set: { _ in taskToggleAction() }
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
                .alignmentGuide(.flatMarkListContent) { dimensions in
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
        FlatMarkInlineView(content: row.content, context: context)
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

        case let .task(isChecked, _):
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
