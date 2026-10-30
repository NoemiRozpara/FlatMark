import FlatMark
import Foundation
import SwiftUI
import Testing

// MARK: - FlatMarkLinkedImageSnapshotTests

/// Reviewed presentation for one image inside a Markdown link and the same image on its own.
///
/// Both variants carry the same network-free placeholder: the document supplies no image loader, so
/// the `https` source is never fetched and FlatMark draws its own alt-text placeholder. Baselines live
/// in `Tests/References/Snapshots/LinkedImage/<platform>/`. Commands, review, and verification are
/// documented in [the testing guide](../../README.md#snapshot-baselines). Pixels establish
/// presentation only: no claim about activation, VoiceOver, or gestures follows from these images.
@Suite(.serialized)
@MainActor
struct FlatMarkLinkedImageSnapshotTests {
    private static let imageURL = "https://example.com/image.png"

    @Test
    func linkedImagePresentationMatchesReviewedBaseline() async throws {
        try await assertPresentation(
            markdown: "Before [![Diagram](\(Self.imageURL))](https://example.com/details) after.",
            name: "linked",
            testName: #function
        )
    }

    @Test
    func unlinkedImagePresentationMatchesReviewedBaseline() async throws {
        try await assertPresentation(
            markdown: "Before ![Diagram](\(Self.imageURL)) after.",
            name: "unlinked",
            testName: #function
        )
    }

    /// Captures each variant against its own reference.
    ///
    /// The variants are snapshotted against separate references rather than against each other, so a
    /// change that pushes both in the same direction still fails.
    private func assertPresentation(markdown: String, name: String, testName: String) async throws {
        let environment = FlatMarkSnapshotEnvironment.standard
        let image = try await flatMarkSnapshotImage(
            of: FlatMarkView(markdown: markdown),
            environment: environment
        )

        assertFlatMarkSnapshot(
            image,
            suite: .linkedImage,
            named: name,
            environment: environment,
            testName: testName
        )
    }
}
