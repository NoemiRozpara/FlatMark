// MARK: - FlatMarkRenderContext

/// The host-provided authorities one rendering pass carries from the document view down
/// through blocks, lists, and inline content.
///
/// Bundles what the renderer needs rather than what each view wants: image loading, the URL
/// scheme policy applied before that loader runs, and the task-marker toggle. The image fields
/// are read by inline content and tables; `taskToggleAction` is read only by task rows, so a
/// `nil` action renders tasks as static content, and a task with no editing address is static
/// content even when this action exists. Handing the second row a callback is a renderer bug
/// rather than a host choice, and a development build asserts on it.
///
/// The context is not `Sendable`, and that is deliberate. Its `taskToggleAction` forwards to the
/// host closure taken by ``FlatMarkView/init(markdown:baseURL:imageLoader:imageURLPolicy:taskToggleAction:)``,
/// whose `taskToggleAction` parameter is a plain `(String) -> Void`. Making this type `Sendable`
/// would require that public parameter to become `@Sendable`, which is a breaking change for
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
    let taskToggleAction: ((FlatMarkSourceRange) -> Void)?

    init(
        imageLoader: FlatMarkImageLoader? = nil,
        imageURLPolicy: FlatMarkImageURLPolicy = .webOnly,
        taskToggleAction: ((FlatMarkSourceRange) -> Void)? = nil
    ) {
        self.imageLoader = imageLoader
        self.imageURLPolicy = imageURLPolicy
        self.taskToggleAction = taskToggleAction
    }
}
