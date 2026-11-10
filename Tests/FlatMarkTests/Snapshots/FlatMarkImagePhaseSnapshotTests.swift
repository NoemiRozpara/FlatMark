@testable import FlatMark
import Foundation
import SwiftUI
import Testing

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Completion is loader bookkeeping, not proof of drawing. Mounted geometry must then remain
/// identical for five samples within 100 attempts at 20ms intervals. Phase-specific comparison
/// and reviewed contract controls establish appearance; neither gate identifies a drawn phase.
@Suite(.serialized)
@MainActor
struct FlatMarkImagePhaseSnapshotTests {
    @Test func placeholder() async throws { try await capture(phase: .placeholder, testName: #function) }
    @Test func emptyAltPlaceholder() async throws { try await capture(phase: .placeholder, alt: "", testName: #function) }
    @Test func heldLoading() async throws { try await capture(phase: .loading, testName: #function) }
    @Test func throwingFailure() async throws { try await capture(phase: .failed, testName: #function) }
    @Test func emptyAltFailure() async throws { try await capture(phase: .failed, alt: "", testName: #function) }
    @Test func smallIntrinsicRaster() async throws { try await capture(phase: .loaded, testName: #function) }
    @Test func oversizedRaster() async throws { try await capture(phase: .loaded, oversized: true, testName: #function) }
    @Test func mixedLoadedText() async throws { try await capture(phase: .loaded, mixed: true, testName: #function) }
    @Test func darkPlaceholder() async throws { try await capture(phase: .placeholder, dark: true, testName: #function) }
    @Test func darkFailure() async throws { try await capture(phase: .failed, dark: true, testName: #function) }

    #if os(macOS)
        @Test func capturePreservesSRGBSourceColors() async throws {
            let colors = [[30, 180, 120], [220, 60, 90], [40, 100, 230], [240, 190, 50]]
            let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
            let context = try #require(CGContext(
                data: nil, width: 80, height: 20, bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            for (index, channels) in colors.enumerated() {
                context.setFillColor(try #require(CGColor(
                    colorSpace: space, components: channels.map { CGFloat($0) / 255 } + [1]
                )))
                context.fill(CGRect(x: index * 20, y: 0, width: 20, height: 20))
            }
            let source = NSImage(cgImage: try #require(context.makeImage()), size: CGSize(width: 80, height: 20))
            let environment = FlatMarkSnapshotEnvironment.standard
            var firstCapture: Data?
            for screen in NSScreen.screens {
                let image = try await flatMarkSnapshotImage(
                    of: Image(nsImage: source), environment: environment,
                    prepareMountedView: { root in
                        root.window?.setFrameOrigin(screen.visibleFrame.origin)
                        #expect(root.window?.screen == screen)
                        root.layoutSubtreeIfNeeded()
                        root.display()
                    }
                )
                let bitmap = try #require(image.representations.first as? NSBitmapImageRep)
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                if let firstCapture {
                    #expect(png == firstCapture, "Capture differs on \(screen.localizedName)")
                } else {
                    firstCapture = png
                }
                #expect(bitmap.pixelsWide == Int(environment.captureSize.width * environment.pixelScale))
                #expect(bitmap.pixelsHigh == Int(environment.captureSize.height * environment.pixelScale))
                #expect(bitmap.cgImage?.colorSpace?.name == CGColorSpace.sRGB)
                #expect(bitmap.bitsPerSample == 16)
                for (index, channels) in colors.enumerated() {
                    var pixel = [Int](repeating: 0, count: bitmap.samplesPerPixel)
                    bitmap.getPixel(&pixel, atX: (30 + index * 20) * 2, y: 60)
                    // Exact 16-bit values catch shifts that disappear when rounded to 8-bit.
                    #expect(Array(pixel.prefix(3)) == channels.map { $0 * 257 })
                    #expect(pixel.last == 65535)
                }
            }
            #expect(firstCapture != nil)
        }
    #endif

    private enum Phase: String { case placeholder, loading, loaded, failed }
    private enum FixtureError: Error { case failed }
    // All bookkeeping is protected by the lock. Completion runs synchronously as the loader exits.
    private final class Delivery: @unchecked Sendable {
        private let lock = NSLock()
        private var didStart = false
        private var didComplete = false
        private var didRelease = false

        var started: Bool { lock.withLock { didStart } }
        var completed: Bool { lock.withLock { didComplete } }
        func start() { lock.withLock { didStart = true } }
        func complete() { lock.withLock { didComplete = true } }
        func release() { lock.withLock { didRelease = true } }

        func wait() async throws {
            while !lock.withLock({ didRelease }) {
                try await Task.sleep(for: .milliseconds(20))
            }
        }
    }
    private final class Geometry {
        var size = CGSize.zero
        var ready = false
    }

    private func capture(
        phase: Phase, alt: String = "Striped local diagram", oversized: Bool = false,
        mixed: Bool = false, dark: Bool = false, testName: String
    ) async throws {
        let environment = FlatMarkSnapshotEnvironment(
            captureSize: CGSize(width: 600, height: 500), columnWidth: 200, contentInset: 100,
            pixelScale: 2, appearance: dark ? .dark : .light, localeIdentifier: "en_US",
            layoutDirection: .leftToRight, textSize: .body
        )
        let raster = Self.raster(size: oversized ? CGSize(width: 1000, height: 500) : CGSize(width: 120, height: 60))
        let delivery = Delivery()
        let geometry = Geometry()
        let loader: FlatMarkImageLoader? = phase == .placeholder ? nil : FlatMarkImageLoader(configurationID: UUID()) { _ in
            delivery.start()
            defer { delivery.complete() }
            if phase == .loading { try await delivery.wait() }
            if phase == .failed { throw FixtureError.failed }
            return raster
        }
        let source = "![\(alt)](https://example.invalid/local.png)"
        let markdown = mixed ? "Before the diagram \(source) after the diagram ends here." : source
        let label = alt.isEmpty ? "Image" : alt
        let imagePhase: FlatMarkInlineView.ImagePhase = switch phase {
        case .placeholder: .placeholder
        case .loading: .loading
        case .failed: .failed
        case .loaded: .loaded(raster)
        }
        if let symbol = imagePhase.placeholderSymbolName {
            let control = try await flatMarkSnapshotImage(
                of: (Text("") + Text(Image(systemName: symbol)) + Text(" \(label)"))
                    .textSelection(.enabled), environment: environment
            )
            assertFlatMarkSnapshot(control, suite: .imagePhases, named: "control", environment: environment, testName: testName)
        }
        do {
            let image = try await flatMarkSnapshotImage(
                of: FlatMarkView(markdown: markdown, imageLoader: loader)
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { geometry.size = $0 },
                environment: environment,
                prepareMountedView: { root in
                    var previous: [CGRect] = []
                    var stable = 0
                    var history: [String] = []
                    for attempt in 1 ... 100 {
                        #if os(macOS)
                            root.layoutSubtreeIfNeeded()
                            root.displayIfNeeded()
                        #else
                            root.layoutIfNeeded()
                        #endif
                        let frames = Self.frames(root)
                        let observed = [CGRect(origin: .zero, size: geometry.size)] + frames
                        let completed = delivery.completed
                        let started = delivery.started
                        let gate = phase == .placeholder || (phase == .loading ? started : completed)
                        stable = gate && observed == previous ? stable + 1 : 0
                        history.append("attempt \(attempt): started=\(started), completed=\(completed), stable=\(stable), geometry=\(observed)")
                        if gate && stable >= 5 {
                            geometry.ready = true
                            return
                        }
                        previous = observed
                        try? await Task.sleep(for: .milliseconds(20))
                    }
                    Issue.record("\(testName): phase \(phase.rawValue), attempts 100, consecutive stable \(stable), observations \(history); \(environment.diagnostic)")
                }
            )
            delivery.release()
            guard geometry.ready else { throw FixtureError.failed }
            assertFlatMarkSnapshot(image, suite: .imagePhases, named: "image", environment: environment, testName: testName)
        } catch {
            delivery.release()
            throw error
        }
    }

    // Observe mounted native regions without interpreting text or phase identity.
    private static func frames(_ view: FlatMarkSnapshotNativeView) -> [CGRect] {
        [view.convert(view.bounds, to: nil)] + view.subviews.flatMap { frames($0) }
    }

    private static func raster(size: CGSize) -> NativeImage {
        let width = Int(size.width), height = Int(size.height)
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let index = (y * width + x) * 4
                bytes[index] = x < width / 2 ? 30 : 240
                bytes[index + 1] = y < height / 2 ? 180 : 70
                bytes[index + 2] = 120
            }
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let cg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                         bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                         bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                         provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        #if os(macOS)
            return NSImage(cgImage: cg, size: CGSize(width: width, height: height))
        #else
            return UIImage(cgImage: cg, scale: 1, orientation: .up)
        #endif
    }
}
