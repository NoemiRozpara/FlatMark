import SwiftUI

/// A native SwiftUI preview of GitHub Flavored Markdown.
///
/// FlatMark renders supported Markdown constructs as native views. When you provide
/// ``init(markdown:taskToggleAction:)``, task-list checkboxes can update their
/// corresponding source marker; FlatMark does not otherwise edit or serialize Markdown.
public struct FlatMarkView: View {
    private let markdown: String
    private var taskToggleAction: ((String) -> Void)?

    /// Creates a Markdown preview.
    ///
    /// - Parameters:
    ///   - markdown: The Markdown source to render.
    ///   - taskToggleAction: An optional closure called with the complete updated
    ///     Markdown source when a task checkbox is toggled.
    public init(
        markdown: String,
        taskToggleAction: ((String) -> Void)? = nil
    ) {
        self.markdown = markdown
        self.taskToggleAction = taskToggleAction
    }

    public var body: some View {
        FlatMarkDocumentView(
            document: FlatMarkRenderProjector.project(markdown: markdown),
            taskToggleAction: taskToggleAction.map { action in
                { id in
                    guard let updatedMarkdown = TaskListMarkerToggle.toggledMarkdown(
                        in: markdown,
                        id: id
                    ) else {
                        return
                    }

                    action(updatedMarkdown)
                }
            }
        )
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
