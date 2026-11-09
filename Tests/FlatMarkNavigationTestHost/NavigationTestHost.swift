#if os(macOS)
    import AppKit
    import FlatMark
    import SwiftUI

    /// An isolated application event loop for exercising the public view's native controls.
    /// All URL opening is recorded; this host never launches an external URL handler.
    @main
    @MainActor
    struct NavigationTestHost {
        static func main() {
            if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--task-interaction" {
                TaskInteractionTestHost.run(mode: CommandLine.arguments[2], markdown: CommandLine.arguments[3])
                return
            }
            guard [4, 6].contains(CommandLine.arguments.count) else { exit(2) }

            let markdown = CommandLine.arguments[1]
            let base = CommandLine.arguments[2].isEmpty ? nil : URL(string: CommandLine.arguments[2])
            let decision = CommandLine.arguments[3]
            let recordsImages = CommandLine.arguments.count == 6
            let expectedImageLoads = recordsImages ? Int(CommandLine.arguments[5]) ?? 0 : 0
            let recorder = ImageRecorder()
            let loader: FlatMarkImageLoader? = recordsImages ? FlatMarkImageLoader(configurationID: UUID()) { url in
                await recorder.record(url)
                return loadedFixtureImage
            } : nil
            var activated: [String] = []
            var opened: [String] = []
            let changesOptionalCallback = decision == "addCallback" || decision == "removeCallback"
            let updatesCallback = decision.hasPrefix("retainedCallback") || changesOptionalCallback
            let updatesOpener = decision == "retainedOpener"
            let action: ((URL) -> FlatMarkLinkActivationResult)? = ["omitted", "addCallback"].contains(decision) ? nil : { url in
                if updatesCallback {
                    activated.append("old:" + url.absoluteString)
                    return .handled
                }
                activated.append(url.absoluteString)
                switch decision {
                case "handled": return .handled
                case "rejected": return .rejected
                default: return .useDefaultOpening
                }
            }
            let application = NSApplication.shared
            application.setActivationPolicy(.prohibited)
            let policyArgument = recordsImages ? CommandLine.arguments[4] : "default"
            let policy: FlatMarkUnsupportedContentPolicy?
            switch policyArgument {
            case "omit":
                policy = .omit
            case "default":
                policy = nil
            default:
                policy = .literal
            }
            let document = FlatMarkDocument(markdown: markdown, baseURL: base)
            func root(action: ((URL) -> FlatMarkLinkActivationResult)?, updated: Bool) -> AnyView {
                let view: FlatMarkView
                if let policy {
                    view = FlatMarkView(
                        document: document,
                        imageLoader: loader,
                        unsupportedContentPolicy: policy,
                        linkActivationAction: action
                    )
                } else {
                    // Keep the public initializer's default distinct from an explicit literal policy.
                    view = FlatMarkView(
                        document: document,
                        imageLoader: loader,
                        linkActivationAction: action
                    )
                }
                return AnyView(view.coordinateSpace(name: "navigationHost").environment(\.openURL, OpenURLAction { url in
                    opened.append((updatesOpener ? (updated ? "new:" : "old:") : "") + url.absoluteString)
                    return .discarded
                }))
            }
            let hosting = NSHostingView(rootView: root(action: action, updated: false))
            hosting.frame = CGRect(x: 0, y: 0, width: 400, height: hosting.fittingSize.height)
            let window = NSWindow(
                contentRect: hosting.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.contentView = hosting
            hosting.layoutSubtreeIfNeeded()
            hosting.displayIfNeeded()

            // Every activation fixture has a leading label or a one-cell table header.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                let originalTarget = hosting.hitTest(NSPoint(x: 20, y: hosting.bounds.midY))
                if updatesCallback || updatesOpener {
                    let updatedAction: ((URL) -> FlatMarkLinkActivationResult)? = decision == "removeCallback" ? nil : updatesCallback ? { url in
                        activated.append("new:" + url.absoluteString)
                        switch decision {
                        case "retainedCallbackHandled", "addCallback": return .handled
                        case "retainedCallbackRejected": return .rejected
                        default: return .useDefaultOpening
                        }
                    } : action
                    hosting.rootView = root(action: updatedAction, updated: true)
                    hosting.layoutSubtreeIfNeeded()
                    hosting.displayIfNeeded()
                    try? await Task.sleep(for: .milliseconds(100))
                }
                // Positive image controls wait for a real loader call, not just a layout delay.
                for _ in 0 ..< 100 where recorder.urls.count < expectedImageLoads {
                    try? await Task.sleep(for: .milliseconds(10))
                }
                let beforeActivation = activated
                let beforeOpening = opened
                let point = NSPoint(x: 20, y: hosting.bounds.midY)
                guard let target = hosting.hitTest(point) else { exit(3) }
                if updatesCallback || updatesOpener {
                    // Replacing the root must update the mounted control, not mount a fresh one.
                    guard target === originalTarget else { exit(8) }
                }
                if let text = target as? NSTextView, let manager = text.layoutManager,
                   let container = text.textContainer, text.string.isEmpty == false {
                    let expectedLink = text.textStorage?.attribute(.link, at: 0, effectiveRange: nil) as? URL
                    // Revalidate the fixed click point against glyphs, not just the view's frame.
                    manager.ensureLayout(for: container)
                    let local = text.convert(point, from: hosting)
                    let containerPoint = NSPoint(
                        x: local.x - text.textContainerOrigin.x, y: local.y - text.textContainerOrigin.y
                    )
                    let glyph = manager.glyphIndex(for: containerPoint, in: container)
                    guard glyph < manager.numberOfGlyphs else { exit(7) }
                    let character = manager.characterIndexForGlyph(at: glyph)
                    guard manager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
                        .contains(containerPoint),
                        text.textStorage?.attribute(.link, at: character, effectiveRange: nil) as? URL == expectedLink
                    else { exit(7) }
                }

                let location = hosting.convert(point, to: nil)
                let timestamp = ProcessInfo.processInfo.systemUptime
                guard let up = NSEvent.mouseEvent(
                    with: .leftMouseUp, location: location, modifierFlags: [], timestamp: timestamp + 0.01,
                    windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 0
                ), let down = NSEvent.mouseEvent(
                    with: .leftMouseDown, location: location, modifierFlags: [], timestamp: timestamp,
                    windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
                ) else { exit(4) }

                // Native text selection can synchronously track until a release arrives.
                application.postEvent(up, atStart: true)
                target.mouseDown(with: down)
                target.mouseUp(with: up)
                application.discardEvents(matching: .leftMouseUp, before: nil)
                try? await Task.sleep(for: .milliseconds(100))
                var report = [
                    "beforeActivation": beforeActivation, "beforeOpening": beforeOpening,
                    "activated": activated, "opened": opened,
                ]
                if recordsImages {
                    report["loaded"] = recorder.urls
                }
                guard let data = try? JSONSerialization.data(withJSONObject: report) else { exit(5) }

                FileHandle.standardOutput.write(data)
                // Exit only after emitting a complete report; a premature exit is a test failure.
                exit(0)
            }
            application.run()
            exit(6)
        }
    }

    /// The stand-in a host loader returns; these checks read the request, never its pixels.
    private let loadedFixtureImage = NativeImage(systemSymbolName: "photo.fill", accessibilityDescription: nil) ?? NativeImage()

    @MainActor
    private final class ImageRecorder {
        private(set) var urls: [String] = []

        func record(_ url: URL) {
            urls.append(url.absoluteString)
        }
    }
#else
    @main
    struct NavigationTestHost {
        static func main() {}
    }
#endif
