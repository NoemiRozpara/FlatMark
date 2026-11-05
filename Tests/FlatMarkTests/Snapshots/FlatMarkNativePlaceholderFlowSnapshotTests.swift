import FlatMark
import Foundation
import SwiftUI
import Testing

@Suite(.serialized)
@MainActor
struct FlatMarkNativePlaceholderFlowSnapshotTests {
    private static let wrapping = "A long introduction wraps before the diagram ![Diagram](image.png) and the explanation continues after it."
    private static let hardBreaks = "A\\\n![D](image.png)\\\nA diagram explanation continues to its final words."

    @Test func narrowStandardWrapping() async throws { try await capture(Self.wrapping, column: 160, testName: #function) }
    @Test func wideStandardWrapping() async throws { try await capture(Self.wrapping, column: 320, testName: #function) }
    #if os(iOS)
    @Test func narrowEnlargedWrapping() async throws { try await capture(Self.wrapping, column: 160, enlarged: true, testName: #function) }
    @Test func wideEnlargedWrapping() async throws { try await capture(Self.wrapping, column: 320, enlarged: true, testName: #function) }
    #endif
    @Test func narrowStandardHardBreaks() async throws { try await capture(Self.hardBreaks, column: 160, testName: #function) }
    @Test func wideStandardHardBreaks() async throws { try await capture(Self.hardBreaks, column: 320, testName: #function) }
    #if os(iOS)
    @Test func narrowEnlargedHardBreaks() async throws { try await capture(Self.hardBreaks, column: 160, enlarged: true, testName: #function) }
    @Test func wideEnlargedHardBreaks() async throws { try await capture(Self.hardBreaks, column: 320, enlarged: true, testName: #function) }
    #endif

    private func capture(_ markdown: String, column: CGFloat, enlarged: Bool = false, testName: String) async throws {
        let environment = FlatMarkSnapshotEnvironment(
            captureSize: CGSize(width: 520, height: 1500), columnWidth: column, contentInset: 80,
            pixelScale: 2, appearance: .light, localeIdentifier: "en_US",
            layoutDirection: .leftToRight, textSize: enlarged ? .enlarged : .body
        )
        // No-loader images share native paragraph storage with the surrounding text.
        let image = try await flatMarkSnapshotImage(
            of: FlatMarkView(markdown: markdown).fixedSize(horizontal: false, vertical: true),
            environment: environment
        )
        assertFlatMarkSnapshot(image, suite: .nativePlaceholderFlow, named: "document",
                               environment: environment, testName: testName)
    }
}
