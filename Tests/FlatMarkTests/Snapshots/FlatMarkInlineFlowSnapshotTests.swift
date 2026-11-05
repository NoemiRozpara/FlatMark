import FlatMark
import Foundation
import SwiftUI
import Testing

@Suite(.serialized)
@MainActor
struct FlatMarkInlineFlowSnapshotTests {
    private static let linkedImage = "[![Diagram](https://example.com/image.png)](https://example.com/details)"
    private static let customTag = "<badge/>"
    private static let hardBreak = "\u{5C}\n"

    /// References retain current output, including lost vertical separation, for a later renderer fix.
    private static let consecutiveBreaksMarkdown = """
    Before the breaks \(linkedImage) and \(customTag)\(hardBreak)\(hardBreak)\
    After two consecutive hard breaks.
    """

    private static var replacement: AttributedString {
        var marker = AttributedString("BADGE")
        marker.font = .system(size: 20, weight: .bold, design: .monospaced)
        marker.foregroundColor = .white
        marker.backgroundColor = .indigo
        return marker
    }

    @Test
    func consecutiveBreaksRetainCurrentRendering() async throws {
        try await assertFlow(
            Self.consecutiveBreaksMarkdown,
            named: "consecutiveBreaks",
            environment: .standard,
            testName: #function
        )
    }

    private func assertFlow(
        _ markdown: String,
        named name: String,
        environment: FlatMarkSnapshotEnvironment,
        testName: String
    ) async throws {
        let view = FlatMarkView(
            markdown: markdown,
            unsupportedContentPolicy: .custom { _ in Self.replacement }
        )
        let image = try await flatMarkSnapshotImage(of: view, environment: environment)

        assertFlatMarkSnapshot(
            image,
            suite: .inlineFlow,
            named: name,
            environment: environment,
            testName: testName
        )
    }
}
