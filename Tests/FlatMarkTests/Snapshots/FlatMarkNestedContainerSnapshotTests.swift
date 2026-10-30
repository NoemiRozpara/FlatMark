import FlatMark
import Foundation
import SwiftUI
import Testing

@Suite(.serialized)
@MainActor
struct FlatMarkNestedContainerSnapshotTests {
    private static let quote = """
    Before the nested quote.

    > Outer opening: keep every line visible as this long explanation wraps inside the reading column.
    >
    > > Inner opening carries <badge/> a custom inline replacement beside supported **bold wording**.
    > > Line two follows a hard break.\\
    > > Line three names the middle of the quote.\\
    > > Line four must remain visible too.\\
    > > Inner ending: the final sentence wraps again and must not disappear below the earlier lines.
    >
    > Outer ending: this paragraph follows the complete inner quote, not a clipped fragment.

    After the nested quote.
    """

    private static let list = """
    Before the mixed list.

    1. Parent opening wraps with enough wording to expose the content alignment.
       - Child bullet wraps across the narrow reading column.
         1. Grandchild numbered row.
       - Final child bullet.

       Parent continuation follows all child rows and wraps onto another line.

       > Parent quote follows the continuation paragraph and keeps its own rule.

       ```swift
       let ready = true
       render(ready)
       ```

    2. Next parent row ends the list.

    After the mixed list.
    """

    @Test
    func narrowNestedQuote() async throws {
        try await capture(Self.quote, column: 240, height: 1100, testName: #function)
    }

    @Test
    func wideNestedQuote() async throws {
        try await capture(Self.quote, column: 480, height: 750, testName: #function)
    }

    @Test
    func narrowListContinuations() async throws {
        try await capture(Self.list, column: 240, height: 1100, testName: #function)
    }

    @Test
    func wideListContinuations() async throws {
        try await capture(Self.list, column: 480, height: 750, testName: #function)
    }

    @Test
    func enlargedListContinuations() async throws {
        try await capture(Self.list, column: 320, height: 2100, textSize: .enlarged, testName: #function)
    }

    private func capture(
        _ markdown: String,
        column: CGFloat,
        height: CGFloat,
        textSize: FlatMarkSnapshotEnvironment.TextSize = .body,
        testName: String
    ) async throws {
        let environment = FlatMarkSnapshotEnvironment(
            captureSize: CGSize(width: column + 260, height: height),
            columnWidth: column,
            contentInset: 100,
            pixelScale: 2,
            appearance: .light,
            localeIdentifier: "en_US",
            layoutDirection: .leftToRight,
            textSize: textSize
        )
        // Qualify intrinsic document height, not flexible rules under a constrained host.
        let view = FlatMarkView(
            markdown: markdown,
            unsupportedContentPolicy: .custom { _ in
                AnyView(RoundedRectangle(cornerRadius: 4).fill(.indigo).frame(width: 44, height: 30))
            }
        )
        .fixedSize(horizontal: false, vertical: true)
        let image = try await flatMarkSnapshotImage(of: view, environment: environment)
        assertFlatMarkSnapshot(image, suite: .nestedContainers, named: "document", environment: environment, testName: testName)
    }
}
