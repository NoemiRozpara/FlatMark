#if os(macOS)
    import AppKit
    import FlatMark
    #if SWIFT_PACKAGE
    import FlatMarkFixtures
    #endif
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

        /// Selectable wording in native descendant order, without synthetic separators.
        var visibleText: String {
            get throws { try visibleAttributedText.string }
        }

        /// Attributes exported by the mounted renderer's native text selection as RTF.
        /// Reading selects all text in each native selection region.
        var visibleAttributedText: NSAttributedString {
            get throws {
                view.layoutSubtreeIfNeeded()
                return try selectedText(in: view)
            }
        }

        func close() {
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }
    }

    @MainActor
    func firstTextView(in view: NSView) -> NSTextView? {
        if let text = view as? NSTextView { return text }
        return view.subviews.lazy.compactMap { firstTextView(in: $0) }.first
    }

    /// Preserves each fixture's size while sharing window lifetime and the initial layout pass.
    @MainActor
    func mountTestView<V: View>(
        _ view: V,
        size: CGSize = CGSize(width: 360, height: 700)
    ) async -> MountedView<V> {
        _ = NSApplication.shared
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

    /// Waits until the loader has seen `expected` requests, then lets rendering settle.
    @MainActor
    func waitForImage(in calls: FlatMarkRecordedImageLoads, expecting expected: Int = 1) async throws {
        for _ in 0 ..< 100 {
            if calls.urls.count >= expected {
                await settleMountedRendering()
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Expected \(expected) supported image request(s), saw \(calls.urls.count)")
    }

    @MainActor
    func settleMountedRendering() async {
        for _ in 0 ..< 3 {
            await Task.yield()
        }
        try? await Task.sleep(for: .milliseconds(30))
    }

    /// Polls only a working selection lane. Missing capability/export throws immediately;
    /// live text missing the requested wording throws a distinct error after the bound.
    @MainActor
    func visibleText<V>(showing wording: String, in hosted: MountedView<V>) async throws -> String {
        for _ in 0 ..< 50 {
            let text = try hosted.visibleText
            if text.contains(wording) {
                return text
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw MountedTextObservationError.wordingNotFound(expected: wording, observed: try hosted.visibleText)
    }

    /// Polls only a working selection lane for the exact wording a reader gets, across every region.
    ///
    /// The wait covers SwiftUI's own re-render after a state change, which is what makes this the
    /// check for a policy switch: wording that never arrives, and wording that never leaves, both
    /// fail with what the mounted view really displayed. Equality rather than containment, so a
    /// region that keeps showing what it showed before the change cannot pass by sitting somewhere
    /// inside the answer.
    @MainActor
    func visibleText<V>(matching wording: String, in hosted: MountedView<V>) async throws -> String {
        for _ in 0 ..< 50 {
            let text = try hosted.visibleText
            if text == wording {
                return text
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw MountedTextObservationError.wordingMismatch(expected: wording, observed: try hosted.visibleText)
    }
#endif
