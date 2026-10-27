// MARK: - FlatMarkRenderContext

/// The host-provided authorities one rendering pass carries from the document view down
/// through blocks, lists, and inline content.
///
/// Bundles what the renderer needs rather than what each view wants: image loading, the URL
/// scheme policy applied before that loader runs, what to do with content that has no native
/// view, and the task-marker toggle. The image fields are read by inline content and tables;
/// `unsupportedContentPolicy` is read wherever an unsupported node appears; `taskToggleAction`
/// is read only by task rows, so a `nil` action renders tasks as static content, and a task with
/// no editing address is static content even when this action exists. Handing the second row a
/// callback is a renderer bug rather than a host choice, and a development build asserts on it.
///
/// The context is not `Sendable`, and that is deliberate. Its `taskToggleAction` forwards to the
/// plain `(String) -> Void` closure supplied to ``FlatMarkView``. Making this type `Sendable`
/// would require that parameter to become `@Sendable`, a breaking change for
/// callers that capture non-`Sendable` state. If a call site ever needs an isolated context,
/// change the public signature first; `readOnly` can then return to being a `static let`.
struct FlatMarkRenderContext {
    /// A read-only pass: static placeholder images, web-only schemes, and no task mutation.
    ///
    /// Computed rather than `static let` for the same non-`Sendable` reason described above.
    static var readOnly: Self {
        Self()
    }

    let imageLoader: FlatMarkImageLoader?
    let imageURLPolicy: FlatMarkImageURLPolicy
    let unsupportedContentPolicy: FlatMarkUnsupportedContentPolicy
    let taskToggleAction: ((FlatMarkSourceRange) -> Void)?
    let taskMarker: FlatMarkTaskMarker

    init(
        imageLoader: FlatMarkImageLoader? = nil,
        imageURLPolicy: FlatMarkImageURLPolicy = .webOnly,
        unsupportedContentPolicy: FlatMarkUnsupportedContentPolicy = .literal,
        taskToggleAction: ((FlatMarkSourceRange) -> Void)? = nil,
        taskMarker: FlatMarkTaskMarker = .default
    ) {
        self.imageLoader = imageLoader
        self.imageURLPolicy = imageURLPolicy
        self.unsupportedContentPolicy = unsupportedContentPolicy
        self.taskToggleAction = taskToggleAction
        self.taskMarker = taskMarker
    }
}
