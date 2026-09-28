import SwiftUI

public struct MarkdownView: View {
    private let markdown: String
    /// Receives the complete updated Markdown after a task checkbox is toggled.
    private var markdownChangeAction: ((String) -> Void)?

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
