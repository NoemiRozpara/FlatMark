import FlatMark
import Foundation
import SwiftUI
import Testing

// MARK: - FlatMarkInlineFlowSnapshotTests

/// Reviewed wrapping, baseline, ordering, break, and overflow behaviour for mixed inline content.
///
/// One fixture carries a resolved linked image, a host attributed replacement with a distinct font,
/// adjacent supported emphasis and link text, and explicit hard breaks. Every variant renders the
/// same public `FlatMarkView`, so a change in how the inline flow places those parts shows up as a
/// pixel difference. Baselines live in `Tests/References/Snapshots/InlineFlow/<platform>/`. Commands,
/// review, and verification are documented in
/// [the testing guide](../../README.md#snapshot-baselines). Pixels establish presentation only: no
/// claim about activation, VoiceOver, or gestures follows from these images.
///
/// The linked image carries absolute image and link URLs, so it resolves into a real linked-image
/// flow rather than falling back to native text. No loader is supplied, so the `https` source is never
/// fetched and FlatMark draws its own alt-text placeholder; navigation is never exercised here.
@Suite(.serialized)
@MainActor
struct FlatMarkInlineFlowSnapshotTests {
    private static let imageURL = "https://example.com/image.png"
    private static let detailsURL = "https://example.com/details"
    private static let linkURL = "https://example.com/page"

    private static let beforeText =
        "A long introduction explains the diagram and gives enough context to wrap naturally inside the narrow reading column"
    private static let afterText =
        "while the remaining explanation continues after the image without collapsing into a narrow orphan row of its own"
    private static let linkedImage = "[![Diagram](\(imageURL))](\(detailsURL))"
    private static let customTag = "<badge/>"

    /// A CommonMark hard line break: a trailing backslash then a newline, projected to a single row
    /// break by the inline flow.
    private static let hardBreak = "\u{5C}\n"

    /// Long text on both sides of the linked image, then the host replacement, adjacent supported
    /// emphasis and link, and two hard breaks that each open a new row.
    private static let mixedFlowMarkdown = """
    \(beforeText) \(linkedImage) \(afterText), and \(customTag) a **bold** word beside \
    [a supported link](\(linkURL))\(hardBreak)the first line after a hard break\(hardBreak)\
    the second line keeps wrapping with a few more words to fill the column.
    """

    /// The linked image and replacement keep both breaks in native mixed-flow layout.
    /// References retain current output, including lost vertical separation, for a later renderer fix.
    private static let consecutiveBreaksMarkdown = """
    Before the breaks \(linkedImage) and \(customTag)\(hardBreak)\(hardBreak)\
    After two consecutive hard breaks.
    """

    /// A distinctive attributed marker exposes replacement position and baseline changes.
    private static var replacement: AttributedString {
        var marker = AttributedString("BADGE")
        marker.font = .system(size: 20, weight: .bold, design: .monospaced)
        marker.foregroundColor = .white
        marker.backgroundColor = .indigo
        return marker
    }

    // MARK: Narrow mixed flow

    @Test
    func narrowMixedFlowMatchesReviewedBaseline() async throws {
        let environment = FlatMarkSnapshotEnvironment(
            captureSize: CGSize(width: 320, height: 460),
            columnWidth: 240,
            contentInset: 20,
            pixelScale: 2,
            appearance: .light,
            localeIdentifier: "en_US",
            layoutDirection: .leftToRight,
            textSize: .body
        )
        try await assertFlow(Self.mixedFlowMarkdown, named: "narrowMixed", environment: environment, testName: #function)
    }

    // MARK: Consecutive breaks

    @Test
    func consecutiveBreaksRetainCurrentRendering() async throws {
        try await assertFlow(
            Self.consecutiveBreaksMarkdown,
            named: "consecutiveBreaks",
            environment: .standard,
            testName: #function
        )
    }

    // MARK: Wide control

    /// The wide counterpart of the narrow fixture. With room for more glyphs per row, the same content
    /// wraps at different points, so a wrapping regression cannot hide by matching only one column.
    @Test
    func wideControlMakesWrappingDifferencesVisible() async throws {
        let environment = FlatMarkSnapshotEnvironment(
            captureSize: CGSize(width: 560, height: 320),
            columnWidth: 480,
            contentInset: 20,
            pixelScale: 2,
            appearance: .light,
            localeIdentifier: "en_US",
            layoutDirection: .leftToRight,
            textSize: .body
        )
        try await assertFlow(Self.mixedFlowMarkdown, named: "wideControl", environment: environment, testName: #function)
    }

    // MARK: Enlarged text

    /// Enlarged effective text: real Dynamic Type on iOS, an absolute effective size on macOS (labelled
    /// as such in the environment diagnostic). The capture is tall enough to hold the enlarged rows so a
    /// vertical clip would read as ink at the bottom edge rather than a cropped pass.
    @Test
    func enlargedMixedFlowMatchesReviewedBaseline() async throws {
        let environment = FlatMarkSnapshotEnvironment(
            captureSize: CGSize(width: 320, height: 1980),
            columnWidth: 240,
            contentInset: 20,
            pixelScale: 2,
            appearance: .light,
            localeIdentifier: "en_US",
            layoutDirection: .leftToRight,
            textSize: .enlarged
        )
        try await assertFlow(
            Self.mixedFlowMarkdown,
            named: "enlargedMixed",
            environment: environment,
            testName: #function
        )
    }

    // MARK: Right-to-left

    @Test
    func rightToLeftMixedFlowMatchesReviewedBaseline() async throws {
        let environment = FlatMarkSnapshotEnvironment(
            captureSize: CGSize(width: 320, height: 460),
            columnWidth: 240,
            contentInset: 20,
            pixelScale: 2,
            appearance: .light,
            localeIdentifier: "en_US",
            layoutDirection: .rightToLeft,
            textSize: .body
        )
        try await assertFlow(
            Self.mixedFlowMarkdown,
            named: "rtlMixed",
            environment: environment,
            testName: #function
        )
    }

    // MARK: - Shared flow

    /// Hosts the fixture through the public `FlatMarkView` with the custom replacement, captures it in
    /// the environment, and compares it against this suite's own reference.
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
