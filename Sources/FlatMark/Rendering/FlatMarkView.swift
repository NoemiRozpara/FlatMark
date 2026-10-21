import SwiftUI

/// A native SwiftUI preview of GitHub Flavored Markdown.
///
/// FlatMark renders supported Markdown constructs as native views. When you provide
/// `taskToggleAction`,
/// task-list checkboxes can update their corresponding source marker; FlatMark does
/// not otherwise edit or serialize Markdown.
public struct FlatMarkView: View {
    private let markdown: String
    private let baseURL: URL?
    private let context: FlatMarkRenderContext
    private let linkActivationAction: ((URL) -> FlatMarkLinkActivationResult)?
    private let detectMentions: Bool

    @Environment(\.openURL) private var openURL

    /// Creates a Markdown preview.
    ///
    /// Links use native URL opening on activation, without a navigation scheme allowlist.
    /// Image fetching is independently restricted by `imageURLPolicy` and requires a loader.
    ///
    /// - Parameters:
    ///   - markdown: The Markdown source to render.
    ///   - baseURL: The Foundation base for relative link and image destinations,
    ///     preserving file/directory semantics. Only absolute resolved URLs are usable.
    ///     Empty or unresolvable links keep their content without navigation.
    ///   - imageLoader: An optional host-provided image loader. When omitted, images
    ///     are deterministic, network-free placeholders containing their alt text.
    ///   - imageURLPolicy: The scheme policy applied before invoking `imageLoader`.
    ///   - unsupportedContentPolicy: What to render where Markdown carries content that has no
    ///     native view. The default renders inert literal text, so HTML and unknown nodes are
    ///     never replaced by renderer diagnostics; `.omit` removes that content instead, together
    ///     with the layout slot of a block it leaves empty. `.custom(render:)` replaces unsupported
    ///     inline and block nodes with host-owned native views, without a literal fallback or an
    ///     enclosing Markdown link action. Hosts own their views' styling, actions, and accessibility.
    ///   - linkActivationAction: An optional synchronous action receiving the resolved
    ///     absolute destination on activation. Handling or rejecting suppresses opening;
    ///     default opening delegates once to the inherited SwiftUI environment opener.
    ///   - detectMentions: Whether to render lexical `@username` tokens in bold, without
    ///     adding actions or link semantics. Each Markdown text node is scanned independently;
    ///     formatting is a hard boundary. Code and link labels are excluded.
    ///     Handles are ASCII letters, digits, and underscores, optionally
    ///     separated by internal dots or hyphens. No user lookup is performed.
    ///   - taskToggleAction: An optional closure called with the complete updated
    ///     Markdown source when a task checkbox is toggled.
    public init(
        markdown: String,
        baseURL: URL? = nil,
        imageLoader: FlatMarkImageLoader? = nil,
        imageURLPolicy: FlatMarkImageURLPolicy = .webOnly,
        unsupportedContentPolicy: FlatMarkUnsupportedContentPolicy = .literal,
        linkActivationAction: ((URL) -> FlatMarkLinkActivationResult)? = nil,
        detectMentions: Bool = false,
        taskToggleAction: ((String) -> Void)? = nil
    ) {
        self.markdown = markdown
        self.baseURL = baseURL
        self.linkActivationAction = linkActivationAction
        self.detectMentions = detectMentions
        context = FlatMarkRenderContext(
            imageLoader: imageLoader,
            imageURLPolicy: imageURLPolicy,
            unsupportedContentPolicy: unsupportedContentPolicy,
            taskToggleAction: taskToggleAction.map { action in
                { sourceRange in
                    guard let updatedMarkdown = FlatMarkTaskMarkerToggle.toggledMarkdown(
                        in: markdown,
                        sourceRange: sourceRange
                    ) else {
                        return
                    }

                    action(updatedMarkdown)
                }
            }
        )
    }

    /// Capture the inherited opener, not the environment installed on the document.
    /// Returning .systemAction here would bypass a host-provided opener.
    private var activationOpenURL: OpenURLAction {
        activationOpenURL(inheriting: openURL)
    }

    func activationOpenURL(inheriting inheritedOpenURL: OpenURLAction) -> OpenURLAction {
        OpenURLAction { url in
            switch linkActivationAction?(url) ?? .useDefaultOpening {
            case .handled:
                return .handled
            case .rejected:
                return .discarded
            case .useDefaultOpening:
                inheritedOpenURL(url)
                return .handled
            }
        }
    }

    public var body: some View {
        FlatMarkDocumentView(
            document: FlatMarkRenderProjector.project(markdown: markdown, baseURL: baseURL, detectMentions: detectMentions),
            context: context
        )
        .environment(\.openURL, activationOpenURL)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
