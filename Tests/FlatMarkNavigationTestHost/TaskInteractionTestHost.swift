#if os(macOS)
    import AppKit
    import FlatMark
    import SwiftUI

    /// Mouse tracking must run in an application event loop, never in the test runner.
    @MainActor
    enum TaskInteractionTestHost {
        static func run(mode: String, markdown: String) {
            guard ["custom", "omit", "marker-interactive", "marker-readOnly"].contains(mode)
            else { exit(2) }

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
                if mode.hasPrefix("marker-") {
                    guard let frame = model.markerFrames[false] else { exit(7) }
                    let states = model.markerFrames.keys.map { String($0) }.sorted()
                    // Use the measured drawing center without assuming a larger control frame.
                    click(
                        at: NSPoint(x: frame.midX, y: frame.midY), in: hosting, window: window,
                        allowsMiss: mode == "marker-readOnly"
                    )
                    await settle(hosting)
                    let report = ["states": states, "updates": model.updates, "completed": ["true"]]
                    guard let data = try? JSONSerialization.data(withJSONObject: report) else { exit(5) }
                    FileHandle.standardOutput.write(data)
                    exit(0)
                }
                guard let frame = model.markerFrames[false] else { exit(7) }
                let checkboxPoint = NSPoint(x: frame.midX, y: frame.midY)
                // The replacement is the first inline child after the eight-point sibling gap.
                let hostPoint = NSPoint(x: frame.midX + 22 + 20, y: frame.midY)
                var report = [
                    "initialMarkdown": [model.markdown],
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

        private static func click(
            at point: NSPoint, in hosting: NSView, window: NSWindow, allowsMiss: Bool = false
        ) {
            // NSView.hitTest expects coordinates in its superview, not its own bounds.
            guard let target = hosting.hitTest(hosting.convert(point, to: hosting.superview)) else {
                if allowsMiss { return }
                exit(3)
            }

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
        @ObservationIgnored var markerFrames: [Bool: CGRect] = [:]
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
                        return AnyView(Button("Replacement") { model.customActivations += 1 }.buttonStyle(.plain))
                    } : model.policy,
                    linkActivationAction: { _ in
                        model.linkActivations += 1
                        return .handled
                    },
                    taskToggleAction: model.mode == "marker-readOnly" ? nil : {
                        model.updates.append($0)
                        model.markdown = $0
                    },
                    taskMarker: .custom { isChecked in
                        Image(systemName: isChecked ? "checkmark.circle" : "circle")
                            .frame(width: 12, height: 12)
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .named("host"))
                            } action: { frame in
                                model.markerFrames[isChecked] = frame
                            }
                    }
                )
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .coordinateSpace(name: "host")
        }
    }
#endif
