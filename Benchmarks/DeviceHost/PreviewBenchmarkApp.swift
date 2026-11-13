import FlatMark
import SwiftUI
import UIKit

// Opt-in device host. Capture acknowledgements bound observation time, not GPU completion.
@main
@MainActor
final class PreviewBenchmarkApp: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var runTask: Task<Void, Never>?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: Text("Preparing benchmark"))
        window.makeKeyAndVisible()
        self.window = window
        runTask = Task { await run(in: window) }
        return true
    }

    private func run(in window: UIWindow) async {
        precondition(Thread.isMainThread)
        guard let name = CommandLine.arguments.last,
              let fixture = fixtures.first(where: { $0.name == name }) else {
            window.rootViewController = UIHostingController(
                rootView: Text("Pass a fixture name as the final launch argument"))
            return
        }
        let priorIdleSetting = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = priorIdleSetting }

        var log: ProgressLog?
        do {
            let progress = try ProgressLog(fixture: fixture.name)
            log = progress
            let process = ProcessInfo.processInfo
            let screen = window.screen
            try progress.row("environment", "os", process.operatingSystemVersionString)
            try progress.row("environment", "screen_points", "\(screen.bounds)")
            try progress.row("environment", "window_points", "\(window.bounds)")
            try progress.row("environment", "scale", "\(screen.scale)")
            try progress.row("environment", "thermal", "\(process.thermalState.rawValue)")
            try progress.row("environment", "low_power", "\(process.isLowPowerModeEnabled)")
            try progress.row("environment", "fixture", fixture.parameters)
            try progress.row("environment", "protocol", "1 warmup + 3 samples; ms; capture includes polling and host transport")
            let clock = ContinuousClock()
            var construction: [Double] = []
            var mount: [Double] = []
            var capture: [Double] = []
            var checksum = 0
            for iteration in 0..<4 {
                let id = "\(fixture.name)-\(iteration)"
                try progress.clearHandshake()
                try progress.row("stage", id, "before_background_construction")
                let result = await Task.detached(priority: .userInitiated) {
                    precondition(!Thread.isMainThread)
                    let clock = ContinuousClock()
                    let start = clock.now
                    let document = FlatMarkDocument(
                        markdown: fixture.markdown,
                        baseURL: URL(string: "https://example.com/tasks/")!
                    )
                    let elapsed = milliseconds(start.duration(to: clock.now))
                    return (document, elapsed, consume(document))
                }.value
                precondition(Thread.isMainThread)
                checksum &+= result.2
                try progress.row("construction_ms", id, "\(result.1)")
                try progress.row("stage", id, "before_main_mount_layout")
                let start = clock.now
                let controller = UIHostingController(rootView:
                    ScrollView {
                        FlatMarkView(document: result.0)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                )
                // A new controller gives every iteration fresh SwiftUI mount state.
                window.rootViewController = controller
                window.setNeedsLayout()
                window.layoutIfNeeded()
                controller.view.setNeedsLayout()
                controller.view.layoutIfNeeded()
                let mountMS = milliseconds(start.duration(to: clock.now))
                try progress.row("main_mount_layout_ms", id, "\(mountMS)")
                try progress.row("stage", id, "before_display_yield")
                // Let the run loop submit display work; this is not a GPU fence.
                await Task.yield()
                try await Task.sleep(for: .milliseconds(100))
                try progress.ready(id)
                try progress.row("stage", id, "capture_ready")
                let deadline = clock.now.advanced(by: .seconds(120))
                while try progress.acknowledgement() != id {
                    guard clock.now < deadline else { throw CaptureError.timeout(id) }
                    try await Task.sleep(for: .milliseconds(100))
                }
                let captureMS = milliseconds(start.duration(to: clock.now))
                try progress.row("visible_capture_upper_bound_ms", id, "\(captureMS)")
                if iteration > 0 {
                    construction.append(result.1)
                    mount.append(mountMS)
                    capture.append(captureMS)
                }
            }
            try progress.summary("construction", construction)
            try progress.summary("main-mount-layout", mount)
            try progress.summary("visible-capture-upper-bound", capture)
            try progress.row("checksum", fixture.name, "\(checksum)")
            try progress.row("completion", fixture.name, "success")
            // Keep the last measured content visible for inspection. No completion overlay.
        } catch {
            try? log?.row("completion", fixture.name, "failure: \(error)")
            print("Device benchmark failed: \(error)")
        }
    }
}

private enum CaptureError: Error {
    case timeout(String)
}

@MainActor
private final class ProgressLog {
    private let directory: URL
    private let handle: FileHandle

    init(fixture: String) throws {
        directory = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let url = directory.appendingPathComponent("preview-\(fixture).csv")
        if !FileManager.default.fileExists(atPath: url.path) {
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try row("run", fixture, ISO8601DateFormatter().string(from: Date()))
        try row("columns", "kind,key,value", "summary values: samples;median_ms;p95_ms;min_ms")
    }

    deinit { try? handle.close() }

    func row(_ kind: String, _ key: String, _ value: String) throws {
        precondition(Thread.isMainThread)
        let line = [kind, key, value].map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
            .joined(separator: ",") + "\n"
        try handle.write(contentsOf: Data(line.utf8))
        try handle.synchronize()
    }

    func summary(_ name: String, _ samples: [Double]) throws {
        let sorted = samples.sorted()
        try row("summary", name,
                "\(samples.count);\(sorted[sorted.count / 2]);\(sorted[Int(ceil(Double(sorted.count) * 0.95)) - 1]);\(sorted[0])")
    }

    func clearHandshake() throws {
        for name in ["capture-ready.txt", "capture-ack.txt"] {
            let url = directory.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }

    func ready(_ id: String) throws {
        try Data(id.utf8).write(to: directory.appendingPathComponent("capture-ready.txt"), options: .atomic)
    }

    func acknowledgement() throws -> String? {
        let url = directory.appendingPathComponent("capture-ack.txt")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
