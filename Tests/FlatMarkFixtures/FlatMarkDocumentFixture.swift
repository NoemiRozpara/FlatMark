import FlatMark
import SwiftUI

// MARK: - FlatMarkDocumentFixture

/// Backend-free fixture for a retained ``FlatMarkDocument``; run `FlatMarkFixtureHost` with
/// `--document` to compare repeated presentations with the string-based initializer.
public struct FlatMarkDocumentFixture: View {
    @Bindable public var model: FlatMarkDocumentFixtureModel

    public init(model: FlatMarkDocumentFixtureModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Refresh requests: \(model.refreshRequests)")
            Toggle("Detect mentions", isOn: $model.detectMentions)
            Button("Re-render without editing") { model.refreshRequests += 1 }
            Button("Edit source") { model.editSource() }
            if let lastToggle = model.lastToggle {
                Text("Last toggle produced: \(lastToggle)")
            }
            Divider()
            documentBackedPreview
            documentBackedPreview
            Divider()
            Text("String-based initializer, same source:")
            stringBackedPreview
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The retained snapshot, presented twice.
    private var documentBackedPreview: some View {
        FlatMarkView(
            document: model.document,
            linkActivationAction: { _ in .handled },
            taskToggleAction: model.toggle
        )
    }

    /// The same source through the string-based initializer, for a side-by-side comparison.
    private var stringBackedPreview: some View {
        FlatMarkView(
            markdown: model.document.markdown,
            baseURL: model.document.baseURL,
            linkActivationAction: { _ in .handled },
            detectMentions: model.document.detectMentions,
            taskToggleAction: model.toggle
        )
    }
}

// MARK: - FlatMarkDocumentFixtureModel

@MainActor
@Observable
public final class FlatMarkDocumentFixtureModel {
    public static let baseURL = URL(string: "https://example.com/docs/readme.md")

    public static let markdown = """
    # Release notes

    Before **bold**, @jane, and [linked text](../other.md).

    - [ ] Review the pull request
    - [x] Ship the release

      > Quoted note about @jane.

    | Owner | State |
    | --- | --- |
    | Noemi | In progress |

    Supported image: ![diagram](diagram.png)
    """

    /// The one snapshot every document-backed preview in this fixture renders.
    public private(set) var document: FlatMarkDocument

    /// Invalidates the enclosing fixture without changing its retained document.
    /// Counts user requests, not renderer evaluations or parser invocations.
    public var refreshRequests = 0

    /// A projection input, so switching it builds a new document rather than re-rendering the old.
    public var detectMentions = false {
        didSet { rebuildDocument(from: document.markdown) }
    }

    public private(set) var lastToggle: String?

    public init(markdown: String = FlatMarkDocumentFixtureModel.markdown) {
        document = FlatMarkDocument(markdown: markdown, baseURL: Self.baseURL)
    }

    /// Appends one supported block to create a new snapshot.
    public func editSource() {
        rebuildDocument(from: document.markdown + "\n\n- [ ] Task added after a re-render")
    }

    /// Receives the complete updated source the renderer derived from ``document``.
    public func toggle(updatedMarkdown: String) {
        lastToggle = updatedMarkdown
        rebuildDocument(from: updatedMarkdown)
    }

    private func rebuildDocument(from markdown: String) {
        document = FlatMarkDocument(markdown: markdown, baseURL: Self.baseURL, detectMentions: detectMentions)
    }
}
