import SwiftUI

// MARK: - FlatMarkDocumentView

struct FlatMarkDocumentView: View {
    let document: FlatMarkRenderDocument
    let context: FlatMarkRenderContext

    var body: some View {
        FlatMarkBlockListView(
            blocks: document.blocks,
            context: context
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - FlatMarkBlockListView

private struct FlatMarkBlockListView: View {
    let blocks: [FlatMarkRenderBlock]
    let context: FlatMarkRenderContext

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(blocks) { block in
                FlatMarkBlockView(
                    block: block,
                    context: context
                )
            }
        }
    }
}

// MARK: - FlatMarkBlockView

struct FlatMarkBlockView: View {
    let block: FlatMarkRenderBlock
    let context: FlatMarkRenderContext

    var body: some View {
        switch block.kind {
        case let .paragraph(content):
            FlatMarkInlineView(
                content: content,
                context: context
            )

        case let .heading(level, content):
            FlatMarkInlineView(
                content: content,
                context: context
            )
                .font(font(for: level))
                .bold()
                .accessibilityAddTraits(.isHeader)

        case let .codeBlock(content):
            Text(content)
                .font(.body.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

        case let .blockQuote(blocks):
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(.secondary)
                    .frame(width: 2)

                FlatMarkBlockListView(blocks: blocks, context: context)
            }

        case let .list(entries):
            FlatMarkListView(entries: entries, context: context)

        case .thematicBreak:
            Divider()

        case let .table(table):
            FlatMarkTableView(table: table, context: context)

        case let .fallback(type, content):
            Text("\(type): \(content)")
                .foregroundStyle(.secondary)
        }
    }

    private func font(for level: Int) -> Font {
        switch level {
        case 1:
            .title
        case 2:
            .title2
        case 3:
            .title3
        default:
            .headline
        }
    }
}

// MARK: - FlatMarkTableView

struct FlatMarkTableView: View {
    private let cellWidth: CGFloat = 160

    let table: FlatMarkRenderTable
    let context: FlatMarkRenderContext

    var rendersTable: Bool {
        !table.header.isEmpty
    }

    var body: some View {
        if rendersTable {
            ScrollView(.horizontal) {
                Grid(
                    alignment: .topLeading,
                    horizontalSpacing: 0,
                    verticalSpacing: 0
                ) {
                    GridRow {
                        ForEach(table.header) { cell in
                            adaptivelySized(inlineView(for: cell.content))
                                .bold()
                                .accessibilityAddTraits(.isHeader)
                        }
                    }

                    ForEach(table.rows) { row in
                        Divider()
                            .gridCellUnsizedAxes(.horizontal)
                            .background(.secondary)
                        GridRow {
                            ForEach(row.cells) { cell in
                                adaptivelySized(inlineView(for: cell.content))
                                    .gridCellColumns(cell.colspan)
                            }
                        }
                    }
                }
                .border(.secondary)
            }
        }
    }

    private func adaptivelySized(_ view: some View) -> some View {
        view
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(8)
            .frame(width: cellWidth, alignment: .topLeading)
    }

    private func inlineView(for content: FlatMarkRenderInlineContent) -> some View {
        FlatMarkInlineView(content: content, context: context)
    }
}

// MARK: - FlatMarkInlineView

struct FlatMarkInlineView: View {
    enum RenderingMode: Equatable {
        case inlineText
        case standaloneLinkedImage(URL)
        case linkedImageFlow
        case responsiveImageFlow
    }

    enum ImagePhase {
        case placeholder
        case loading
        case loaded(Image)
        case failed
    }

    private enum ImageLoadResult: Sendable {
        case loaded(componentIndex: Int, image: Image)
        case failed(componentIndex: Int)
        case cancelled(componentIndex: Int)
    }

    private struct ImageRequest: Equatable {
        let componentIndex: Int
        let request: FlatMarkImageRequest
    }

    private struct ImageTaskID: Equatable {
        let requests: [ImageRequest]
        let loaderConfigurationID: UUID?
    }

    struct InlineElement: Identifiable, Equatable {
        enum Content: Equatable {
            case text(AttributedString)
            case lineBreak
            case image(componentIndex: Int, image: FlatMarkRenderImage)
        }

        let id: Int
        let content: Content
    }

    let content: FlatMarkRenderInlineContent
    let context: FlatMarkRenderContext

    @Environment(\.layoutDirection) private var layoutDirection
    @State private var imagePhases: [Int: ImagePhase] = [:]

    var renderingMode: RenderingMode {
        if let destination = content.standaloneLinkedImageDestination {
            return .standaloneLinkedImage(destination)
        }

        if content.components.contains(where: \.isLinkedImage) {
            return .linkedImageFlow
        }

        return imagePhases.values.contains(where: \.isLoaded)
            ? .responsiveImageFlow
            : .inlineText
    }

    var body: some View {
        renderedContent
            .accessibilityRepresentation {
                if let destination = content.standaloneLinkedImageDestination {
                    Link(destination: destination) {
                        accessibilityText
                    }
                } else {
                    accessibilityText
                }
            }
            .task(id: imageTaskID) {
                await loadImages()
            }
    }

    @ViewBuilder
    private var renderedContent: some View {
        switch renderingMode {
        case let .standaloneLinkedImage(destination):
            Link(destination: destination) {
                FlatMarkInlineFlowLayout(layoutDirection: layoutDirection) {
                    ForEach(inlineElements) { element in
                        inlineView(for: element)
                    }
                }
            }

        case .linkedImageFlow, .responsiveImageFlow:
            FlatMarkInlineFlowLayout(layoutDirection: layoutDirection) {
                ForEach(inlineElements) { element in
                    inlineView(for: element)
                }
            }

        case .inlineText:
            inlineText
        }
    }

    private var inlineElements: [InlineElement] {
        Self.inlineElements(for: content)
    }

    static func inlineElements(for content: FlatMarkRenderInlineContent) -> [InlineElement] {
        var elements: [InlineElement] = []

        for (componentIndex, component) in content.components.enumerated() {
            switch component {
            case let .text(text):
                for fragment in text.inlineFragments {
                    switch fragment {
                    case let .text(text):
                        elements.append(InlineElement(
                            id: elements.count,
                            content: .text(text)
                        ))
                    case .lineBreak:
                        elements.append(InlineElement(
                            id: elements.count,
                            content: .lineBreak
                        ))
                    }
                }
            case let .image(image):
                elements.append(InlineElement(
                    id: elements.count,
                    content: .image(componentIndex: componentIndex, image: image)
                ))
            }
        }

        return elements
    }

    @ViewBuilder
    private func inlineView(for element: InlineElement) -> some View {
        switch element.content {
        case let .text(text):
            Text(text)
        case .lineBreak:
            Color.clear
                .frame(width: 0, height: 0)
                .layoutValue(key: FlatMarkInlineFlowLayout.LineBreakKey.self, value: true)
                .accessibilityHidden(true)
        case let .image(index, image):
            if let destination = image.link {
                Link(destination: destination) {
                    imageView(for: image, at: index)
                }
            } else {
                imageView(for: image, at: index)
            }
        }
    }

    @ViewBuilder
    private func imageView(for image: FlatMarkRenderImage, at index: Int) -> some View {
        switch imagePhases[index] ?? .placeholder {
        case let .loaded(loadedImage):
            ViewThatFits(in: .horizontal) {
                loadedImage
                loadedImage
                    .resizable()
                    .scaledToFit()
            }
        case .placeholder, .loading, .failed:
            imageText(for: image, at: index)
        }
    }

    private var inlineText: Text {
        content.components.enumerated().reduce(Text("")) { result, item in
            let (index, component) = item

            switch component {
            case let .text(text):
                return result + Text(text)
            case let .image(image):
                return result + imageText(for: image, at: index)
            }
        }
    }

    private var accessibilityText: Text {
        content.components.enumerated().reduce(Text("")) { result, item in
            let (index, component) = item

            switch component {
            case let .text(text):
                return result + Text(text)
            case let .image(image):
                let phase = imagePhases[index] ?? .placeholder
                let labelText = Self.accessibilityLabel(for: image, phase: phase)
                var label = AttributedString(labelText)
                label.link = image.link
                return result + Text(label)
            }
        }
    }

    private var imageRequests: [ImageRequest] {
        content.components.enumerated().compactMap { index, component in
            guard case let .image(image) = component else {
                return nil
            }

            return ImageRequest(
                componentIndex: index,
                request: FlatMarkImageRequest.resolve(
                    url: image.url,
                    policy: context.imageURLPolicy
                )
            )
        }
    }

    private var imageTaskID: ImageTaskID {
        ImageTaskID(
            requests: imageRequests,
            loaderConfigurationID: context.imageLoader?.configurationID
        )
    }

    private func imageText(for image: FlatMarkRenderImage, at index: Int) -> Text {
        switch imagePhases[index] ?? .placeholder {
        case .placeholder:
            labeledImageText(systemName: "photo", label: image.accessibleLabel)
        case .loading:
            labeledImageText(systemName: "clock", label: image.accessibleLabel)
        case .loaded:
            Text(image.accessibleLabel)
        case .failed:
            labeledImageText(
                systemName: "exclamationmark.triangle",
                label: image.accessibleLabel
            )
        }
    }

    static func accessibilityLabel(
        for image: FlatMarkRenderImage,
        phase: ImagePhase
    ) -> String {
        switch phase {
        case .placeholder:
            "\(image.accessibleLabel), not loaded"
        case .loading:
            "\(image.accessibleLabel), loading"
        case .loaded:
            image.accessibleLabel
        case .failed:
            "\(image.accessibleLabel), failed to load"
        }
    }

    private func labeledImageText(systemName: String, label: String) -> Text {
        Text(Image(systemName: systemName)) + Text(" \(label)")
    }

    private func loadImages() async {
        let imageLoader = context.imageLoader
        imagePhases = Dictionary(uniqueKeysWithValues: imageRequests.map { imageRequest in
            let phase: ImagePhase = if imageLoader == nil {
                .placeholder
            } else if case .allowed = imageRequest.request {
                .loading
            } else {
                .failed
            }

            return (imageRequest.componentIndex, phase)
        })

        guard let imageLoader else {
            return
        }

        await withTaskGroup(of: ImageLoadResult.self) { group in
            for imageRequest in imageRequests {
                guard case let .allowed(url) = imageRequest.request else {
                    continue
                }

                group.addTask {
                    do {
                        try Task.checkCancellation()
                        let image = try await imageLoader.load(url)
                        return .loaded(
                            componentIndex: imageRequest.componentIndex,
                            image: image
                        )
                    } catch is CancellationError {
                        return .cancelled(componentIndex: imageRequest.componentIndex)
                    } catch {
                        return .failed(componentIndex: imageRequest.componentIndex)
                    }
                }
            }

            for await result in group {
                guard !Task.isCancelled else {
                    return
                }

                switch result {
                case let .loaded(index, image):
                    imagePhases[index] = .loaded(image)
                case let .failed(index):
                    imagePhases[index] = .failed
                case let .cancelled(index):
                    imagePhases[index] = .placeholder
                }
            }
        }
    }
}

private extension FlatMarkInlineView.ImagePhase {
    var isLoaded: Bool {
        if case .loaded = self {
            return true
        }

        return false
    }
}

private extension FlatMarkRenderInlineContent.Component {
    var isLinkedImage: Bool {
        guard case let .image(image) = self else {
            return false
        }

        return image.link != nil
    }
}

private extension AttributedString {
    enum InlineFragment {
        case text(AttributedString)
        case lineBreak
    }

    var inlineFragments: [InlineFragment] {
        var fragments: [InlineFragment] = []
        var fragmentStart = startIndex

        for index in characters.indices where characters[index].isNewline {
            if fragmentStart < index {
                fragments.append(.text(AttributedString(self[fragmentStart..<index])))
            }
            fragments.append(.lineBreak)
            fragmentStart = characters.index(after: index)
        }

        if fragmentStart < endIndex {
            fragments.append(.text(AttributedString(self[fragmentStart..<endIndex])))
        }

        return fragments
    }
}

#Preview("Inline Markdown Image") {
    FlatMarkView(
        markdown: "Before ![diagram](image.png) after.",
        baseURL: URL(string: "https://example.com/"),
        imageLoader: FlatMarkImageLoader(configurationID: previewImageLoaderConfigurationID) { _ in
            Image(systemName: "photo.on.rectangle.angled")
        }
    )
    .padding()
}

private let previewImageLoaderConfigurationID = UUID()

#Preview("Markdown Table") {
    FlatMarkTableView(
        table: FlatMarkRenderTable(
            header: [
                .init(id: .init(path: [0, 0, 0]), content: "Owner", colspan: 1),
                .init(id: .init(path: [0, 0, 1]), content: "Status", colspan: 1),
                .init(id: .init(path: [0, 0, 2]), content: "Notes", colspan: 1),
            ],
            rows: [
                .init(
                    id: .init(path: [0, 1, 0]),
                    cells: [
                        .init(id: .init(path: [0, 1, 0, 0]), content: "Noemi", colspan: 2),
                        .init(
                            id: .init(path: [0, 1, 0, 2]),
                            content: "Confirm the release notes before publishing. Some very long text. Confirm the release notes before publishing. Some very long text. Confirm the release notes before publishing. Some very long text.",
                            colspan: 1
                        ),
                    ]
                ),
                .init(
                    id: .init(path: [0, 1, 1]),
                    cells: [
                        .init(id: .init(path: [0, 1, 1, 0]), content: "Alex", colspan: 1),
                        .init(id: .init(path: [0, 1, 1, 1]), content: "In progress", colspan: 1),
                        .init(id: .init(path: [0, 1, 1, 2]), content: "Waiting for review.", colspan: 1),
                    ]
                ),
            ]
        ),
        context: .readOnly
    )
    .padding()
}
