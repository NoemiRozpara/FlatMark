import SwiftUI

#if os(macOS)
    import AppKit
    typealias FlatMarkSnapshotImage = NSImage
#elseif os(iOS)
    import UIKit
    typealias FlatMarkSnapshotImage = UIImage
#endif

enum FlatMarkSnapshotCaptureError: Error {
    case unavailable
}

/// Captures a mounted, synchronous fixture after three layout passes.
/// Async fixtures must resolve their state before calling this helper.
@MainActor
func flatMarkSnapshotImage<V: View>(
    of view: V,
    environment: FlatMarkSnapshotEnvironment
) async throws -> FlatMarkSnapshotImage {
    #if os(macOS)
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
        window.contentView = hosting
        defer {
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }
        for _ in 0 ..< 3 {
            await Task.yield()
            hosting.layoutSubtreeIfNeeded()
            hosting.displayIfNeeded()
        }
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            throw FlatMarkSnapshotCaptureError.unavailable
        }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let captured = NSImage(size: environment.captureSize)
        captured.addRepresentation(bitmap)
        return NSImage(size: environment.captureSize, flipped: false) { bounds in
            (environment.appearance == .dark ? NSColor.black : NSColor.white).setFill()
            bounds.fill()
            captured.draw(in: bounds)
            return true
        }
    #elseif os(iOS)
        let hosting = UIHostingController(rootView: environment.pinnedContent(view))
        hosting.view.frame = CGRect(origin: .zero, size: environment.captureSize)
        hosting.view.backgroundColor = .clear
        let window = UIWindow(frame: hosting.view.frame)
        window.overrideUserInterfaceStyle = environment.appearance == .dark ? .dark : .light
        window.rootViewController = hosting
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        for _ in 0 ..< 3 {
            await Task.yield()
            window.layoutIfNeeded()
            hosting.view.layoutIfNeeded()
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
    #endif
}
