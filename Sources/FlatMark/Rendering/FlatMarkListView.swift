import SwiftUI

// MARK: - List indentation

/// The gap one nesting level advances list content inward.
private let flatMarkListIndentationSpacing: CGFloat = 8

private extension View {
    /// Indents nested list content inward and reserves that space from the offered width.
    ///
    /// Padding shrinks the proposed width so content stays inside the reading column.
    /// Leading padding follows the layout direction. Clamp at zero because continuation
    /// blocks are projected one level below their row and callers may pass zero.
    func markdownListIndentation(_ indentation: Int, spacing: CGFloat) -> some View {
        padding(.leading, CGFloat(max(indentation, 0)) * spacing)
    }
}

// MARK: - FlatMarkListView

struct FlatMarkListView: View {
    let entries: [FlatMarkListRenderEntry]
    let context: FlatMarkRenderContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(visibleEntries) { entry in
                switch entry {
                case let .row(row):
                    FlatMarkListRowView(row: row, context: context)
                case let .childBlock(childBlock):
                    FlatMarkListChildBlockView(childBlock: childBlock, context: context)
                }
            }
        }
    }

    /// The entries this policy lays out.
    ///
    /// A row is an item of the list, not a container of unsupported content, so omission keeps
    /// every marker, ordered number, and task control. Only a continuation block that presents
    /// nothing leaves the sequence.
    private var visibleEntries: [FlatMarkListRenderEntry] {
        entries.filter { entry in
            switch entry {
            case .row:
                true
            case let .childBlock(childBlock):
                context.unsupportedContentPolicy.presents(childBlock.block)
            }
        }
    }
}

// MARK: - FlatMarkListChildBlockView

private struct FlatMarkListChildBlockView: View {
    let childBlock: FlatMarkListChildRenderBlock
    let context: FlatMarkRenderContext

    var body: some View {
        FlatMarkBlockView(block: childBlock.block, context: context)
            .markdownListIndentation(childBlock.indentation - 1, spacing: flatMarkListIndentationSpacing)
    }
}

// MARK: - FlatMarkListRowView

struct FlatMarkListRowView: View {
    let row: FlatMarkListRenderRow
    let context: FlatMarkRenderContext

    /// The checkbox action, or `nil` without both an editing address and a host callback.
    /// Static tasks still show their checked state.
    ///
    /// String projection supplies task addresses. An unaddressable task with a callback
    /// indicates an invalid render value and triggers a debug assertion.
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
        // Keep the control and paragraph as siblings so links remain independently actionable
        // and inline image identity survives policy changes. A whole-row accessibilityRepresentation
        // would replace the paragraph's accessible links and image descriptions with one element.
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            leadingElement
            inlineContent
                // Preserve the full label when the stack proposes a compressed height.
                .fixedSize(horizontal: false, vertical: true)
        }
        .markdownListIndentation(row.indentation, spacing: flatMarkListIndentationSpacing)
    }

    @ContentBuilder
    private var leadingElement: some View {
        if case let .task(isChecked, _) = row.marker {
            if let taskToggleAction {
                Button(action: taskToggleAction) {
                    marker()
                        .accessibilityHidden(true)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .fixedSize()
                .accessibilityLabel(taskAccessibilityLabel)
                .accessibilityValue(isChecked ? "Checked" : "Unchecked")
                .accessibilityAddTraits(.isToggle)
            } else {
                marker()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(taskAccessibilityLabel)
                    .accessibilityValue(isChecked ? "Checked" : "Unchecked")
            }
        } else {
            marker()
        }
    }

    /// The control's VoiceOver name: the task level plus the row's wording under the active
    /// unsupported-content policy, so two tasks at the same level stay distinguishable.
    var taskAccessibilityLabel: String {
        "Level \(row.indentation + 1) task: \(context.unsupportedContentPolicy.plainText(for: row.content))"
    }

    private var inlineContent: some View {
        FlatMarkInlineView(content: row.content, context: context)
    }

    @ContentBuilder
    private func marker() -> some View {
        switch row.marker {
        case .unordered:
            Text("•")
                .foregroundStyle(.secondary)

        case let .ordered(index):
            Text("\(index).")
                .foregroundStyle(.secondary)

        case let .task(isChecked, _):
            context.taskMarker.view(isChecked: isChecked)
                .allowsHitTesting(false)
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
