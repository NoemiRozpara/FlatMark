import SwiftUI

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

// MARK: - FlatMarkDocumentView

struct FlatMarkDocumentView: View {
    let document: FlatMarkRenderDocument
    let context: FlatMarkRenderContext

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            FlatMarkBlocks(blocks: document.blocks, context: context)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - FlatMarkBlocks

private struct FlatMarkBlocks: View {
    let blocks: [FlatMarkRenderBlock]
    let context: FlatMarkRenderContext

    var body: some View {
        ForEach(visibleBlocks) { block in
            FlatMarkBlockView(
                block: block,
                context: context
            )
        }
    }

    /// The blocks this policy lays out, in document order.
    ///
    /// Omitted blocks are absent from the list rather than emptied, so the gap between two
    /// supported blocks matches the same document without the unsupported one.
    private var visibleBlocks: [FlatMarkRenderBlock] {
        blocks.filter { context.unsupportedContentPolicy.presents($0) }
    }
}

// MARK: - FlatMarkBlockView

struct FlatMarkBlockView: View {
    let block: FlatMarkRenderBlock
    let context: FlatMarkRenderContext

    var body: some View {
        switch block.kind {
        case let .paragraph(content):
            FlatMarkInlineView(content: content, context: context)

        case let .heading(level, content):
            FlatMarkInlineView(content: content, context: context, role: .heading(level: level))
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

                VStack(alignment: .leading, spacing: 16) {
                    FlatMarkBlocks(blocks: blocks, context: context)
                }
            }

        case let .list(entries):
            FlatMarkListView(entries: entries, context: context)

        case .thematicBreak:
            Divider()

        case let .table(table):
            FlatMarkTableView(table: table, context: context)

        case let .unsupported(content):
            FlatMarkInlineView(
                content: FlatMarkRenderInlineContent(components: [.unsupported(content)]),
                context: context
            )
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
                            adaptivelySized(inlineView(for: cell.content, role: .tableHeader))
                                .accessibilityAddTraits(.isHeader)
                        }
                    }

                    ForEach(table.rows) { row in
                        Divider()
                            .gridCellUnsizedAxes(.horizontal)
                            .background(.secondary)
                        GridRow {
                            ForEach(row.cells) { cell in
                                adaptivelySized(inlineView(for: cell.content, role: .body))
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

    private func inlineView(
        for content: FlatMarkRenderInlineContent,
        role: FlatMarkTextRole
    ) -> some View {
        FlatMarkInlineView(content: content, context: context, role: role)
    }
}

// MARK: - FlatMarkInlineView

struct FlatMarkInlineView: View {
    enum ImagePhase: Equatable {
        case placeholder
        case loading
        case loaded(NativeImage)
        case failed

        var accessibilitySuffix: String {
            switch self {
            case .placeholder: ", not loaded"
            case .loading: ", loading"
            case .loaded: ""
            case .failed: ", failed to load"
            }
        }

        var placeholderSymbolName: String? {
            switch self {
            case .placeholder: "photo"
            case .loading: "hourglass"
            case .loaded: nil
            case .failed: "exclamationmark.triangle"
            }
        }
    }

    private enum ImageLoadResult: Sendable {
        case loaded(componentIndex: Int, image: NativeImage)
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

    let content: FlatMarkRenderInlineContent
    let context: FlatMarkRenderContext
    var role: FlatMarkTextRole = .body

    @State private var imagePhases: [Int: ImagePhase] = [:]

    var body: some View {
        #if os(iOS)
        FlatMarkParagraphText(content: content, role: role, context: context, imagePhases: imagePhases)
            .task(id: imageTaskID) {
                await loadImages()
            }
        #else
        let text = FlatMarkParagraphText(content: content, role: role, context: context, imagePhases: imagePhases)
        text.alignmentGuide(.firstTextBaseline) { dimensions in
            text.firstBaseline(width: dimensions.width)
        }
        .task(id: imageTaskID) {
            await loadImages()
        }
        #endif
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

    @MainActor
    private func loadImages() async {
        guard !imageRequests.isEmpty else { return }
        let imageLoader = context.imageLoader
        imagePhases = Dictionary(uniqueKeysWithValues: imageRequests.map { imageRequest in
            let phase: ImagePhase =
                if imageLoader == nil {
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

#Preview("Inline Markdown Image") {
    FlatMarkView(
        markdown: "Before ![diagram](image.png) after.",
        baseURL: URL(string: "https://example.com/"),
        imageLoader: FlatMarkImageLoader(configurationID: previewImageLoaderConfigurationID) { _ in
            previewDiagramImage
        }
    )
    .padding()
}

private let previewImageLoaderConfigurationID = UUID()

/// Stands in for a host-loaded diagram so the preview needs no fetching.
private var previewDiagramImage: NativeImage {
    #if os(macOS)
        NSImage(systemSymbolName: "photo.on.rectangle.angled", accessibilityDescription: nil) ?? NSImage()
    #else
        UIImage(systemName: "photo.on.rectangle.angled") ?? UIImage()
    #endif
}

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
                        .init(id: .init(path: [0, 1, 0, 0]), content: "Alice", colspan: 2),
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
