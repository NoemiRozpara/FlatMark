#if os(macOS)
    import AppKit
    import FlatMark
    import SwiftUI

    /// Mouse tracking must run in an application event loop, never in the test runner.
    @MainActor
    enum TaskInteractionTestHost {
        static func run(mode: String, markdown: String) {
            guard mode == "custom" || mode == "omit" else { exit(2) }

            let application = NSApplication.shared
            application.setActivationPolicy(.prohibited)
            let model = TaskInteractionModel(markdown: markdown, mode: mode)
            let hosting = NSHostingView(rootView: TaskInteractionView(model: model))
            hosting.frame = CGRect(x: 0, y: 0, width: 400, height: 1000)
            let window = NSWindow(
                contentRect: hosting.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.contentView = hosting

            Task { @MainActor in
                await settle(hosting)
                if mode == "omit" {
                    for _ in 0 ..< 100 where model.loadedURLs.isEmpty {
                        try? await Task.sleep(for: .milliseconds(10))
                    }
                    for policy: FlatMarkUnsupportedContentPolicy in [.omit, .literal, .omit] {
                        model.policy = policy
                        await settle(hosting)
                    }
                }
                let buttons = nativeButtons(in: hosting)
                let unchecked = buttons.filter { $0.state == .off }
                guard unchecked.count == 1, let task = unchecked.first else { exit(7) }

                let frame = task.convert(task.bounds, to: hosting)
                let checkboxPoint = NSPoint(x: frame.midX, y: frame.midY)
                // The replacement is the first inline child after the eight-point sibling gap.
                let hostPoint = NSPoint(x: frame.maxX + 20, y: frame.midY)
                var report = [
                    "initialMarkdown": [model.markdown],
                    "initialCheckboxStates": buttons.map { String($0.state.rawValue) }.sorted(),
                    "checkboxEnabled": [String(task.isEnabled)],
                    "initialLoaded": model.loadedURLs,
                    "initialCustomActivations": [String(model.customActivations)],
                    "initialTaskUpdates": [String(model.updates.count)],
                ]
                for activatesTask in mode == "custom" ? [false, true, false] : [true] {
                    click(at: activatesTask ? checkboxPoint : hostPoint, in: hosting, window: window)
                    await settle(hosting)
                    report["customActivations", default: []].append(String(model.customActivations))
                    report["taskUpdates", default: []].append(String(model.updates.count))
                    report["markdown", default: []].append(model.markdown)
                    report["linkActivations", default: []].append(String(model.linkActivations))
                }
                report["updates"] = model.updates
                report["customPayloads"] = model.payloads
                report["loaded"] = model.loadedURLs
                report["finalCheckboxStates"] = nativeButtons(in: hosting).map { String($0.state.rawValue) }.sorted()
                report["completed"] = ["true"]
                guard let data = try? JSONSerialization.data(withJSONObject: report) else { exit(5) }

                FileHandle.standardOutput.write(data)
                exit(0)
            }
            application.run()
            exit(6)
        }

        private static func settle(_ hosting: NSView) async {
            try? await Task.sleep(for: .milliseconds(30))
            hosting.layoutSubtreeIfNeeded()
            hosting.displayIfNeeded()
        }

        private static func nativeButtons(in view: NSView) -> [NSButton] {
            let button = (view as? NSButton).map { [$0] } ?? []
            return button + view.subviews.flatMap { nativeButtons(in: $0) }
        }

        private static func click(at point: NSPoint, in hosting: NSView, window: NSWindow) {
            // NSView.hitTest expects coordinates in its superview, not its own bounds.
            guard let target = hosting.hitTest(hosting.convert(point, to: hosting.superview)) else { exit(3) }

            let location = hosting.convert(point, to: nil)
            let timestamp = ProcessInfo.processInfo.systemUptime
            guard let down = NSEvent.mouseEvent(
                with: .leftMouseDown, location: location, modifierFlags: [], timestamp: timestamp,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ), let up = NSEvent.mouseEvent(
                with: .leftMouseUp, location: location, modifierFlags: [], timestamp: timestamp + 0.01,
                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 0
            ) else { exit(4) }

            NSApplication.shared.postEvent(up, atStart: true)
            target.mouseDown(with: down)
            target.mouseUp(with: up)
            NSApplication.shared.discardEvents(matching: .leftMouseUp, before: nil)
        }
    }

    @MainActor
    @Observable
    private final class TaskInteractionModel {
        var markdown: String
        var policy: FlatMarkUnsupportedContentPolicy = .literal
        let mode: String
        var customActivations = 0
        var linkActivations = 0
        var updates: [String] = []
        @ObservationIgnored var payloads: [String] = []
        @ObservationIgnored var loadedURLs: [String] = []
        let loaderID = UUID()

        init(markdown: String, mode: String) {
            self.markdown = markdown
            self.mode = mode
        }
    }

    private struct TaskInteractionView: View {
        let model: TaskInteractionModel

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                if model.mode == "omit" {
                    Toggle("Omit unsupported content", isOn: Binding(
                        get: {
                            if case .omit = model.policy {
                                true
                            } else {
                                false
                            }
                        },
                        set: { model.policy = $0 ? .omit : .literal }
                    ))
                }
                FlatMarkView(
                    markdown: model.markdown,
                    baseURL: URL(string: "https://example.com/"),
                    imageLoader: FlatMarkImageLoader(configurationID: model.loaderID) { url in
                        await MainActor.run { model.loadedURLs.append(url.absoluteString) }
                        return Image(systemName: "photo.fill")
                    },
                    unsupportedContentPolicy: model.mode == "custom" ? .custom { payload in
                        model.payloads.append(payload)
                        // Keep this SwiftUI control separate from the native checkbox inventory.
                        return AnyView(Button("Replacement") { model.customActivations += 1 }.buttonStyle(.plain))
                    } : model.policy,
                    linkActivationAction: { _ in
                        model.linkActivations += 1
                        return .handled
                    },
                    taskToggleAction: {
                        model.updates.append($0)
                        model.markdown = $0
                    }
                )
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
#endif
