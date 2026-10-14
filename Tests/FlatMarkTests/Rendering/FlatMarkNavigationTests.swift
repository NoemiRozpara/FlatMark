#if os(macOS)
import Foundation
import Testing

@MainActor
struct FlatMarkNavigationTests {
    @Test(arguments: [
        "[Details](details)",
        "[![Diagram](image.png)](details)",
        "[Details](details) [![Diagram](image.png)](details) after",
        "[![Diagram](image.png)](details) [Details](details) after",
        "| [Details](details) |\n| --- |",
        "| [![Diagram](image.png)](details) |\n| --- |",
        "> [Details](details)",
        "[Details](reader:details)",
    ], ["handled", "rejected", "default"])
    func `native activation suppresses or delegates exactly once`(markdown: String, decision: String) async throws {
        let report = try await navigationReport(markdown: markdown, decision: decision)
        let destination = markdown.contains("reader:details") ? "reader:details" : "https://example.com/docs/details"
        #expect(report["beforeActivation"] == [])
        #expect(report["beforeOpening"] == [])
        #expect(report["activated"] == [destination])
        #expect(report["opened"] == (decision == "default" ? [destination] : []))
    }

    @Test(arguments: [
        "[Details](details)",
        "[![Diagram](image.png)](details)",
        "[Details](unsupported:details)",
    ])
    func `omitted callback preserves native default opening`(markdown: String) async throws {
        let report = try await navigationReport(markdown: markdown, decision: "omitted")
        let destination = markdown.contains("unsupported:details")
            ? "unsupported:details" : "https://example.com/docs/details"
        #expect(report["beforeActivation"] == [])
        #expect(report["beforeOpening"] == [])
        #expect(report["activated"] == [])
        #expect(report["opened"] == [destination])
    }

    @Test(arguments: [
        "[**Details**]()",
        "[**Details**](details)",
        "[**Details**](<http://[>)",
        "[![Diagram](image.png)]()",
        "[![Diagram](image.png)](details)",
        "[![Diagram](image.png)](<http://[>)",
        "| [Details](details) |\n| --- |",
    ], ["", "docs/page"])
    func `inert labels never invoke either handler`(markdown: String, base: String) async throws {
        let report = try await navigationReport(markdown: markdown, base: base, decision: "default")
        #expect(report["beforeActivation"] == [])
        #expect(report["beforeOpening"] == [])
        #expect(report["activated"] == [])
        #expect(report["opened"] == [])
    }
}

private final class NavigationTestBundle: NSObject {}

@MainActor
private func navigationReport(
    markdown: String, base: String = "https://example.com/docs/page", decision: String
) async throws -> [String: [String]] {
    // SwiftPM builds the executable dependency alongside the test bundle. Each
    // invocation owns its application event loop, windows, and mouse-event queue.
    let executable = Bundle(for: NavigationTestBundle.self).bundleURL
        .deletingLastPathComponent().appendingPathComponent("FlatMarkNavigationTestHost")
    try #require(FileManager.default.isExecutableFile(atPath: executable.path), "Missing native host: \(executable.path)")
    let process = Process()
    process.executableURL = executable
    process.arguments = [markdown, base, decision]
    let output = Pipe()
    process.standardOutput = output
    try process.run()
    defer {
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
    }
    for _ in 0..<500 {
        if !process.isRunning { break }
        try await Task.sleep(for: .milliseconds(10))
    }
    try #require(!process.isRunning, "Native navigation host timed out")
    process.waitUntilExit()
    try #require(process.terminationReason == .exit && process.terminationStatus == 0,
                 "Native navigation host exited with status \(process.terminationStatus)")
    let data = output.fileHandleForReading.readDataToEndOfFile()
    // A zero exit status is insufficient: require the host's completed activation
    // report so a premature AppKit/runner exit cannot masquerade as a passing test.
    let report = try JSONDecoder().decode([String: [String]].self, from: data)
    try #require(Set(report.keys) == ["beforeActivation", "beforeOpening", "activated", "opened"])
    return report
}
#endif
