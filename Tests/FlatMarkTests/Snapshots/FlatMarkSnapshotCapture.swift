import SwiftUI

#if os(macOS)
    import AppKit
    typealias FlatMarkSnapshotImage = NSImage
    typealias FlatMarkSnapshotNativeView = NSView
#elseif os(iOS)
    import UIKit
    typealias FlatMarkSnapshotImage = UIImage
    typealias FlatMarkSnapshotNativeView = UIView
#endif

enum FlatMarkSnapshotCaptureError: Error {
    case unavailable
}

/// Captures a mounted, synchronous fixture after three layout passes.
/// Async fixtures must resolve their state before calling this helper.
/// `prepareMountedView` prepares an already-mounted native view for deterministic scroll positioning.
/// It is not a readiness signal: changing native state does not prove content drew or gestures work.
@MainActor
func flatMarkSnapshotImage<V: View>(
    of view: V,
    environment: FlatMarkSnapshotEnvironment,
    prepareMountedView: (@MainActor (FlatMarkSnapshotNativeView) async -> Void)? = nil
) async throws -> FlatMarkSnapshotImage {
    let host = flatMakeRetainedSnapshotHost(view: view, environment: environment)
    defer { host.close() }
    return try await host.capture(prepareMountedView: prepareMountedView)
}

/// A native host kept mounted across several captures of the SAME view identity, so a
/// render-setting can change in place without remounting. Callers mutate the model between
/// `capture` calls and drive it to the intended drawn state; this is not a readiness signal.
@MainActor
final class FlatMarkRetainedSnapshotHost {
    private var captureMounted: ((@MainActor (FlatMarkSnapshotNativeView) async -> Void)?) async throws -> FlatMarkSnapshotImage
    private var closeMounted: (() -> Void)?

    fileprivate init(
        capture: @escaping ((@MainActor (FlatMarkSnapshotNativeView) async -> Void)?) async throws -> FlatMarkSnapshotImage,
        close: @escaping () -> Void
    ) {
        captureMounted = capture
        closeMounted = close
    }

    /// Runs the bounded layout passes (+ optional mounted preparation), then captures once.
    func capture(prepareMountedView: (@MainActor (FlatMarkSnapshotNativeView) async -> Void)? = nil) async throws -> FlatMarkSnapshotImage {
        guard closeMounted != nil else { throw FlatMarkSnapshotCaptureError.unavailable }
        return try await captureMounted(prepareMountedView)
    }

    /// Unmounts and releases the host. Call in a defer/teardown.
    func close() {
        closeMounted?()
        closeMounted = nil
        captureMounted = { _ in throw FlatMarkSnapshotCaptureError.unavailable }
    }
}

/// Mounts `view` once and returns a host for repeated captures.
@MainActor
func flatMakeRetainedSnapshotHost<V: View>(view: V, environment: FlatMarkSnapshotEnvironment) -> FlatMarkRetainedSnapshotHost {
    #if os(macOS)
        let (hosting, window) = mountSnapshotView(view, environment: environment)
        let bitmapContext = FlatMarkSnapshotBitmapContext()
        return FlatMarkRetainedSnapshotHost(capture: { prepare in
            try await captureMountedSnapshot(hosting, bitmapContext: bitmapContext, environment: environment, prepareMountedView: prepare)
        }, close: {
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        })
    #elseif os(iOS)
        let (hosting, window) = mountSnapshotView(view, environment: environment)
        return FlatMarkRetainedSnapshotHost(capture: { prepare in
            try await captureMountedSnapshot(hosting, window: window, environment: environment, prepareMountedView: prepare)
        }, close: {
            window.isHidden = true
            window.rootViewController = nil
        })
    #endif
}

#if os(macOS)
    /// Reuses the flattening buffer for captures of one mounted host.
    @MainActor
    private final class FlatMarkSnapshotBitmapContext {
        private var context: CGContext?

        func matching(_ bitmap: NSBitmapImageRep) throws -> CGContext {
            if let context, context.width == bitmap.pixelsWide, context.height == bitmap.pixelsHigh {
                return context
            }
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let replacement = CGContext(
                      data: nil, width: bitmap.pixelsWide, height: bitmap.pixelsHigh,
                      bitsPerComponent: 16, bytesPerRow: 0, space: space,
                      bitmapInfo: CGBitmapInfo.byteOrder16Little.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
                  )
            else {
                throw FlatMarkSnapshotCaptureError.unavailable
            }
            context = replacement
            return replacement
        }
    }

    @MainActor
    private func mountSnapshotView<V: View>(_ view: V, environment: FlatMarkSnapshotEnvironment) -> (NSHostingView<some View>, NSWindow) {
        _ = NSApplication.shared
        let hosting = NSHostingView(rootView: environment.pinnedContent(view))
        hosting.sizingOptions = []
        hosting.frame = CGRect(origin: .zero, size: environment.captureSize)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.appearance = NSAppearance(named: environment.appearance == .dark ? .darkAqua : .aqua)
        // Pin the drawing color space too; converting afterward retains display-dependent pixels.
        window.colorSpace = .sRGB
        window.contentView = hosting
        return (hosting, window)
    }

    @MainActor
    private func captureMountedSnapshot<V: View>(
        _ hosting: NSHostingView<V>, bitmapContext: FlatMarkSnapshotBitmapContext,
        environment: FlatMarkSnapshotEnvironment,
        prepareMountedView: (@MainActor (FlatMarkSnapshotNativeView) async -> Void)?
    ) async throws -> FlatMarkSnapshotImage {
        for _ in 0 ..< 3 {
            await Task.yield()
            hosting.layoutSubtreeIfNeeded()
            hosting.displayIfNeeded()
        }
        if let prepareMountedView {
            await prepareMountedView(hosting)
        }
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            throw FlatMarkSnapshotCaptureError.unavailable
        }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        // Flatten in a named color space. NSImage's implicit drawing context uses the display
        // profile, which changes pixel values even if the result is later converted to sRGB.
        guard let source = bitmap.cgImage else {
            throw FlatMarkSnapshotCaptureError.unavailable
        }
        let context = try bitmapContext.matching(bitmap)
        let bounds = CGRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        context.setFillColor(gray: environment.appearance == .dark ? 0 : 1, alpha: 1)
        context.fill(bounds)
        context.draw(source, in: bounds)
        guard let cgImage = context.makeImage() else {
            throw FlatMarkSnapshotCaptureError.unavailable
        }
        let standardBitmap = NSBitmapImageRep(cgImage: cgImage)
        let image = NSImage(size: environment.captureSize)
        standardBitmap.size = environment.captureSize
        image.addRepresentation(standardBitmap)
        return image
    }
#elseif os(iOS)
    @MainActor
    private func mountSnapshotView<V: View>(_ view: V, environment: FlatMarkSnapshotEnvironment) -> (UIHostingController<some View>, UIWindow) {
        let hosting = UIHostingController(rootView: environment.pinnedContent(view))
        hosting.view.frame = CGRect(origin: .zero, size: environment.captureSize)
        hosting.view.backgroundColor = .clear
        let window = UIWindow(frame: hosting.view.frame)
        window.overrideUserInterfaceStyle = environment.appearance == .dark ? .dark : .light
        window.rootViewController = hosting
        window.isHidden = false
        return (hosting, window)
    }

    @MainActor
    private func captureMountedSnapshot<V: View>(
        _ hosting: UIHostingController<V>, window: UIWindow, environment: FlatMarkSnapshotEnvironment,
        prepareMountedView: (@MainActor (FlatMarkSnapshotNativeView) async -> Void)?
    ) async throws -> FlatMarkSnapshotImage {
        for _ in 0 ..< 3 {
            await Task.yield()
            window.layoutIfNeeded()
            hosting.view.layoutIfNeeded()
        }
        if let prepareMountedView {
            await prepareMountedView(hosting.view)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = environment.pixelScale
        format.opaque = false
        var drawn = false
        let image = UIGraphicsImageRenderer(size: environment.captureSize, format: format).image { _ in
            drawn = hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true)
        }
        guard drawn else { throw FlatMarkSnapshotCaptureError.unavailable }
        return image
    }
#endif
