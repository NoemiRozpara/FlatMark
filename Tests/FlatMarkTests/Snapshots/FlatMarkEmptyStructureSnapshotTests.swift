import FlatMark
import Foundation
import SwiftUI
import Testing

@Suite(.serialized)
@MainActor
struct FlatMarkEmptyStructureSnapshotTests {
    private static let tasks = """
    - [ ] <u></u>
    - [x] Keep checked
    """

    private static let table = """
    | A | B |
    | --- | --- |
    | <u></u> | keep |
    | left | <u></u> |
    | <u></u> | <u></u> |
    | last | end |
    """

    @Test func emptyTaskInteractive() async throws {
        try await capture(Self.tasks, interactive: true, testName: #function)
    }

    @Test func emptyTaskReadOnly() async throws {
        // Read-only and interactive captures share pixels, not interaction semantics.
        try await capture(Self.tasks, testName: "emptyTaskInteractive()")
    }

    @Test func authoredOrderedRows() async throws {
        try await capture("7. <u></u>\n8. keep", testName: #function)
    }

    @Test func omittedTableCells() async throws {
        try await capture(Self.table, testName: #function)
    }

    #if os(iOS)
    @Test func enlargedEmptyTask() async throws {
        try await capture(
            "- [ ] <u></u>\n- [x] Keep checked while this neighboring task wraps onto another line.",
            interactive: true, enlarged: true, testName: #function
        )
    }

    #endif

    private func capture(
        _ markdown: String, interactive: Bool = false, enlarged: Bool = false, testName: String
    ) async throws {
        let environment = FlatMarkSnapshotEnvironment(
            captureSize: CGSize(width: 560, height: enlarged ? 950 : 450),
            columnWidth: 340, contentInset: 100, pixelScale: 2, appearance: .light,
            localeIdentifier: "en_US", layoutDirection: .leftToRight,
            textSize: enlarged ? .enlarged : .body
        )
        let action: ((String) -> Void)? = interactive ? { _ in } : nil
        let image = try await flatMarkSnapshotImage(
            of: FlatMarkView(markdown: markdown, unsupportedContentPolicy: .omit, taskToggleAction: action)
                .fixedSize(horizontal: false, vertical: true),
            environment: environment
        )
        assertFlatMarkSnapshot(image, suite: .emptyStructures, named: "document", environment: environment, testName: testName)
    }
}
