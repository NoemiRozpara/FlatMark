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

        @Test(arguments: ["addCallback", "removeCallback"])
        func `optional callback changes reach the retained native control`(decision: String) async throws {
            let report = try await navigationReport(markdown: "[Details](details)", decision: decision)
            let destination = "https://example.com/docs/details"
            #expect(report["beforeActivation"] == [])
            #expect(report["beforeOpening"] == [])
            #expect(report["activated"] == (decision == "addCallback" ? ["new:" + destination] : []))
            #expect(report["opened"] == (decision == "removeCallback" ? [destination] : []))
        }

        @Test(arguments: [
            "[Details](details)",
            "| [Details](details) |\n| --- |",
            "[![Diagram](image.png)](details)",
        ], ["retainedCallback", "retainedCallbackHandled", "retainedCallbackRejected", "retainedOpener"])
        func `retained native controls use current host navigation handlers`(markdown: String, decision: String) async throws {
            let report = try await navigationReport(markdown: markdown, decision: decision)
            let destination = "https://example.com/docs/details"
            #expect(report["beforeActivation"] == [])
            #expect(report["beforeOpening"] == [])
            #expect(report["activated"] == [(decision.hasPrefix("retainedCallback") ? "new:" : "") + destination])
            let suppressesOpening = decision == "retainedCallbackHandled" || decision == "retainedCallbackRejected"
            #expect(report["opened"] == (suppressesOpening ? [] : [(decision == "retainedOpener" ? "new:" : "") + destination]))
        }

        @Test(arguments: ["custom", "customLink"],
              ["retainedCallback", "retainedCallbackHandled", "retainedCallbackRejected", "retainedOpener"])
        func `retained replacement links use current host navigation handlers`(policy: String, decision: String) async throws {
            let report = try await navigationReport(
                markdown: "[<tag>](details)", decision: decision, unsupportedPolicy: policy
            )
            let destination = policy == "customLink"
                ? "https://host.example/explicit" : "https://example.com/docs/details"
            #expect(report["beforeActivation"] == [])
            #expect(report["beforeOpening"] == [])
            #expect(report["activated"] == [(decision.hasPrefix("retainedCallback") ? "new:" : "") + destination])
            let suppressesOpening = decision == "retainedCallbackHandled" || decision == "retainedCallbackRejected"
            #expect(report["opened"] == (suppressesOpening ? [] : [(decision == "retainedOpener" ? "new:" : "") + destination]))
        }

        @Test(arguments: ["[**Details**]()", "[**Details**](<http://[>)", "Plain neighbor [Details](details)"], ["retainedCallback", "retainedOpener"])
        func `retained inert labels ignore updated handlers`(markdown: String, decision: String) async throws {
            let report = try await navigationReport(markdown: markdown, decision: decision)
            #expect(report["beforeActivation"] == [])
            #expect(report["beforeOpening"] == [])
            #expect(report["activated"] == [])
            #expect(report["opened"] == [])
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

        @Test(arguments: [
            "before <img src=\"https://evil.example/x.png\"> after",
            "<script>go()</script>",
            "<iframe src=\"https://evil.example/e\"></iframe>",
            "<img src=\"https://evil.example/x.png\" onclick=\"go()\">",
            "<a href=\"javascript:go()\" onclick=\"go()\">tap</a>",
            "<details>Visible literal</details>",
        ], ["default", "literal", "omit"])
        func `mounted public view never loads or activates HTML resources`(
            markdown: String,
            policy: String
        ) async throws {
            // Three supported lines keep the host's midpoint click inside text, not the block gap,
            // whether omission removes the entire fixture or leaves one line of supported siblings.
            let mountedMarkdown = policy == "omit"
                ? markdown + "\n\nSupported text.\nSupported text.\nSupported text."
                : markdown
            let report = try await navigationReport(
                markdown: mountedMarkdown, decision: "default", unsupportedPolicy: policy
            )
            #expect(report["beforeActivation"] == [])
            #expect(report["beforeOpening"] == [])
            #expect(report["activated"] == [])
            #expect(report["opened"] == [])
            #expect(report["loaded"] == [])
        }

        @Test(arguments: ["default", "literal", "omit"])
        func `every policy preserves Markdown image loading and native link activation`(policy: String) async throws {
            let report = try await navigationReport(
                markdown: "[Details](details) ![Diagram](image.png)", decision: "default",
                unsupportedPolicy: policy, expectedImageLoads: 1
            )
            #expect(report["beforeActivation"] == [])
            #expect(report["beforeOpening"] == [])
            #expect(report["activated"] == ["https://example.com/docs/details"])
            #expect(report["opened"] == ["https://example.com/docs/details"])
            #expect(report["loaded"] == ["https://example.com/docs/image.png"])
        }

        @Test(arguments: ["handled", "rejected", "default", "omitted"], ["custom", "customLink"])
        func `replacement links use existing host navigation routing`(decision: String, policy: String) async throws {
            let report = try await navigationReport(
                markdown: "[<u>after](details) [Adjacent](adjacent)",
                decision: decision, unsupportedPolicy: policy
            )
            let destination = policy == "custom" ? "https://example.com/docs/details" : "https://host.example/explicit"
            #expect(report["beforeActivation"] == [])
            #expect(report["beforeOpening"] == [])
            #expect(report["activated"] == (decision == "omitted" ? [] : [destination]))
            #expect(report["opened"] == (["default", "omitted"].contains(decision) ? [destination] : []))
        }

        @Test(arguments: ["custom", "customLink"])
        func `supported links beside replacements remain independent`(policy: String) async throws {
            let report = try await navigationReport(
                markdown: "[Adjacent](adjacent) [<u>after](details)",
                decision: "default", unsupportedPolicy: policy
            )
            #expect(report["activated"] == ["https://example.com/docs/adjacent"])
            #expect(report["opened"] == ["https://example.com/docs/adjacent"])
        }

        @Test(arguments: [
            "[before <u>x</u> after](details)",
            "[**before <u>x</u> after**](details)",
            "# [before <u>x</u> after](details)",
            "> [before <u>x</u> after](details)",
            "| [before <u>x</u> after](details) |\n| --- |",
        ], ["literal", "omit"])
        func `unsupported tags retain native enclosing Markdown link activation`(
            markdown: String,
            policy: String
        ) async throws {
            let report = try await navigationReport(
                markdown: markdown, decision: "default", unsupportedPolicy: policy
            )
            #expect(report["activated"] == ["https://example.com/docs/details"])
            #expect(report["opened"] == ["https://example.com/docs/details"])
            #expect(report["loaded"] == [])
        }
    }

    /// Launches the native host so an observation comes from a running application event loop
    /// rather than from a view tree that never received an event.
    @MainActor
    func navigationReport(
        markdown: String, base: String = "https://example.com/docs/page", decision: String,
        unsupportedPolicy: String? = nil, expectedImageLoads: Int = 0
    ) async throws -> [String: [String]] {
        var arguments = [markdown, base, decision]
        if let unsupportedPolicy {
            arguments += [unsupportedPolicy, String(expectedImageLoads)]
        }
        let report = try await nativeHostReport(arguments: arguments)
        var expectedKeys: Set = ["beforeActivation", "beforeOpening", "activated", "opened"]
        if unsupportedPolicy != nil {
            expectedKeys.insert("loaded")
        }
        if unsupportedPolicy == "custom" || unsupportedPolicy == "customLink" {
            expectedKeys.formUnion(["customPayloads", "customActivations"])
        }
        try #require(Set(report.keys) == expectedKeys)
        return report
    }

    @MainActor
    func nativeHostReport(arguments: [String]) async throws -> [String: [String]] {
        // SwiftPM builds the executable dependency alongside the test bundle. Each
        // invocation owns its application event loop, windows, and mouse-event queue.
        let executable = Bundle(for: NavigationTestBundle.self)
            .bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("FlatMarkNavigationTestHost")
        try #require(
            FileManager.default.isExecutableFile(atPath: executable.path),
            "Missing native host: \(executable.path)"
        )
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        defer {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
        }
        for _ in 0 ..< 500 {
            if !process.isRunning {
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(!process.isRunning, "Native navigation host timed out")
        process.waitUntilExit()
        try #require(
            process.terminationReason == .exit && process.terminationStatus == 0,
            "Native navigation host exited with status \(process.terminationStatus)"
        )
        let data = output.fileHandleForReading.readDataToEndOfFile()
        // A zero exit status is insufficient: require the host's completed activation
        // report so a premature AppKit/runner exit cannot masquerade as a passing test.
        return try JSONDecoder().decode([String: [String]].self, from: data)
    }

    private final class NavigationTestBundle: NSObject {}
#endif
