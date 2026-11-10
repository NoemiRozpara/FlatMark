#if os(macOS)
import AppKit
import FlatMark
import SwiftUI

/// Initial synchronous layout and a subsequent screen-capture checkpoint, not frame latency.
@MainActor
func runPreviewBenchmark() async {
    setbuf(stdout, nil)
    let application = NSApplication.shared
    application.setActivationPolicy(.regular)
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 390, height: 844),
        styleMask: [.titled], backing: .buffered, defer: false
    )
    window.title = "FlatMark rendering measurement"
    window.isReleasedWhenClosed = false
    window.makeKeyAndOrderFront(nil)
    application.activate(ignoringOtherApps: true)
    let output = ProcessInfo.processInfo.environment["FLATMARK_CAPTURE_DIR"] ?? "/tmp/flatmark-preview"
    try! FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
    print("# OS=\(ProcessInfo.processInfo.operatingSystemVersionString); thermal=\(ProcessInfo.processInfo.thermalState.rawValue)")
    print("# Release; viewport=390x844pt; 1 warmup, 3 samples; unchanged eager renderer")
    print("# capture-checkpoint includes layout, display, 20ms run-loop yield and screencapture overhead; inspect PNGs before claiming visible content")
    print("fixture,scenario,samples,median_ms,p95_ms,min_ms")
    var checksum = 0
    for fixture in fixtures {
        var construction: [Double] = []
        var layout: [Double] = []
        var capture: [Double] = []
        for iteration in 0..<4 {
            print("# \(fixture.name) iteration=\(iteration) thermal=\(ProcessInfo.processInfo.thermalState.rawValue)")
            let (document, constructionMS) = await Task.detached(priority: .userInitiated) {
                precondition(!Thread.isMainThread)
                let clock = ContinuousClock()
                let start = clock.now
                let document = FlatMarkDocument(markdown: fixture.markdown, baseURL: URL(string: "https://example.com/tasks/"))
                return (document, milliseconds(start.duration(to: clock.now)))
            }.value
            checksum &+= consume(document)
            precondition(Thread.isMainThread)
            let clock = ContinuousClock()
            let start = clock.now
            let hosting = NSHostingView(rootView: ScrollView {
                FlatMarkView(document: document)
                    .frame(maxWidth: .infinity, alignment: .leading)
            })
            hosting.frame = NSRect(x: 0, y: 0, width: 390, height: 844)
            window.contentView = hosting
            hosting.layoutSubtreeIfNeeded()
            let layoutMS = milliseconds(start.duration(to: clock.now))
            window.displayIfNeeded()
            try? await Task.sleep(for: .milliseconds(20))
            let path = "\(output)/\(fixture.name)-\(iteration).png"
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
            do {
                try process.run()
                // Yield the main actor while the external capture waits for the window server.
                while process.isRunning { try await Task.sleep(for: .milliseconds(5)) }
                guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: path) else {
                    fatalError("Screen capture unavailable; cannot measure visible-content checkpoint")
                }
            } catch { fatalError("Screen capture failed: \(error)") }
            let captureMS = milliseconds(start.duration(to: clock.now))
            print("# sample \(fixture.name) \(iteration): construction=\(constructionMS) layout=\(layoutMS) capture=\(captureMS); png=\(path)")
            checksum &+= hosting.subviews.count
            if iteration > 0 {
                construction.append(constructionMS)
                layout.append(layoutMS)
                capture.append(captureMS)
            }
            window.contentView = nil
            try? await Task.sleep(for: .milliseconds(20))
        }
        report(fixture.name, "background-construction", construction)
        report(fixture.name, "main-mount-layout", layout)
        report(fixture.name, "visible-capture-upper-bound", capture)
    }
    print("Consumed preview checksum: \(checksum)")
    print("# end=\(Date()); thermal=\(ProcessInfo.processInfo.thermalState.rawValue)")
    window.close()
}
#endif
