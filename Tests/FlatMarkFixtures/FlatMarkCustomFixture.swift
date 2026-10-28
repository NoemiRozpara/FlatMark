import FlatMark
import SwiftUI

// MARK: - FlatMarkCustomPolicyKind

public enum FlatMarkCustomPolicyKind: String, CaseIterable, Identifiable, Hashable {
    case literal
    case omit
    case custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .literal: "Literal"
        case .omit: "Omit"
        case .custom: "Custom"
        }
    }
}

// MARK: - FlatMarkCustomFixture

/// Backend-free playground, shared by the automated suite and `FlatMarkFixtureHost`: a single page
/// showing the shared recipe with exploration controls above it.
/// Present `FlatMarkCustomFixture(model:)` for iOS/macOS observation; run the host with
/// `scripts/run-fixture-host.sh`.
public struct FlatMarkCustomFixture: View {
    @Bindable public var model: FlatMarkCustomFixtureModel
    @State private var settingsExpanded = false
    @State private var sourceExpanded = false

    public init(model: FlatMarkCustomFixtureModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Label("Recipe Lab", systemImage: "fork.knife")
                .font(.largeTitle.bold())
            GroupBox {
                DisclosureGroup(isExpanded: $settingsExpanded) {
                    FlatMarkRecipeSettings(model: model)
                        .padding(.top, 12)
                } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
                        .font(.headline)
                }
                .padding(8)
            }
            GroupBox {
                DisclosureGroup(isExpanded: $sourceExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("View or edit the raw Markdown. Changes appear in the recipe preview below; ticking tasks also updates this source.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $model.markdown)
                            .font(.system(.body, design: .monospaced))
                            .autocorrectionDisabled()
                            .frame(minHeight: 280)
                            .accessibilityLabel("Raw Markdown source")
                    }
                    .padding(.top, 12)
                } label: {
                    Label("Markdown source", systemImage: "doc.plaintext")
                        .font(.headline)
                }
                .padding(8)
            }
            Label(model.lastActivity, systemImage: "bubble.left")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.quaternary, in: .rect(cornerRadius: 12))
            recipe
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .tint(.orange)
        .preferredColorScheme(model.darkAppearance ? .dark : .light)
    }

    /// Reading settings apply only to the recipe, not the surrounding controls.
    private var recipe: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The recipe")
                .font(.title2.bold())
            Text("This recipe is an interactive rendering demo. Tick a baking step to update its checkbox and the Markdown source. Recipe links—including the photo—show a local note in the activity strip above instead of opening a browser. With Replace tags and Make replacements tappable enabled in Settings, replacement buttons show a baker’s tip in that same strip. These actions only change this demo’s state; they don’t send data or navigate away.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: Self.columnWidth, alignment: .leading)
            Group {
                Divider()
                FlatMarkCustomDocumentFixture(model: model)
            }
            .dynamicTypeSize(model.enlargedText ? .accessibility2 : .large)
            .environment(\.layoutDirection, model.rightToLeft ? .rightToLeft : .leftToRight)
            #if os(macOS)
            // macOS does not scale body text from Dynamic Type alone.
            .font(.system(size: model.enlargedText ? 28 : 17))
            #endif
            .frame(maxWidth: Self.columnWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// iOS keeps the narrow reading column; a macOS window is resized instead.
    private static var columnWidth: CGFloat? {
        #if os(macOS)
        nil
        #else
        240
        #endif
    }
}

// MARK: - FlatMarkCustomDocumentFixture

/// Document-only path for mounted tests and the playground recipe; unrelated
/// controls cannot make its content oracle pass.
public struct FlatMarkCustomDocumentFixture: View {
    public let model: FlatMarkCustomFixtureModel
    private let usesRetainedDocument: Bool?

    public init(model: FlatMarkCustomFixtureModel, usesRetainedDocument: Bool? = nil) {
        self.model = model
        self.usesRetainedDocument = usesRetainedDocument
    }

    public var body: some View {
        let _ = model.refreshRequests
        let policy = model.policy()
        let activateLink: (URL) -> FlatMarkLinkActivationResult = { url in
            switch url.lastPathComponent {
            case "herbs":
                model.lastActivity = "The recipe: Rosemary note: strip the leaves from two sprigs; scatter them over the oiled dough."
            case "folding":
                model.lastActivity = "The recipe: Folding note: lift one edge, fold it into the middle, and repeat on all four sides."
            case "tin":
                model.lastActivity = "The recipe: Tin note: use a 23 × 33 cm tin and oil the base and corners generously."
            default:
                model.lastActivity = "The recipe: Example link handled locally. No browser was opened."
            }
            model.linkActivations += 1
            return .handled
        }
        let toggleTask: ((String) -> Void)? = model.allowsTaskEditing ? { updatedMarkdown in
            model.markdown = updatedMarkdown
            model.taskUpdates += 1
            model.lastActivity = "The recipe: Recipe updated. Nice prep work!"
        } : nil
        let marker: FlatMarkTaskMarker = model.usesHostTaskMarker ? .custom { isChecked in
            FlatMarkFixtureTaskMark(isChecked: isChecked)
        } : .default

        if usesRetainedDocument ?? model.usesRetainedDocument {
            FlatMarkView(
                document: model.document,
                imageLoader: model.loader,
                unsupportedContentPolicy: policy,
                linkActivationAction: activateLink,
                taskToggleAction: toggleTask,
                taskMarker: marker
            )
        } else {
            FlatMarkView(
                markdown: model.markdown,
                baseURL: FlatMarkCustomFixtureModel.baseURL,
                imageLoader: model.loader,
                unsupportedContentPolicy: policy,
                linkActivationAction: activateLink,
                detectMentions: model.detectMentions,
                taskToggleAction: toggleTask,
                taskMarker: marker
            )
        }
    }
}

// MARK: - FlatMarkCustomFixtureModel

@MainActor
@Observable
public final class FlatMarkCustomFixtureModel {
    public static let markdown = FlatMarkRecipeSample.markdown

    /// The same recipe is mounted by the automated suite and shown in the playground.
    public static let baseURL = URL(string: "https://example.com/")
    public var markdown: String {
        didSet { rebuildDocument() }
    }
    public private(set) var document: FlatMarkDocument
    public var usesRetainedDocument = false
    public var refreshRequests = 0
    public var policyKind: FlatMarkCustomPolicyKind = .literal {
        didSet { payloads = [] }
    }
    public var replacementLabel = "Replacement"
    public var allowsTaskEditing = true
    public var usesHostTaskMarker = false
    public var showsButtons = false
    public var showsEmpty = false
    public var darkAppearance = false
    public var enlargedText = false
    public var rightToLeft = false
    public var detectMentions = true {
        didSet { rebuildDocument() }
    }
    public var lastActivity = "Your recipe notes and task confirmations appear here."
    public var customActivations = 0
    public var linkActivations = 0
    public var taskUpdates = 0
    @ObservationIgnored public var payloads: [String] = []
    @ObservationIgnored public var presentedLabels: [String] = []
    public let imageCalls = FlatMarkRecordedImageLoads()
    public let loader: FlatMarkImageLoader

    public init(markdown: String = FlatMarkCustomFixtureModel.markdown) {
        self.markdown = markdown
        document = FlatMarkDocument(markdown: markdown, baseURL: Self.baseURL, detectMentions: true)
        let imageCalls = imageCalls
        let imageURL = Bundle.module.url(forResource: "focaccia", withExtension: "png")
        let expectedImageURL = Self.baseURL?.appending(path: "focaccia.png")
        loader = FlatMarkImageLoader(configurationID: UUID()) { url in
            await imageCalls.record(url)
            guard url == expectedImageURL, let imageURL else {
                return Image(systemName: "leaf.fill")
            }
            #if os(macOS)
            guard let image = NSImage(contentsOf: imageURL) else { return Image(systemName: "leaf.fill") }
            return Image(nsImage: image)
            #elseif canImport(UIKit)
            guard let image = UIImage(contentsOfFile: imageURL.path) else { return Image(systemName: "leaf.fill") }
            return Image(uiImage: image)
            #else
            return Image(systemName: "leaf.fill")
            #endif
        }
    }

    private func rebuildDocument() {
        document = FlatMarkDocument(markdown: markdown, baseURL: Self.baseURL, detectMentions: detectMentions)
    }

    public func policy() -> FlatMarkUnsupportedContentPolicy {
        switch policyKind {
        case .literal:
            return .literal
        case .omit:
            return .omit
        case .custom:
            let label = replacementLabel
            let showsButtons = showsButtons
            let showsEmpty = showsEmpty
            return .custom { payload in
                self.payloads.append(payload)
                self.presentedLabels.append(label)
                if showsEmpty { return AnyView(EmptyView()) }
                if showsButtons {
                    return AnyView(Button(label) {
                        self.customActivations += 1
                        self.lastActivity = "The recipe: Dimpling tip: oil your fingertips, then press gently into the risen dough."
                    })
                }
                return AnyView(Text(label))
            }
        }
    }
}
