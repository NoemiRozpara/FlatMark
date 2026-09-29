import SwiftUI

/// A native SwiftUI preview of GitHub Flavored Markdown.
///
/// FlatMark renders supported Markdown constructs as native views. When you provide
/// ``init(markdown:baseURL:imageLoader:imageURLPolicy:taskToggleAction:)``,
/// task-list checkboxes can update their corresponding source marker; FlatMark does
/// not otherwise edit or serialize Markdown.
public struct FlatMarkView: View {
    private let markdown: String
    private let baseURL: URL?
    private let imageLoader: FlatMarkImageLoader?
    private let imageURLPolicy: FlatMarkImageURLPolicy
    private var taskToggleAction: ((String) -> Void)?

    /// Creates a Markdown preview.
    ///
    /// - Parameters:
    ///   - markdown: The Markdown source to render.
    ///   - baseURL: The URL used to resolve relative link and image destinations.
    ///   - imageLoader: An optional host-provided image loader. When omitted, images
    ///     are deterministic, network-free placeholders containing their alt text.
    ///   - imageURLPolicy: The scheme policy applied before invoking `imageLoader`.
    ///   - taskToggleAction: An optional closure called with the complete updated
    ///     Markdown source when a task checkbox is toggled.
    public init(
        markdown: String,
        baseURL: URL? = nil,
        imageLoader: FlatMarkImageLoader? = nil,
        imageURLPolicy: FlatMarkImageURLPolicy = .webOnly,
        taskToggleAction: ((String) -> Void)? = nil
    ) {
        self.markdown = markdown
        self.baseURL = baseURL
        self.imageLoader = imageLoader
        self.imageURLPolicy = imageURLPolicy
        self.taskToggleAction = taskToggleAction
    }

    public var body: some View {
        FlatMarkDocumentView(
            document: FlatMarkRenderProjector.project(markdown: markdown, baseURL: baseURL),
            imageLoader: imageLoader,
            imageURLPolicy: imageURLPolicy,
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
