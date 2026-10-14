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
        guard CommandLine.arguments.count == 4 else { exit(2) }
        let markdown = CommandLine.arguments[1]
        let base = CommandLine.arguments[2].isEmpty ? nil : URL(string: CommandLine.arguments[2])
        let decision = CommandLine.arguments[3]
        var activated: [String] = []
        var opened: [String] = []
        let action: ((URL) -> FlatMarkLinkActivationResult)? = decision == "omitted" ? nil : { url in
            activated.append(url.absoluteString)
            switch decision {
            case "handled": return .handled
            case "rejected": return .rejected
            default: return .useDefaultOpening
            }
        }
        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        let hosting = NSHostingView(rootView: FlatMarkView(
            markdown: markdown, baseURL: base, linkActivationAction: action
        ).environment(\.openURL, OpenURLAction { url in
            opened.append(url.absoluteString)
            return .discarded
        }))
        hosting.frame = CGRect(x: 0, y: 0, width: 400, height: hosting.fittingSize.height)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()

        // Every fixture has a single leading label or a one-cell table header.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let beforeActivation = activated
            let beforeOpening = opened
            let point = NSPoint(x: 20, y: hosting.bounds.midY)
            guard let target = hosting.hitTest(point) else { exit(3) }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let report = [
                    "beforeActivation": beforeActivation, "beforeOpening": beforeOpening,
                    "activated": activated, "opened": opened,
                ]
                guard let data = try? JSONSerialization.data(withJSONObject: report) else { exit(5) }
                FileHandle.standardOutput.write(data)
                // Exit only after emitting a complete report; a premature exit is a test failure.
                exit(0)
            }
        }
        application.run()
        exit(6)
    }
}
#else
@main
struct NavigationTestHost {
    static func main() {}
}
#endif
