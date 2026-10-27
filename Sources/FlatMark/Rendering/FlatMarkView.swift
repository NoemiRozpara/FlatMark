import SwiftUI

/// A native SwiftUI preview of GitHub Flavored Markdown.
///
/// FlatMark renders supported Markdown constructs as native views. When you provide
/// `taskToggleAction`,
/// task-list checkboxes can update their corresponding source marker; FlatMark does
/// not otherwise edit or serialize Markdown.
///
/// For repeated rendering, retain a ``FlatMarkDocument`` and use the `document:` initializer
/// to avoid reparsing.
public struct FlatMarkView: View {
    private let document: FlatMarkDocument
    private let context: FlatMarkRenderContext
    private let linkActivationAction: ((URL) -> FlatMarkLinkActivationResult)?

    @Environment(\.openURL) private var openURL

    /// Creates a preview from a retained document without parsing again.
    ///
    /// Links use native URL opening without a scheme allowlist. Image fetching requires a loader
    /// and is restricted separately by `imageURLPolicy`.
    ///
    /// - Parameters:
    ///   - document: The parsed snapshot to reuse across renders.
    ///   - imageLoader: Loads images; when omitted, renders network-free alt-text placeholders.
    ///   - imageURLPolicy: Allowed image schemes, checked before calling the loader.
    ///   - unsupportedContentPolicy: Renders unsupported content as inert text by default.
    ///     `.omit` removes it and any emptied block's layout slot. `.custom(render:)` supplies
    ///     host-owned views without literal fallback or an enclosing Markdown link action;
    ///     the host owns their styling, actions, and accessibility.
    ///   - linkActivationAction: Synchronously handles the resolved absolute URL. Handling or
    ///     rejecting prevents opening; default opening calls the inherited SwiftUI opener once.
    ///   - taskToggleAction: Receives the complete updated source after a checkbox toggle,
    ///     derived from `document.markdown` to keep editing addresses paired with their snapshot.
    public init(
        document: FlatMarkDocument,
        imageLoader: FlatMarkImageLoader? = nil,
        imageURLPolicy: FlatMarkImageURLPolicy = .webOnly,
        unsupportedContentPolicy: FlatMarkUnsupportedContentPolicy = .literal,
        linkActivationAction: ((URL) -> FlatMarkLinkActivationResult)? = nil,
        taskToggleAction: ((String) -> Void)? = nil
    ) {
        self.document = document
        self.linkActivationAction = linkActivationAction
        context = FlatMarkRenderContext(
            imageLoader: imageLoader,
            imageURLPolicy: imageURLPolicy,
            unsupportedContentPolicy: unsupportedContentPolicy,
            taskToggleAction: taskToggleAction.map { action in
                { sourceRange in
                    guard let updatedMarkdown = FlatMarkTaskMarkerToggle.toggledMarkdown(
                        in: document.markdown,
                        sourceRange: sourceRange
                    ) else {
                        return
                    }

                    action(updatedMarkdown)
                }
            }
        )
    }

    /// Creates a Markdown preview from a source string.
    ///
    /// Links use native URL opening on activation, without a navigation scheme allowlist.
    /// Image fetching is independently restricted by `imageURLPolicy` and requires a loader.
    ///
    /// Parses on each initialization. For repeated rendering, retain a ``FlatMarkDocument``
    /// and use the `document:` initializer instead.
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
        self.init(
            document: FlatMarkDocument(markdown: markdown, baseURL: baseURL, detectMentions: detectMentions),
            imageLoader: imageLoader,
            imageURLPolicy: imageURLPolicy,
            unsupportedContentPolicy: unsupportedContentPolicy,
            linkActivationAction: linkActivationAction,
            taskToggleAction: taskToggleAction
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
            document: document.renderDocument,
            context: context
        )
        .environment(\.openURL, activationOpenURL)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
