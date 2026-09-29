import SwiftUI

/// A native SwiftUI preview of GitHub Flavored Markdown.
///
/// FlatMark renders supported Markdown constructs as native views. When you provide
/// ``init(markdown:markdownChangeAction:)``, task-list checkboxes can update their
/// corresponding source marker; FlatMark does not otherwise edit or serialize Markdown.
public struct FlatMarkView: View {
    private let markdown: String
    private var markdownChangeAction: ((String) -> Void)?

    /// Creates a Markdown preview.
    ///
    /// - Parameters:
    ///   - markdown: The Markdown source to render.
    ///   - markdownChangeAction: An optional closure called with the complete updated
    ///     Markdown source when a task checkbox is toggled.
    public init(
        markdown: String,
        markdownChangeAction: ((String) -> Void)? = nil
    ) {
        self.markdown = markdown
        self.markdownChangeAction = markdownChangeAction
    }

    public var body: some View {
        TodoMarkdownDocumentView(
            document: TodoMarkdownProjector.project(markdown: markdown),
            taskToggleAction: markdownChangeAction.map { action in
                { id in
                    guard let updatedMarkdown = TodoMarkdownTaskToggleOperation.toggledMarkdown(
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
