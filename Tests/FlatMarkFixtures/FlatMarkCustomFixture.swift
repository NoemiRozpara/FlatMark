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

/// Backend-free policy-switching fixture, shared by the automated suite and `FlatMarkFixtureHost`.
/// Present `FlatMarkCustomFixture(model:)` for iOS/macOS observation; run the host with
/// `scripts/run-fixture-host.sh`.
public struct FlatMarkCustomFixture: View {
    @Bindable public var model: FlatMarkCustomFixtureModel

    public init(model: FlatMarkCustomFixtureModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Unsupported content", selection: $model.policyKind) {
                ForEach(FlatMarkCustomPolicyKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            Picker("Task marker", selection: $model.usesHostTaskMarker) {
                Text("Default marker").tag(false)
                Text("Host marker").tag(true)
            }
            .pickerStyle(.segmented)
            Toggle("Task editing", isOn: $model.allowsTaskEditing)
            Toggle("Disable tasks", isOn: $model.disablesTasks)
            Button("Load task-marker sample") { model.markdown = FlatMarkCustomFixtureModel.taskMarkerMarkdown }
            Toggle("Host buttons", isOn: $model.showsButtons)
            Toggle("Empty output", isOn: $model.showsEmpty)
            Toggle("Large text", isOn: $model.enlargedText)
            Toggle("RTL", isOn: $model.rightToLeft)
            TextField("Replacement label", text: $model.replacementLabel)
            Button("Load omission sample") { model.markdown = FlatMarkCustomFixtureModel.omissionMarkdown }
            Text("Images: \(model.imageCalls.urls.count); actions: \(model.customActivations); links: \(model.linkActivations); tasks: \(model.taskUpdates)")
            FlatMarkCustomDocumentFixture(model: model)
                .dynamicTypeSize(model.enlargedText ? .accessibility2 : .large)
                .environment(\.layoutDirection, model.rightToLeft ? .rightToLeft : .leftToRight)
                .frame(width: 240, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Document-only path for mounted tests; unrelated controls cannot make its content oracle pass.
public struct FlatMarkCustomDocumentFixture: View {
    public let model: FlatMarkCustomFixtureModel

    public init(model: FlatMarkCustomFixtureModel) {
        self.model = model
    }

    public var body: some View {
        FlatMarkView(
            markdown: model.markdown,
            baseURL: URL(string: "https://example.com/"),
            imageLoader: model.loader,
            unsupportedContentPolicy: model.policy(rendering: model.replacementLabel),
            linkActivationAction: { _ in
                model.linkActivations += 1
                return .handled
            },
            taskToggleAction: model.allowsTaskEditing ? { updatedMarkdown in
                model.markdown = updatedMarkdown
                model.taskUpdates += 1
            } : nil,
            taskMarker: model.usesHostTaskMarker ? .custom { isChecked in
                FlatMarkFixtureTaskMark(isChecked: isChecked)
            } : .default
        )
        .disabled(model.disablesTasks)
    }
}

// MARK: - FlatMarkCustomFixtureModel

@MainActor
@Observable
public final class FlatMarkCustomFixtureModel {
    public static let taskMarkerMarkdown = """
    - [x] Shipped
    - [ ] Review [Details](details)
      - [ ] Nested pending
      - [x] Nested complete
    - [ ] Task with <u>host content</u>
    """

    public static let omissionMarkdown = """
    Before

    <div>hidden block</div>

    > > <u></u>

    - [x] Keep checked
    - [ ] <u></u>

      > <u></u>

      > Supported continuation

    ![Supported image](image.png)

    7. <u></u>
    8. keep

    | A | B |
    | --- | --- |
    | <u></u> | keep |

    [Details](details)

    After
    """

    public static let omissionReferenceMarkdown = """
    Before

    - [x] Keep checked
    - [ ] <u></u>

      > Supported continuation

    ![Supported image](image.png)

    7.
    8. keep

    | A | B |
    | --- | --- |
    | | keep |

    [Details](details)

    After
    """

    public static let markdown = """
    Before

    <div>hidden block</div>

    before <u>important</u> after

    **before <u>x</u> after**

    # before <u>x</u>

    [linked <u>x</u> after](https://example.com/md)

    > > <div>quoted block</div>

    > > nested <u>x</u> quote

    - [ ] task <u>x</u> text

    | Heading <u>x</u> |
    | - |
    | cell <u>y</u> |

    Multiline supported text wraps at the available width <u>x</u> after.\\
    Explicit line break.

    image <u>x</u> ![Supported image](image.png)

    After
    """

    public var markdown: String
    public var policyKind: FlatMarkCustomPolicyKind = .literal {
        didSet { payloads = [] }
    }
    public var replacementLabel = "Replacement"
    public var allowsTaskEditing = true
    public var usesHostTaskMarker = false
    public var disablesTasks = false
    public var showsButtons = false
    public var showsEmpty = false
    public var enlargedText = false
    public var rightToLeft = false
    public var customActivations = 0
    public var linkActivations = 0
    public var taskUpdates = 0
    @ObservationIgnored public var payloads: [String] = []
    @ObservationIgnored public var presentedLabels: [String] = []
    public let imageCalls = FlatMarkRecordedImageLoads()
    public let loader: FlatMarkImageLoader

    public init(markdown: String = FlatMarkCustomFixtureModel.markdown) {
        self.markdown = markdown
        let imageCalls = imageCalls
        loader = FlatMarkImageLoader(configurationID: UUID()) { url in
            await imageCalls.record(url)
            return Image(systemName: "photo.fill")
        }
    }

    public func policy(rendering label: String) -> FlatMarkUnsupportedContentPolicy {
        switch policyKind {
        case .literal:
            return .literal
        case .omit:
            return .omit
        case .custom:
            let showsButtons = showsButtons
            let showsEmpty = showsEmpty
            return .custom { payload in
                self.payloads.append(payload)
                self.presentedLabels.append(label)
                if showsEmpty { return AnyView(EmptyView()) }
                if showsButtons { return AnyView(Button(label) { self.customActivations += 1 }) }
                return AnyView(Text(label))
            }
        }
    }
}
