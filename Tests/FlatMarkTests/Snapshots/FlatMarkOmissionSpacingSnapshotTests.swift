import FlatMark
import Foundation
import SwiftUI
import Testing

@Suite(.serialized)
@MainActor
struct FlatMarkOmissionSpacingSnapshotTests {
    private static let removedBlocks = """
    <div>hidden block</div>

    <u></u>

    # <u></u>

    > <u></u>

    > > <u></u>
    """

    @Test
    func emptiedBlocksLeaveNoSlotsOrRules() async throws {
        try await assertPair(
            omitted: "Before omission.\n\n\(Self.removedBlocks)\n\nAfter omission.",
            control: "Before omission.\n\nAfter omission.",
            environment: .standard,
            testName: #function
        )
    }

    @Test
    func supportedListKeepsItsQuote() async throws {
        try await assertPair(
            omitted: """
            Before the quote.

            > <u></u>
            >
            > - Retained list item.
            >
            > > <u></u>

            After the quote.
            """,
            control: """
            Before the quote.

            > - Retained list item.

            After the quote.
            """,
            environment: .standard,
            testName: #function
        )
    }

    #if os(iOS)
    @Test
    func enlargedNarrowNeighborsKeepTheirSpacing() async throws {
        let before = "Before omission the supported neighbors wrap."
        let after = "After omission the wording stays intact."
        let environment = FlatMarkSnapshotEnvironment(
            captureSize: CGSize(width: 320, height: 1100),
            columnWidth: 240,
            contentInset: 20,
            pixelScale: 2,
            appearance: .light,
            localeIdentifier: "en_US",
            layoutDirection: .leftToRight,
            textSize: .enlarged
        )
        try await assertPair(
            omitted: "\(before)\n\n\(Self.removedBlocks)\n\n\(after)",
            control: "\(before)\n\n\(after)",
            environment: environment,
            testName: #function
        )
    }

    #endif

    // Both documents check a retained golden so a shared regression cannot pass unnoticed.
    private func assertPair(
        omitted: String,
        control: String,
        environment: FlatMarkSnapshotEnvironment,
        testName: String
    ) async throws {
        for markdown in [omitted, control] {
            // Measure intrinsic content, not a flexible quote rule stretched to the capture height.
            let image = try await flatMarkSnapshotImage(
                of: FlatMarkView(markdown: markdown, unsupportedContentPolicy: .omit)
                    .fixedSize(horizontal: false, vertical: true),
                environment: environment
            )
            assertFlatMarkSnapshot(
                image,
                suite: .omissionSpacing,
                named: "omitted",
                environment: environment,
                testName: testName
            )
        }
    }
}
