import SwiftUI
import UIKit
import Darwin

public struct ContentView: View {
    @State private var status = "Running construction benchmark. Keep app in foreground."
    public init() {}
    public var body: some View {
        Text(status).padding().task {
            UIApplication.shared.isIdleTimerDisabled = true
            status = await Task.detached(priority: .userInitiated) {
                let documents = URL.documentsDirectory
                let run = ProcessInfo.processInfo.arguments.last ?? "run"
                let file = documents.appending(path: "benchmark-\(run).csv")
                guard freopen(file.path, "w", stdout) != nil else { return "Cannot open result file" }
                var system = utsname()
                uname(&system)
                let machine = withUnsafePointer(to: &system.machine) {
                    $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
                }
                print("# device=\(machine); OS=\(ProcessInfo.processInfo.operatingSystemVersionString)")
                print("# start=\(Date()); thermal=\(ProcessInfo.processInfo.thermalState.rawValue); lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled)")
                runBenchmark()
                print("# end=\(Date()); thermal=\(ProcessInfo.processInfo.thermalState.rawValue)")
                fflush(stdout)
                return "Completed: \(file.lastPathComponent)"
            }.value
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
