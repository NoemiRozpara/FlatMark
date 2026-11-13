import SwiftUI

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

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
