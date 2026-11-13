// MARK: - FlatMarkRenderContext

/// Host settings and callbacks shared by blocks, lists, and inline content.
///
/// Tasks stay static without both an editing address and a callback. Supplying a callback
/// for an unaddressable task is a renderer bug and triggers a debug assertion.
///
/// This type is not `Sendable`: its task callback forwards to FlatMarkView's plain
/// `(String) -> Void` closure. Requiring `@Sendable` would break callers that capture
/// non-`Sendable` state.
struct FlatMarkRenderContext {
    /// A read-only pass: static placeholder images, web-only schemes, and no task mutation.
    ///
    /// Computed to avoid sharing a non-`Sendable` value.
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
