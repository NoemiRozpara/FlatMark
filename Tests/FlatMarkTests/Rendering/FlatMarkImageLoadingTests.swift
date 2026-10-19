@testable import FlatMark
import FlatMarkFixtures
import Foundation
import Observation
import SwiftUI
import Testing

#if os(macOS)
    import AppKit
#endif

// MARK: - FlatMarkImageLoadingTests

@MainActor
struct FlatMarkImageLoadingTests {
    @Test
    func `resolves relative image sources with the link base URL rules`() throws {
        let baseURL = try #require(URL(string: "https://example.com/docs/readme.md"))
        let document = FlatMarkRenderProjector.project(
            markdown: "[Guide](guide.html) ![Diagram](images/diagram.png)",
            baseURL: baseURL
        )
        let content = try #require(paragraphContent(in: document))
        let image = try #require(content.components.compactMap(renderImage).first)

        #expect(run(containing: "Guide", in: content)?.link == URL(
            string: "https://example.com/docs/guide.html"
        ))
        #expect(image.url == URL(string: "https://example.com/docs/images/diagram.png"))
        #expect(try FlatMarkImageRequest.resolve(
            url: image.url,
            policy: .webOnly
        ) == .allowed(#require(URL(string: "https://example.com/docs/images/diagram.png"))))
    }

    @Test
    func `uses an accessible generic label when alt text is missing`() throws {
        let document = FlatMarkRenderProjector.project(markdown: "![](https://example.com/image.png)")
        let content = try #require(paragraphContent(in: document))
        let image = try #require(content.components.compactMap(renderImage).first)

        #expect(image.altContent.components.isEmpty)
        #expect(FlatMarkUnsupportedContentPolicy.literal.imageLabel(for: image) == "Image")
    }

    @Test
    func `describes each image loading phase to assistive technology`() {
        let image = FlatMarkRenderImage(url: nil, altText: "Diagram")
        let imageWithoutAltText = FlatMarkRenderImage(url: nil, altText: "")

        #expect(FlatMarkInlineView.accessibilityLabel(
            for: image,
            phase: .placeholder
        ) == "Diagram, not loaded")
        #expect(FlatMarkInlineView.accessibilityLabel(
            for: image,
            phase: .loading
        ) == "Diagram, loading")
        #expect(FlatMarkInlineView.accessibilityLabel(
            for: image,
            phase: .loaded(Image(systemName: "photo"))
        ) == "Diagram")
        #expect(FlatMarkInlineView.accessibilityLabel(
            for: image,
            phase: .failed
        ) == "Diagram, failed to load")
        #expect(FlatMarkInlineView.accessibilityLabel(
            for: imageWithoutAltText,
            phase: .loading
        ) == "Image, loading")
        #expect(FlatMarkInlineView.accessibilityLabel(
            for: imageWithoutAltText,
            phase: .loaded(Image(systemName: "photo"))
        ) == "Image")
        #expect(FlatMarkInlineView.accessibilityLabel(
            for: imageWithoutAltText,
            phase: .failed
        ) == "Image, failed to load")
    }

    @Test
    func `image description accessibility follows policy in every loading phase`() throws {
        let content = try #require(paragraphContent(in: FlatMarkRenderProjector.project(
            markdown: "![before <u>x</u> after](image.png)"
        )))
        let image = try #require(content.components.compactMap(renderImage).first)
        let erasedContent = try #require(paragraphContent(in: FlatMarkRenderProjector.project(
            markdown: "![<u></u>](image.png)"
        )))
        let erased = try #require(erasedContent.components.compactMap(renderImage).first)
        // A host view would be handed the same wording the literal policy prints; a `.custom` label
        // can only carry the text that stays supported.
        let custom = FlatMarkUnsupportedContentPolicy.custom(render: { _ in AnyView(Text("Replacement")) })
        let phases: [(FlatMarkInlineView.ImagePhase, String)] = [
            (.placeholder, ", not loaded"),
            (.loading, ", loading"),
            (.loaded(Image(systemName: "photo")), ""),
            (.failed, ", failed to load"),
        ]
        for (phase, suffix) in phases {
            #expect(FlatMarkInlineView.accessibilityLabel(
                for: image, phase: phase, policy: .omit
            ) == "before x after" + suffix)
            #expect(FlatMarkInlineView.accessibilityLabel(
                for: image, phase: phase, policy: .literal
            ) == "before <u>x</u> after" + suffix)
            // Supported wording a reader can reach survives; the part a host view would have owned
            // is simply absent, because no image label can contain a view.
            #expect(FlatMarkInlineView.accessibilityLabel(
                for: image, phase: phase, policy: custom
            ) == "before x after" + suffix)
            // A description that leaves no supported wording is the generic label, not an empty one.
            #expect(FlatMarkInlineView.accessibilityLabel(
                for: erased, phase: phase, policy: custom
            ) == "Image" + suffix)
        }
    }

    #if os(macOS)
        /// An image description is metadata, so mounting a document that only carries one dispatches
        /// nothing while the supported image itself keeps loading. The second mount is the positive
        /// control on the same recorder and hosting path.
        @Test
        func `mounts an image description without a host and keeps the image loader`() async throws {
            let loads = FlatMarkRecordedImageLoads()
            let recorder = BlockPayloadRecorder()
            let hosted = await mountTestView(FlatMarkView(
                markdown: "![before <u>x</u> after](image.png)",
                baseURL: URL(string: "https://example.com/"),
                imageLoader: FlatMarkImageLoader(configurationID: UUID()) { url in
                    await loads.record(url)
                    return Image(systemName: "photo.fill")
                },
                unsupportedContentPolicy: .custom { payload in
                    recorder.payloads.append(payload)
                    return AnyView(Text("Replacement"))
                }
            ))
            defer { hosted.close() }
            try await waitForImage(in: loads)

            // The URL the loader was asked for is both the record that the supported image is still
            // there and the readiness signal: nothing in this test fetches it, and a document whose
            // body never evaluated would have asked for nothing. An empty payload list then says the
            // description placed no host view anywhere, which is what a label of plain text must do.
            #expect(loads.urls == [try #require(URL(string: "https://example.com/image.png"))])
            #expect(hosted.showsContent)
            #expect(recorder.payloads.isEmpty)

            let control = BlockPayloadRecorder()
            let inlineHosted = await mountTestView(FlatMarkView(
                markdown: "before <u>x</u> after",
                unsupportedContentPolicy: .custom { payload in
                    control.payloads.append(payload)
                    return AnyView(Text("Replacement"))
                }
            ))
            defer { inlineHosted.close() }
            await settleMountedRendering()

            // The same host and recorder do reach the two inline nodes a document really carries, so
            // the empty set above is not a view that never rendered.
            #expect(Set(control.payloads) == ["<u>", "</u>"])
            #expect(inlineHosted.showsContent)
        }

        @Test(arguments: [false, true])
        func `switching image description policy restores wording without reloading`(usesLoader: Bool) async throws {
            let spy = LoaderSpy()
            let configurationID = UUID()
            let model = ImageLoaderTestModel(firstConfigurationID: configurationID, spy: spy)
            if usesLoader {
                model.loaderConfigurationID = configurationID
            }
            let content = try #require(paragraphContent(in: FlatMarkRenderProjector.project(
                markdown: "![before <u>x</u> after](https://example.com/image.png)"
            )))
            let hostingView = NSHostingView(rootView: ImageLoaderTestView(content: content, model: model))
            hostingView.frame = CGRect(x: 0, y: 0, width: 320, height: 80)
            try await withTemporaryWindow(hosting: hostingView) {
                if usesLoader {
                    await waitForLoadCount(1, in: spy)
                } else {
                    await settleRendering()
                }
                let literalPNG = try #require(renderedPNG(of: hostingView))

                model.unsupportedContentPolicy = .omit
                await settleRendering()
                let omittedPNG = try #require(renderedPNG(of: hostingView))
                #expect(await spy.loadedURLs.count == (usesLoader ? 1 : 0))
                if usesLoader {
                    #expect(omittedPNG == literalPNG)
                } else {
                    #expect(omittedPNG != literalPNG)
                }

                model.unsupportedContentPolicy = .literal
                await settleRendering()
                #expect(renderedPNG(of: hostingView) == literalPNG)
                #expect(await spy.loadedURLs.count == (usesLoader ? 1 : 0))
            }
        }

        @Test
        func `rejected image scheme does not invoke the loader`() async throws {
            let spy = LoaderSpy()
            let content = imageContent(url: URL(string: "file:///private/image.png"))
            let hostingView = NSHostingView(rootView: FlatMarkInlineView(
                content: content,
                context: FlatMarkRenderContext(
                    imageLoader: FlatMarkImageLoader(configurationID: UUID()) { url in
                        await spy.record(url)
                        return Image(systemName: "photo.fill")
                    },
                    imageURLPolicy: .webOnly
                )
            ))
            hostingView.frame = CGRect(x: 0, y: 0, width: 240, height: 80)

            try await withTemporaryWindow(hosting: hostingView) {
                await settleRendering()

                #expect(await spy.loadedURLs.isEmpty)
            }
        }

        @Test
        func `mixed linked image receives visible link presentation`() async throws {
            let linkedContent = try #require(paragraphContent(in: FlatMarkRenderProjector.project(
                markdown: "Before [![Diagram](image.png)](https://example.com/details) after."
            )))
            let unlinkedContent = try #require(paragraphContent(in: FlatMarkRenderProjector.project(
                markdown: "Before ![Diagram](image.png) after."
            )))

            #expect(await renderedPNG(of: linkedContent, width: 300) != renderedPNG(
                of: unlinkedContent,
                width: 300
            ))
        }

        @Test
        func `linked image flow remains finite at accessibility text sizes`() throws {
            let textBeforeImage = "A long introduction explains the diagram and gives enough context to wrap naturally"
            let textAfterImage = "while the remaining explanation continues after it without becoming a narrow column."
            let linkedContent = try #require(paragraphContent(in: FlatMarkRenderProjector.project(
                markdown: "\(textBeforeImage) [![Diagram](image.png)](details.html) \(textAfterImage)"
            )))
            let regularHeight = fittedHeight(
                of: linkedContent,
                width: 180,
                dynamicTypeSize: .xSmall
            )
            let accessibilityHeight = fittedHeight(
                of: linkedContent,
                width: 180,
                dynamicTypeSize: .accessibility5
            )

            #expect(regularHeight.isFinite)
            #expect(accessibilityHeight.isFinite)
            #expect(accessibilityHeight >= regularHeight)
        }

        @Test
        func `linked image flow preserves non-breaking spaces`() throws {
            let content = try #require(paragraphContent(in: FlatMarkRenderProjector.project(
                markdown: "A&nbsp;B [![x](image.png)](details.html)"
            )))
            #expect(content.plainText.contains("\u{00A0}"))

            let elements = FlatMarkInlineView.inlineElements(for: content, policy: .literal)

            #expect(elements.count == 2)
            #expect(elements[0].content == .text(AttributedString("A\u{00A0}B ")))
        }

        @Test
        func `large raster is aspect fitted to the proposed paragraph width`() async throws {
            let spy = LoaderSpy()
            let content = imageContent(url: URL(string: "https://example.com/image.png"))
            let raster = NSImage(size: NSSize(width: 1000, height: 500))
            let hostingView = NSHostingView(rootView: FlatMarkInlineView(
                content: content,
                context: FlatMarkRenderContext(
                    imageLoader: FlatMarkImageLoader(configurationID: UUID()) { url in
                        await spy.record(url)
                        return Image(nsImage: raster)
                    },
                    imageURLPolicy: .webOnly
                )
            )
            .frame(width: 200, alignment: .leading))

            try await withTemporaryWindow(hosting: hostingView) {
                await waitForLoadCount(1, in: spy)

                let fittedSize = hostingView.fittingSize

                #expect(await spy.loadedURLs == [URL(string: "https://example.com/image.png")!])
                #expect(fittedSize.width <= 200)
                #expect(fittedSize.height <= 100)
            }
        }

        @Test
        func `ordinary image matches native wrapping across dynamic type sizes`() throws {
            let textBeforeImage = "A long introduction wraps before the diagram"
            let textAfterImage = "and the explanation continues after it."
            let content = try #require(paragraphContent(in: FlatMarkRenderProjector.project(
                markdown: "\(textBeforeImage) ![Diagram](image.png) \(textAfterImage)"
            )))
            let nativeInlineText = Text("\(textBeforeImage) ")
                + Text(Image(systemName: "photo"))
                + Text(" Diagram \(textAfterImage)")

            for dynamicTypeSize in [DynamicTypeSize.large, .accessibility3] {
                for width: CGFloat in [160, 240] {
                    #expect(fittedHeight(
                        of: content,
                        width: width,
                        dynamicTypeSize: dynamicTypeSize
                    ) == fittedHeight(
                        of: nativeInlineText,
                        width: width,
                        dynamicTypeSize: dynamicTypeSize
                    ))
                }
            }
        }

        @Test
        func `ordinary image matches native hard break layout`() throws {
            let content = try #require(paragraphContent(in: FlatMarkRenderProjector.project(
                markdown: "Before  \n![Diagram](image.png)  \nAfter"
            )))
            let nativeInlineText = Text("Before\n")
                + Text(Image(systemName: "photo"))
                + Text(" Diagram\nAfter")

            for dynamicTypeSize in [DynamicTypeSize.large, .accessibility3] {
                #expect(fittedHeight(
                    of: content,
                    width: 180,
                    dynamicTypeSize: dynamicTypeSize
                ) == fittedHeight(
                    of: nativeInlineText,
                    width: 180,
                    dynamicTypeSize: dynamicTypeSize
                ))
            }
        }

        @Test
        func `reloads only when the host loader configuration changes`() async throws {
            let spy = LoaderSpy()
            let firstConfigurationID = UUID()
            let model = ImageLoaderTestModel(
                firstConfigurationID: firstConfigurationID,
                spy: spy
            )
            let content = FlatMarkRenderInlineContent(components: [
                .image(FlatMarkRenderImage(
                    url: URL(string: "https://example.com/image.png"),
                    altText: "Diagram"
                )),
            ])
            let hostingView = NSHostingView(rootView: ImageLoaderTestView(
                content: content,
                model: model
            ))
            hostingView.frame = CGRect(x: 0, y: 0, width: 240, height: 80)
            try await withTemporaryWindow(hosting: hostingView) {
                await settleRendering()
                let initialPlaceholder = try #require(renderedPNG(of: hostingView))
                #expect(await spy.loadedURLs.isEmpty)

                model.loaderConfigurationID = firstConfigurationID
                await waitForLoadCount(1, in: spy)
                let firstLoadedImage = try #require(renderedPNG(of: hostingView))

                model.unrelatedState.toggle()
                await settleRendering()
                #expect(await spy.loadedURLs.count == 1)

                model.loaderConfigurationID = UUID()
                await waitForLoadCount(2, in: spy)
                let secondLoadedImage = try #require(renderedPNG(of: hostingView))

                model.loaderConfigurationID = nil
                await settleRendering()
                let resetPlaceholder = try #require(renderedPNG(of: hostingView))

                #expect(firstLoadedImage != initialPlaceholder)
                #expect(secondLoadedImage != firstLoadedImage)
                #expect(resetPlaceholder == initialPlaceholder)
                #expect(await spy.loadedURLs == [
                    URL(string: "https://example.com/image.png")!,
                    URL(string: "https://example.com/image.png")!,
                ])
            }
        }

        @Test
        func `generic loader error renders the failure state`() async throws {
            let spy = LoaderSpy()
            let gate = SuspensionGate()
            let content = imageContent(url: URL(string: "https://example.com/image.png"))
            let hostingView = NSHostingView(rootView: FlatMarkInlineView(
                content: content,
                context: FlatMarkRenderContext(
                    imageLoader: FlatMarkImageLoader(configurationID: UUID()) { url in
                        await spy.record(url)
                        await gate.wait()
                        throw ImageLoaderTestError.failed
                    },
                    imageURLPolicy: .webOnly
                )
            ))
            hostingView.frame = CGRect(x: 0, y: 0, width: 240, height: 80)

            try await withTemporaryWindow(hosting: hostingView) {
                await waitForLoadCount(1, in: spy)
                let loadingImage = try #require(renderedPNG(of: hostingView))

                await gate.release()
                await settleRendering()
                let failedImage = try #require(renderedPNG(of: hostingView))

                hostingView.rootView = FlatMarkInlineView(
                    content: imageContent(url: URL(string: "file:///private/image.png")),
                    context: FlatMarkRenderContext(
                        imageLoader: FlatMarkImageLoader(configurationID: UUID()) { _ in
                            Image(systemName: "photo.fill")
                        },
                        imageURLPolicy: .webOnly
                    )
                )
                await settleRendering()
                let expectedFailure = try #require(renderedPNG(of: hostingView))

                #expect(failedImage != loadingImage)
                #expect(failedImage == expectedFailure)
            }
        }

        @Test
        func `replacing the mounted view cancels its image request`() async throws {
            let spy = LoaderSpy()
            let content = imageContent(url: URL(string: "https://example.com/image.png"))
            let hostingView = NSHostingView(rootView: FlatMarkInlineView(
                content: content,
                context: FlatMarkRenderContext(
                    imageLoader: FlatMarkImageLoader(configurationID: UUID()) { url in
                        await spy.record(url)

                        do {
                            try await Task.sleep(for: .seconds(60))
                            return Image(systemName: "photo.fill")
                        } catch is CancellationError {
                            await spy.recordCancellation()
                            throw CancellationError()
                        }
                    },
                    imageURLPolicy: .webOnly
                )
            ))
            hostingView.frame = CGRect(x: 0, y: 0, width: 240, height: 80)

            try await withTemporaryWindow(hosting: hostingView) {
                await waitForLoadCount(1, in: spy)

                hostingView.rootView = FlatMarkInlineView(
                    content: content,
                    context: .readOnly
                )

                await waitForCancellation(in: spy)
                #expect(await spy.cancellationCount == 1)
            }
        }
    #endif
}

// MARK: - LoaderSpy

private actor LoaderSpy {
    private(set) var loadedURLs: [URL] = []
    private(set) var cancellationCount = 0

    func record(_ url: URL) {
        loadedURLs.append(url)
    }

    func recordCancellation() {
        cancellationCount += 1
    }
}

// MARK: - ImageLoaderTestError

private enum ImageLoaderTestError: Error {
    case failed
}

// MARK: - SuspensionGate

private actor SuspensionGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isReleased = false

    func wait() async {
        guard !isReleased else {
            return
        }

        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
        isReleased = true
        continuation?.resume()
        continuation = nil
    }
}

#if os(macOS)
    @MainActor
    private func fittedHeight(
        of content: FlatMarkRenderInlineContent,
        width: CGFloat,
        dynamicTypeSize: DynamicTypeSize = .accessibility3
    ) -> CGFloat {
        fittedHeight(of: FlatMarkInlineView(
            content: content,
            context: .readOnly
        ), width: width, dynamicTypeSize: dynamicTypeSize)
    }

    @MainActor
    private func fittedHeight<V: View>(
        of view: V,
        width: CGFloat,
        dynamicTypeSize: DynamicTypeSize = .accessibility3
    ) -> CGFloat {
        let hostingView = NSHostingView(rootView: view
            .environment(\.dynamicTypeSize, dynamicTypeSize)
            .frame(width: width, alignment: .leading))

        return hostingView.fittingSize.height
    }

    @MainActor
    private func renderedPNG(
        of content: FlatMarkRenderInlineContent,
        width: CGFloat
    ) async -> Data? {
        let hostingView = NSHostingView(rootView: FlatMarkInlineView(
            content: content,
            context: .readOnly
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading))
        hostingView.frame = CGRect(x: 0, y: 0, width: width, height: 44)
        await settleRendering()
        return renderedPNG(of: hostingView)
    }

    @MainActor
    private func withTemporaryWindow<Content: View>(
        hosting hostingView: NSHostingView<Content>,
        operation: () async throws -> Void
    ) async rethrows {
        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.contentView = hostingView

        do {
            try await operation()
            await tearDown(window)
        } catch {
            await tearDown(window)
            throw error
        }
    }

    @MainActor
    private func tearDown(_ window: NSWindow) async {
        window.orderOut(nil)
        window.contentView = nil
        window.close()
        await settleRendering()
    }

    private struct ImageLoaderTestView: View {
        let content: FlatMarkRenderInlineContent
        let model: ImageLoaderTestModel

        var body: some View {
            let _ = model.unrelatedState

            FlatMarkInlineView(
                content: content,
                context: FlatMarkRenderContext(
                    imageLoader: imageLoader,
                    imageURLPolicy: .webOnly,
                    unsupportedContentPolicy: model.unsupportedContentPolicy
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }

        private var imageLoader: FlatMarkImageLoader? {
            model.loaderConfigurationID.map { configurationID in
                FlatMarkImageLoader(configurationID: configurationID) { url in
                    await model.spy.record(url)
                    return Image(systemName: configurationID == model.firstConfigurationID
                        ? "1.circle.fill"
                        : "2.circle.fill")
                }
            }
        }
    }

    @MainActor
    @Observable
    private final class ImageLoaderTestModel {
        var loaderConfigurationID: UUID?
        var unrelatedState = false
        var unsupportedContentPolicy = FlatMarkUnsupportedContentPolicy.literal
        let spy: LoaderSpy
        let firstConfigurationID: UUID

        init(firstConfigurationID: UUID, spy: LoaderSpy) {
            loaderConfigurationID = nil
            self.spy = spy
            self.firstConfigurationID = firstConfigurationID
        }
    }

    @MainActor
    private func renderedPNG<V: View>(of hostingView: NSHostingView<V>) -> Data? {
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return nil
        }

        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        return bitmap.representation(using: .png, properties: [:])
    }

    @MainActor
    private func waitForLoadCount(_ expectedCount: Int, in spy: LoaderSpy) async {
        for _ in 0 ..< 100 {
            if await spy.loadedURLs.count == expectedCount {
                await settleRendering()
                return
            }

            try? await Task.sleep(for: .milliseconds(10))
        }

        Issue.record("Expected \(expectedCount) image loads")
    }

    @MainActor
    private func waitForCancellation(in spy: LoaderSpy) async {
        for _ in 0 ..< 100 {
            if await spy.cancellationCount > 0 {
                await settleRendering()
                return
            }

            try? await Task.sleep(for: .milliseconds(10))
        }

        Issue.record("Expected the image load to be cancelled")
    }

    @MainActor
    private func settleRendering() async {
        for _ in 0 ..< 3 {
            await Task.yield()
        }
        try? await Task.sleep(for: .milliseconds(20))
    }
#endif

private func paragraphContent(in document: FlatMarkRenderDocument) -> FlatMarkRenderInlineContent? {
    guard case let .paragraph(content) = document.blocks.first?.kind else {
        return nil
    }

    return content
}

private func imageContent(url: URL?) -> FlatMarkRenderInlineContent {
    FlatMarkRenderInlineContent(components: [
        .image(FlatMarkRenderImage(
            url: url,
            altText: "Diagram"
        )),
    ])
}

private func renderImage(
    from component: FlatMarkRenderInlineContent.Component
) -> FlatMarkRenderImage? {
    guard case let .image(image) = component else {
        return nil
    }

    return image
}

private func run(
    containing text: String,
    in content: FlatMarkRenderInlineContent
) -> AttributedString.Runs.Element? {
    content.components
        .lazy
        .compactMap(attributedText)
        .compactMap { attributedText in
            attributedText.runs.first { run in
                String(attributedText[run.range].characters).contains(text)
            }
        }
        .first
}

private func attributedText(
    from component: FlatMarkRenderInlineContent.Component
) -> AttributedString? {
    guard case let .text(text) = component else {
        return nil
    }

    return text
}
