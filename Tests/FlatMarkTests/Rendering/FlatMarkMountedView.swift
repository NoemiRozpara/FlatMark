#if os(macOS)
    import AppKit
    import FlatMark
    import FlatMarkFixtures
    import SwiftUI
    import Testing

    /// Owns one mounted view and its window for a rendering observation.
    @MainActor
    final class MountedView<V: View> {
        let view: NSHostingView<V>
        private let window: NSWindow

        init(view: NSHostingView<V>, window: NSWindow) {
            self.view = view
            self.window = window
        }

        /// Whether the mounted view lays out anything at all: a document with no surviving blocks,
        /// or a view that failed to render, reports zero.
        var showsContent: Bool {
            view.layoutSubtreeIfNeeded()
            return view.fittingSize != .zero
        }

        /// Native text exposed by the mounted AppKit hierarchy, suitable for content assertions.
        var visibleText: String {
            view.layoutSubtreeIfNeeded()
            return view.descendants
                .compactMap { ($0 as? NSTextField)?.stringValue }
                .joined(separator: " ")
        }

        func close() {
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }
    }

    /// Preserves each fixture's size while sharing window lifetime and the initial layout pass.
    @MainActor
    func mountTestView<V: View>(
        _ view: V,
        size: CGSize = CGSize(width: 360, height: 700)
    ) async -> MountedView<V> {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.contentView = hosting
        for _ in 0 ..< 3 {
            await Task.yield()
        }
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()
        return MountedView(view: hosting, window: window)
    }

    private extension NSView {
        var descendants: [NSView] {
            subviews.flatMap { [$0] + $0.descendants }
        }
    }

    @MainActor
    func waitForImage(in calls: FlatMarkRecordedImageLoads) async throws {
        for _ in 0 ..< 100 {
            if calls.urls.count == 1 {
                await settleMountedRendering()
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Expected the supported image to load")
    }

    @MainActor
    func settleMountedRendering() async {
        for _ in 0 ..< 3 {
            await Task.yield()
        }
        try? await Task.sleep(for: .milliseconds(30))
    }

    /// The native text one mounted view exposes once it shows `wording`, or as far as it got within a
    /// bound, so a view that renders at all is read after it laid out rather than after an arbitrary
    /// sleep, and wording that never arrives stays a missing observation.
    @MainActor
    func visibleText<V>(showing wording: String, in hosted: MountedView<V>) async -> String {
        for _ in 0 ..< 50 {
            if hosted.visibleText.contains(wording) {
                break
            }

            try? await Task.sleep(for: .milliseconds(10))
        }

        return hosted.visibleText
    }
#endif
