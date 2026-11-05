@testable import FlatMark
import FlatMarkFixtures
import Foundation
import Observation
import SwiftUI
import Testing

#if os(macOS)
    import AppKit
#else
    import UIKit
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
            phase: .loaded(loadedFixtureImage())
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
            phase: .loaded(loadedFixtureImage())
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
        // Custom text also contributes to image-description wording.
        let custom = FlatMarkUnsupportedContentPolicy.custom(inline: { _ in AttributedString("Replacement") })
        let phases: [(FlatMarkInlineView.ImagePhase, String)] = [
            (.placeholder, ", not loaded"),
            (.loading, ", loading"),
            (.loaded(loadedFixtureImage()), ""),
            (.failed, ", failed to load"),
        ]
        for (phase, suffix) in phases {
            #expect(FlatMarkInlineView.accessibilityLabel(
                for: image, phase: phase, policy: .omit
            ) == "before x after" + suffix)
            #expect(FlatMarkInlineView.accessibilityLabel(
                for: image, phase: phase, policy: .literal
            ) == "before <u>x</u> after" + suffix)
            #expect(FlatMarkInlineView.accessibilityLabel(
                for: image, phase: phase, policy: custom
            ) == "before ReplacementxReplacement after" + suffix)
            // A description made entirely of custom output keeps that wording.
            #expect(FlatMarkInlineView.accessibilityLabel(
                for: erased, phase: phase, policy: custom
            ) == "ReplacementReplacement" + suffix)
        }
    }

    #if os(macOS)
        /// Custom image-description text does not change supported image loading.
        @Test
        func `composes custom image description text and keeps the image loader`() async throws {
            let loads = FlatMarkRecordedImageLoads()
            let recorder = BlockPayloadRecorder()
            let hosted = await mountTestView(FlatMarkView(
                markdown: "![before <u>x</u> after](image.png)",
                baseURL: URL(string: "https://example.com/"),
                imageLoader: FlatMarkImageLoader(configurationID: UUID()) { url in
                    await loads.record(url)
                    return loadedFixtureImage()
                },
                unsupportedContentPolicy: .custom(inline: { payload in
                    recorder.payloads.append(payload)
                    return AttributedString("Replacement")
                })
            ))
            defer { hosted.close() }
            try await waitForImage(in: loads)

            // The loader request confirms the supported image survives the text replacement.
            #expect(loads.urls == [try #require(URL(string: "https://example.com/image.png"))])
            #expect(hosted.showsContent)
            #expect(Set(recorder.payloads) == ["<u>", "</u>"])

            let control = BlockPayloadRecorder()
            let inlineHosted = await mountTestView(FlatMarkView(
                markdown: "before <u>x</u> after",
                unsupportedContentPolicy: .custom(inline: { payload in
                    control.payloads.append(payload)
                    return AttributedString("Replacement")
                })
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
                    await expectImageLoad(in: spy)
                } else {
                    await settleRendering()
                }
                #expect(model.unsupportedContentPolicy.plainText(for: content) == "before <u>x</u> after")

                model.unsupportedContentPolicy = .omit
                await settleRendering()
                #expect(model.unsupportedContentPolicy.plainText(for: content) == "before x after")
                #expect(await spy.loadedURLs.count == (usesLoader ? 1 : 0))

                model.unsupportedContentPolicy = .literal
                await settleRendering()
                #expect(model.unsupportedContentPolicy.plainText(for: content) == "before <u>x</u> after")
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
                        return loadedFixtureImage()
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

        /// The control for every enlarged-text case below.
        ///
        /// macOS body text does not scale from `dynamicTypeSize` alone — the Recipe Lab fixture applies a
        /// font-size override for the same reason — so a mounted case that wants bigger text has to ask
        /// for it explicitly. This proves the override the cases below rely on really does change the
        /// effective size: a pair of variants that came out equal is then a layout failure rather than an
        /// override that did nothing. A font override is not system Dynamic Type or VoiceOver
        /// verification.
        @Test
        func `font size override changes the effective size of mounted text`() {
            let wording = "A long introduction explains the diagram and gives enough context to wrap naturally"
            let body = fittedSize(of: Text(wording), width: flowColumnWidth, textSize: .body)
            let enlarged = fittedSize(of: Text(wording), width: flowColumnWidth, textSize: .enlarged)

            #expect(body.width > 0)
            #expect(body.height > 0)
            #expect(
                enlarged.height >= body.height * 1.5,
                "enlarged text measured \(enlarged.height)pt against \(body.height)pt: the override did nothing"
            )
        }

        @Test
        func `linked image flow wraps inside its column at enlarged effective text sizes`() async throws {
            let textBeforeImage = "A long introduction explains the diagram and gives enough context to wrap naturally"
            let textAfterImage = "while the remaining explanation continues after it without becoming a narrow column."
            // Absolute destinations preserve image navigation in this fixture.
            let linkedImage = "[![Diagram](https://example.com/image.png)](https://example.com/details)"
            let document = FlatMarkRenderProjector.project(
                markdown: "\(textBeforeImage) \(linkedImage) \(textAfterImage)"
            )
            let linkedContent = try #require(paragraphContent(in: document))

            #if os(macOS)
            #expect(FlatMarkInlineView(content: linkedContent, context: .readOnly).renderingMode == .linkedImageFlow)
            #endif

            let bodyHeight = fittedSize(of: linkedContent, width: flowColumnWidth, textSize: .body).height
            let enlargedHeight = fittedSize(of: linkedContent, width: flowColumnWidth, textSize: .enlarged).height

            // This document really does take more room once text is enlarged, so the cases below cannot
            // pass with both variants rendered at one effective size.
            #expect(enlargedHeight > bodyHeight)

            for textSize in [MountedTextSize.body, .enlarged] {
                // Read from the view's own drawing rather than from what the layout reported, so a line
                // that ran past the column is caught whether or not the layout admitted it.
                let drawn = try await waitForFlowInk(of: linkedContent, textSize: textSize)

                // The whole drawing sat inside the capture, so the edges below are the drawing's own and
                // not the border of the region it was read back from.
                #expect(drawn.edgeInset > drawnGeometryTolerance)
                #expect(
                    drawn.frame.minX >= flowCaptureInset - drawnGeometryTolerance,
                    "\(textSize.name): flow drew from x=\(drawn.frame.minX), short of the capture inset"
                )
                #expect(
                    drawn.frame.maxX <= flowCaptureInset + flowColumnWidth + drawnGeometryTolerance,
                    "\(textSize.name): flow drew to x=\(drawn.frame.maxX), past the column's right edge"
                )
            }
        }

        @Test
        func `linked image flow preserves non-breaking spaces`() throws {
            let content = try #require(paragraphContent(in: FlatMarkRenderProjector.project(
                markdown: "A&nbsp;B [![x](https://example.com/image.png)](https://example.com/details)"
            )))
            #expect(content.plainText.contains("\u{00A0}"))

            #if os(macOS)
            let elements = FlatMarkInlineView.inlineElements(for: content, policy: .literal)
            #expect(elements.count == 2)
            #expect(elements[0].content == .text(AttributedString("A\u{00A0}B ")))
            #else
            let native = FlatMarkParagraphText.attributedText(for: content, policy: .literal,
                dynamicTypeSize: .large, layoutDirection: .leftToRight, alignment: .leading)
            #expect(native.string.hasPrefix("A\u{00A0}B "))
            #endif
        }

        @Test
        func `large raster is aspect fitted to the proposed paragraph width`() async throws {
            let spy = LoaderSpy()
            let content = imageContent(url: URL(string: "https://example.com/image.png"))
            let raster = try paintedFixtureRaster()
            let proposedWidth: CGFloat = 200
            // A 2:1 raster offered 200 points of width can only be drawn 200x100 while keeping its
            // shape, and it is far wider than the offer, so fitting it is the thing under test.
            let expectedFittedSize = CGSize(
                width: proposedWidth,
                height: proposedWidth * fixtureRasterSize.height / fixtureRasterSize.width
            )
            let hostingView = NSHostingView(rootView: FlatMarkInlineView(
                content: content,
                context: FlatMarkRenderContext(
                    imageLoader: FlatMarkImageLoader(configurationID: UUID()) { url in
                        await spy.record(url)
                        return raster
                    },
                    imageURLPolicy: .webOnly
                )
            )
            .frame(width: proposedWidth, alignment: .leading))

            // The capture is a fixed frame larger than any correctly fitted image, and not the size
            // the hosting view would choose for itself: a container that shrinks to its own content
            // clips an oversized image to exactly the geometry this test is looking for.
            hostingView.sizingOptions = []
            hostingView.frame = CGRect(origin: .zero, size: fixtureCaptureSize)

            try await withTemporaryWindow(hosting: hostingView) {
                await expectImageLoad(in: spy)

                // Measured from the fixture's own drawn pixels, so these read the image itself rather
                // than the space around it.
                let drawn = try await waitForDrawn(.fixtureRaster, in: hostingView)

                #expect(await spy.loadedURLs == [URL(string: "https://example.com/image.png")!])
                #expect(drawn.frame.width > 0)
                #expect(drawn.frame.height > 0)
                #expect(
                    abs(drawn.frame.width - expectedFittedSize.width) <= drawnGeometryTolerance,
                    "fitted width measured \(drawn.frame.width)pt, expected \(expectedFittedSize.width)pt"
                )
                #expect(
                    abs(drawn.frame.height - expectedFittedSize.height) <= drawnGeometryTolerance,
                    "fitted height measured \(drawn.frame.height)pt, expected \(expectedFittedSize.height)pt"
                )
                // The whole raster sat inside the capture, so the edges above were the image's own
                // and not the border of the region it was read back from.
                #expect(drawn.edgeInset > drawnGeometryTolerance)
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
                #expect(await spy.loadedURLs.isEmpty)

                model.loaderConfigurationID = firstConfigurationID
                await expectImageLoad(in: spy)
                #expect(await spy.loadedURLs.count == 1)

                model.unrelatedState.toggle()
                await settleRendering()
                #expect(await spy.loadedURLs.count == 1)

                model.loaderConfigurationID = UUID()
                await expectImageLoad(in: spy)
                #expect(await spy.loadedURLs.count == 2)

                model.loaderConfigurationID = nil
                await settleRendering()
                #expect(await spy.loadedURLs == [
                    URL(string: "https://example.com/image.png")!,
                    URL(string: "https://example.com/image.png")!,
                ])
            }
        }

        /// The package lane checks throwing completion; ticket 06 observes the resulting failure state.
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
                        return try await gate.fail()
                    },
                    imageURLPolicy: .webOnly
                )
            ))
            hostingView.frame = CGRect(x: 0, y: 0, width: 240, height: 80)

            try await withTemporaryWindow(hosting: hostingView) {
                await expectImageLoad(in: spy)
                await gate.release()
                for _ in 0 ..< 50 {
                    if await gate.didThrow {
                        break
                    }
                    await settleRendering()
                }
                // Ticket 06 verifies the resulting failure pixels with a real throwing loader.
                #expect(await gate.didThrow)
                #expect(await spy.loadedURLs == [URL(string: "https://example.com/image.png")!])
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
                            return loadedFixtureImage()
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
                await expectImageLoad(in: spy)

                hostingView.rootView = FlatMarkInlineView(
                    content: content,
                    context: .readOnly
                )

                await expectImageLoadCancellation(in: spy)
                #expect(await spy.cancellationCount == 1)
            }
        }
    #endif
}

// MARK: - ImageLoaderTestError

private enum ImageLoaderTestError: Error {
    case failed
}

// MARK: - SuspensionGate

private actor SuspensionGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isReleased = false
    private(set) var didThrow = false

    func fail() throws -> NativeImage {
        didThrow = true
        throw ImageLoaderTestError.failed
    }

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
    /// Measures effective-size controls for the surviving drawn-width checks.
    @MainActor
    private func fittedSize<V: View>(
        of view: V,
        width: CGFloat,
        textSize: MountedTextSize
    ) -> CGSize {
        NSHostingController(rootView: view
            .environment(\.dynamicTypeSize, textSize.dynamicTypeSize)
            .font(.system(size: textSize.fontSize)))
        .sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
    }

    @MainActor
    private func fittedSize(
        of content: FlatMarkRenderInlineContent,
        width: CGFloat,
        textSize: MountedTextSize
    ) -> CGSize {
        fittedSize(of: FlatMarkInlineView(
            content: content,
            context: .readOnly
        ), width: width, textSize: textSize)
    }

    @MainActor
    private func withTemporaryWindow<Content: View, Result>(
        hosting hostingView: NSHostingView<Content>,
        operation: () async throws -> Result
    ) async rethrows -> Result {
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
            let result = try await operation()
            await tearDown(window)
            return result
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
                    return loadedFixtureImage(symbolName: configurationID == model.firstConfigurationID
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

    /// Consumes one host loader invocation, whenever it arrived, then lets SwiftUI render what it
    /// returned.
    ///
    /// Swift Testing owns the count: the loader confirms through ``LoaderSpy``, so a load that never
    /// arrives is reported against this expectation rather than against a polling bound. The spy
    /// retains an invocation that arrived while nothing was armed, so triggering the load and then
    /// waiting for it is as valid as the other way round.
    @MainActor
    private func expectImageLoad(in spy: LoaderSpy) async {
        await confirmation("the host loader is invoked", expectedCount: 1) { loaded in
            await spy.expectLoad(confirmedBy: loaded)
            await spy.awaitExpectation(deadline: .seconds(2))
        }

        await settleRendering()
    }

    /// Consumes one reported cancellation of the mounted view's image request, whenever it arrived,
    /// then settles rendering.
    @MainActor
    private func expectImageLoadCancellation(in spy: LoaderSpy) async {
        await confirmation("the image request is cancelled", expectedCount: 1) { cancelled in
            await spy.expectCancellation(confirmedBy: cancelled)
            await spy.awaitExpectation(deadline: .seconds(2))
        }

        await settleRendering()
    }

    /// Gives SwiftUI the run-loop turns a state change needs before a capture reflects it. Nothing in
    /// Swift Testing observes a render pass, so this stays a settle rather than a callback expectation.
    @MainActor
    private func settleRendering() async {
        for _ in 0 ..< 3 {
            await Task.yield()
        }
        try? await Task.sleep(for: .milliseconds(20))
    }

    // MARK: - MountedTextSize

    /// An effective mounted text size.
    ///
    /// macOS does not scale body text from `dynamicTypeSize` alone — the Recipe Lab fixture applies a
    /// font-size override for the same reason — so a layout case that wants bigger text has to ask for
    /// it. The Dynamic Type environment value is carried because the fixture carries one; the font size
    /// is what changes the glyphs. Neither is system Dynamic Type or VoiceOver verification.
    private struct MountedTextSize {
        let name: String
        let dynamicTypeSize: DynamicTypeSize
        let fontSize: CGFloat

        static var body: MountedTextSize {
            MountedTextSize(name: "body", dynamicTypeSize: .large, fontSize: 13)
        }

        static var enlarged: MountedTextSize {
            MountedTextSize(name: "enlarged", dynamicTypeSize: .accessibility3, fontSize: 28)
        }
    }

    // MARK: - Drawn content observation

    /// Exactly 2:1, and many times wider than the width it is fitted into.
    private let fixtureRasterSize = NSSize(width: 1000, height: 500)

    /// The raster capture region: larger than any correctly fitted image, so an oversized draw shows up
    /// as oversized instead of being clipped into the size the test is looking for.
    private let fixtureCaptureSize = CGSize(width: 320, height: 240)

    /// The column the flow cases offer their document.
    private let flowColumnWidth: CGFloat = 180

    /// The flow capture region: wider and taller than any correctly wrapped flow at the tested sizes, so
    /// a line that ran past the column reads as ink reaching the capture edge instead of being clipped
    /// into looking wrapped.
    private let flowInkCaptureSize = CGSize(width: 320, height: 700)

    /// The gap between the capture's edge and the column, so ink flush with the capture edge always means
    /// the drawing was clipped rather than that the column simply starts where the capture starts.
    private let flowCaptureInset: CGFloat = 20

    /// A captured pixel belongs to the fixture when green dominates it. Green is the middle byte of a
    /// 32-bit pixel in either byte order, and nothing else this view can draw — grayscale text and
    /// placeholder symbols, a tinted link — is green-dominant.
    private let fixtureChannelThreshold: UInt8 = 128

    /// How many settle passes to allow for drawn output to reach the screen before concluding it never
    /// drew.
    private let drawnWaitAttempts = 50

    /// The allowance for geometry read out of pixels: a capture is only as fine as a device pixel,
    /// which is a whole point at a 1x backing scale, and the outermost drawn pixels blend with the
    /// transparent capture, so a measured edge can sit up to a point early or late.
    private let drawnGeometryTolerance: CGFloat = 2

    /// Which drawn pixels a measurement should count.
    private enum DrawnContent: CustomStringConvertible {
        /// The green fixture raster, so a placeholder or a line of text cannot be read as the image.
        case fixtureRaster

        /// Every pixel with coverage at all: text, symbols, and links.
        case ink

        var description: String {
            switch self {
            case .fixtureRaster:
                "the fixture raster"
            case .ink:
                "drawn ink"
            }
        }

        func contains(channels: (red: UInt8, green: UInt8, blue: UInt8), alpha: UInt8) -> Bool {
            switch self {
            case .fixtureRaster:
                channels.red <= fixtureChannelThreshold
                    && channels.green > fixtureChannelThreshold
                    && channels.blue <= fixtureChannelThreshold
            case .ink:
                alpha > 0
            }
        }
    }

    /// Where a mounted view's own drawing landed, measured from its pixels.
    private struct DrawnRegion {
        /// The drawn pixels, in points within the capture.
        let frame: CGRect
        /// The gap, in points, from the drawn pixels to the nearest edge of the capture. Zero means
        /// the capture clipped the drawing, so `frame` is a floor rather than a measurement.
        let edgeInset: CGFloat
    }

    // MARK: - MountedDrawingObservationError

    private enum MountedDrawingObservationError: Error {
        /// The capture lane gave nothing readable, so no claim about drawn output is available.
        case captureUnavailable(bounds: CGRect, pixelsWide: Int, pixelsHigh: Int)

        /// The capture lane worked throughout and the view kept rendering, but what the test came for
        /// never appeared in it.
        case contentNotDrawn(DrawnContent, attempts: Int)
    }

    /// A real raster, painted rather than only sized: an `NSImage(size:)` with no representation
    /// reports a size while drawing nothing, which is what let a collapsed image pass for a fitted one.
    private func paintedFixtureRaster() throws -> NSImage {
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(fixtureRasterSize.width),
            pixelsHigh: Int(fixtureRasterSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        let bytes = try #require(bitmap.bitmapData)
        var row = [UInt8](repeating: 0, count: bitmap.bytesPerRow)
        for column in 0 ..< bitmap.pixelsWide {
            let pixel = column * bitmap.samplesPerPixel
            row[pixel] = 0
            row[pixel + 1] = 255
            row[pixel + 2] = 0
            row[pixel + 3] = 255
        }

        row.withUnsafeBufferPointer { rowBytes in
            for line in 0 ..< bitmap.pixelsHigh {
                memcpy(bytes + line * bitmap.bytesPerRow, rowBytes.baseAddress!, bitmap.bytesPerRow)
            }
        }

        let raster = NSImage(size: fixtureRasterSize)
        raster.addRepresentation(bitmap)
        return raster
    }

    /// Polls the mounted view for its own drawing of `content`, because a loader callback only says an
    /// image was handed to SwiftUI, not that the result was committed and drawn.
    ///
    /// The observation is the drawing itself, so a capture lane that gives nothing, a view that draws
    /// everything except what is under test, and a view that never settles are three separate failures
    /// rather than a geometry check that was never given anything to measure. The bound keeps output
    /// that never draws from hanging the suite.
    @MainActor
    private func waitForDrawn<V: View>(
        _ content: DrawnContent,
        in hostingView: NSHostingView<V>
    ) async throws -> DrawnRegion {
        var attempt = 0
        while attempt < drawnWaitAttempts {
            attempt += 1
            if let drawn = try drawnRegion(of: hostingView, containing: content) {
                return drawn
            }

            await settleRendering()
        }

        throw MountedDrawingObservationError.contentNotDrawn(content, attempts: attempt)
    }

    /// Mounts an inline flow at ``flowColumnWidth`` inside the wider ``flowInkCaptureSize`` and returns
    /// where the view's own drawing landed.
    ///
    /// The capture is a fixed frame rather than the size the hosting view would choose for itself: a
    /// container that shrinks to its own content clips a line that ran past the column into exactly the
    /// shape a test looking for overflow would read as correct.
    @MainActor
    private func waitForFlowInk(
        of content: FlatMarkRenderInlineContent,
        textSize: MountedTextSize
    ) async throws -> DrawnRegion {
        let hostingView = NSHostingView(rootView: FlatMarkInlineView(
            content: content,
            context: .readOnly
        )
        .frame(width: flowColumnWidth, alignment: .leading)
        .padding(flowCaptureInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.dynamicTypeSize, textSize.dynamicTypeSize)
        .font(.system(size: textSize.fontSize)))
        hostingView.sizingOptions = []
        hostingView.frame = CGRect(origin: .zero, size: flowInkCaptureSize)

        return try await withTemporaryWindow(hosting: hostingView) {
            try await waitForDrawn(.ink, in: hostingView)
        }
    }

    /// Reads the mounted view's drawing back, returning where the pixels of `content` landed, or `nil`
    /// when a working capture holds none of them.
    @MainActor
    private func drawnRegion<V: View>(
        of hostingView: NSHostingView<V>,
        containing content: DrawnContent
    ) throws -> DrawnRegion? {
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()

        let bounds = hostingView.bounds
        let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: bounds)
        guard bounds.width > 0, bounds.height > 0, let bitmap else {
            throw MountedDrawingObservationError.captureUnavailable(
                bounds: bounds,
                pixelsWide: bitmap?.pixelsWide ?? 0,
                pixelsHigh: bitmap?.pixelsHigh ?? 0
            )
        }

        hostingView.cacheDisplay(in: bounds, to: bitmap)

        let bytes = bitmap.bitmapData
        guard bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0,
              bitmap.samplesPerPixel == 4, bitmap.bitsPerSample == 8, !bitmap.isPlanar,
              let bytes
        else {
            throw MountedDrawingObservationError.captureUnavailable(
                bounds: bounds,
                pixelsWide: bitmap.pixelsWide,
                pixelsHigh: bitmap.pixelsHigh
            )
        }

        var minX = bitmap.pixelsWide
        var minY = bitmap.pixelsHigh
        var maxX = -1
        var maxY = -1
        for line in 0 ..< bitmap.pixelsHigh {
            let rowBytes = line * bitmap.bytesPerRow
            for column in 0 ..< bitmap.pixelsWide {
                let pixel = rowBytes + column * bitmap.samplesPerPixel
                guard content.contains(
                    channels: (bytes[pixel], bytes[pixel + 1], bytes[pixel + 2]),
                    alpha: bytes[pixel + 3]
                ) else {
                    continue
                }

                minX = min(minX, column)
                minY = min(minY, line)
                maxX = max(maxX, column)
                maxY = max(maxY, line)
            }
        }

        guard minX <= maxX, minY <= maxY else {
            return nil
        }

        let pointsPerDevicePixel = bounds.width / CGFloat(bitmap.pixelsWide)
        let frame = CGRect(
            x: CGFloat(minX) * pointsPerDevicePixel,
            y: CGFloat(minY) * pointsPerDevicePixel,
            width: CGFloat(maxX - minX + 1) * pointsPerDevicePixel,
            height: CGFloat(maxY - minY + 1) * pointsPerDevicePixel
        )
        let edgeInset = min(
            CGFloat(minX),
            CGFloat(minY),
            CGFloat(bitmap.pixelsWide - 1 - maxX),
            CGFloat(bitmap.pixelsHigh - 1 - maxY)
        ) * pointsPerDevicePixel

        return DrawnRegion(frame: frame, edgeInset: edgeInset)
    }
#endif

/// The native image a test loader returns when the case reads the request rather than the pixels.
private func loadedFixtureImage(symbolName: String = "photo") -> NativeImage {
    #if os(macOS)
        NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) ?? NSImage()
    #else
        UIImage(systemName: symbolName) ?? UIImage()
    #endif
}

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
