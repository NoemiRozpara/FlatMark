import FlatMark
import Foundation
import SwiftUI
import Testing

#if SWIFT_PACKAGE
    @testable import FlatMarkFixtures
#endif

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

@Suite(.serialized)
@MainActor
struct FlatMarkRecipeIntegrationSnapshotTests {
    @Test func primary() async throws { try await capture(testName: #function) }
    @Test func dark() async throws { try await capture(dark: true, testName: #function) }
    @Test func enlarged() async throws { try await capture(enlarged: true, testName: #function) }

    private enum CaptureError: Error { case resource, readiness, crop }

    // Loader completion precedes geometry quiescence; contrast and reviewed pixels prove drawing.
    private final class Delivery: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        private var done = false
        var requests: Int { lock.withLock { count } }
        var completed: Bool { lock.withLock { done } }
        func start() { lock.withLock { count += 1 } }
        func complete() { lock.withLock { done = true } }
    }

    private final class Geometry {
        var size = CGSize.zero
        var ready = false
    }

    private func capture(dark: Bool = false, enlarged: Bool = false, testName: String) async throws {
        let environment = FlatMarkSnapshotEnvironment(
            captureSize: CGSize(width: enlarged ? 1200 : 640, height: enlarged ? 1100 : 2400), columnWidth: enlarged ? 1120 : 560, contentInset: 40,
            pixelScale: 2, appearance: dark ? .dark : .light, localeIdentifier: "en_US",
            layoutDirection: .leftToRight, textSize: enlarged ? .enlarged : .body
        )
        let loaded = try await render(environment: environment, fallback: false)
        let fallback = try await render(environment: environment, fallback: true)
        #if os(macOS)
            let sections = [("upperTitleImage", 0, 600), ("tasksQuotes", 600, 470),
                            ("tableCode", 1070, 425), ("lowerNotes", 1495, 425)]
        #else
            let sections = [("upperTitleImage", 0, 650), ("tasksQuotes", 650, 540),
                            ("tableCode", 1190, 505), ("lowerNotes", 1695, 550)]
        #endif
        #if os(macOS)
            let upperHeight = enlarged ? 750 : sections[0].2
        #else
            let upperHeight = enlarged ? 900 : sections[0].2
        #endif
        let upper = try crop(loaded, y: 0, height: upperHeight)
        let control = try crop(fallback, y: 0, height: upperHeight)
        #expect(bytes(upper) != bytes(control), "Loaded recipe must differ from leaf.fill control")
        print("Recipe \(testName): raster upper != leaf.fill control; requests=1 for each render")
        if enlarged {
            assertFlatMarkSnapshot(upper, suite: .recipe, named: "upperTitleImage", environment: environment, testName: testName)
        } else {
            for (name, y, height) in sections {
                assertFlatMarkSnapshot(try crop(loaded, y: y, height: height), suite: .recipe,
                                       named: name, environment: environment, testName: testName)
            }
        }
    }

    private func render(environment: FlatMarkSnapshotEnvironment, fallback: Bool) async throws -> FlatMarkSnapshotImage {
        let delivery = Delivery()
        let geometry = Geometry()
        let expectedURL = FlatMarkCustomFixtureModel.baseURL?.appending(path: "focaccia.jpeg")
        let loader = FlatMarkImageLoader(configurationID: UUID()) { url in
            delivery.start()
            defer { delivery.complete() }
            guard url == expectedURL else {
                throw CaptureError.resource
            }
            if fallback { return Image(systemName: "leaf.fill") }
            guard let resource = FlatMarkFixtureResources.focacciaURL else { throw CaptureError.resource }
            #if os(macOS)
                guard let image = NSImage(contentsOf: resource) else { throw CaptureError.resource }
                return Image(nsImage: image)
            #else
                guard let image = UIImage(contentsOfFile: resource.path) else { throw CaptureError.resource }
                return Image(uiImage: image)
            #endif
        }
        let document = FlatMarkView(
                markdown: FlatMarkRecipeSample.markdown,
                baseURL: FlatMarkCustomFixtureModel.baseURL,
                imageLoader: loader, unsupportedContentPolicy: .literal,
                linkActivationAction: { _ in .handled }, detectMentions: true,
                taskToggleAction: nil, taskMarker: .default
            )
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { geometry.size = $0 }
        let image = try await flatMarkSnapshotImage(
            of: Group {
                if environment.textSize == .enlarged {
                    ScrollView(.vertical) { document }
                        .scrollIndicators(.hidden)
                } else {
                    document
                }
            },
            environment: environment,
            prepareMountedView: { root in
                var previous: [CGRect] = []
                var stable = 0
                for _ in 1 ... 100 {
                    #if os(macOS)
                        root.layoutSubtreeIfNeeded()
                        root.displayIfNeeded()
                    #else
                        root.layoutIfNeeded()
                    #endif
                    let observed = [CGRect(origin: .zero, size: geometry.size)] + Self.frames(root)
                    stable = delivery.completed && observed == previous ? stable + 1 : 0
                    if stable >= 5 {
                        if environment.textSize == .enlarged {
                            #if os(iOS)
                                let scrolls = Self.scrollViews(root)
                                #expect(scrolls.count == 1)
                                #expect(scrolls.first?.contentOffset.y == 0)
                            #else
                                let scrolls = Self.scrollViews(root)
                                #expect(scrolls.count == 1)
                                #expect(scrolls.first?.contentView.bounds.minY == 0)
                            #endif
                        }
                        geometry.ready = true
                        return
                    }
                    previous = observed
                    try? await Task.sleep(for: .milliseconds(20))
                }
                Issue.record("Recipe readiness timed out: completed=\(delivery.completed), stable=\(stable), size=\(geometry.size)")
            }
        )
        #expect(delivery.requests == 1)
        #expect(delivery.completed)
        guard geometry.ready else { throw CaptureError.readiness }
        if environment.textSize != .enlarged {
            #expect(geometry.size.height < environment.captureSize.height - 80, "Full recipe must fit before cropping")
        }
        return image
    }

    private static func frames(_ view: FlatMarkSnapshotNativeView) -> [CGRect] {
        [view.convert(view.bounds, to: nil)] + view.subviews.flatMap { frames($0) }
    }

    #if os(iOS)
        private static func scrollViews(_ view: UIView) -> [UIScrollView] {
            (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews($0) }
        }
    #else
        private static func scrollViews(_ view: NSView) -> [NSScrollView] {
            (view as? NSScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews($0) }
        }
    #endif

    // Crop coordinates are top-origin points converted to fixed 2x pixel rectangles.
    private func crop(_ image: FlatMarkSnapshotImage, y: Int, height: Int) throws -> FlatMarkSnapshotImage {
        #if os(macOS)
            var proposed = CGRect(origin: .zero, size: image.size)
            guard let source = image.cgImage(forProposedRect: &proposed, context: nil, hints: nil) else { throw CaptureError.crop }
        #else
            guard let source = image.cgImage else { throw CaptureError.crop }
        #endif
        guard let cropped = source.cropping(to: CGRect(x: 0, y: y * 2, width: source.width, height: height * 2)) else { throw CaptureError.crop }
        #if os(macOS)
            return NSImage(cgImage: cropped, size: CGSize(width: source.width / 2, height: height))
        #else
            return UIImage(cgImage: cropped, scale: 2, orientation: .up)
        #endif
    }

    private func bytes(_ image: FlatMarkSnapshotImage) -> Data? {
        #if os(macOS)
            image.tiffRepresentation
        #else
            image.pngData()
        #endif
    }
}
