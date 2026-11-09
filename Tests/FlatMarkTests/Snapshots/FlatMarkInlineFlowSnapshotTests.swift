import FlatMark
import Foundation
import SwiftUI
import Testing

#if os(macOS)
    import AppKit
#elseif os(iOS)
    import UIKit
#endif

// MARK: - FlatMarkInlineFlowSnapshotTests

/// Reviewed break behavior for mixed inline content inside one native paragraph.
///
/// The fixture carries a linked image and literal inline HTML before two consecutive CommonMark hard
/// breaks. A dropped break marker collapses the blank row between the surrounding lines, so both the
/// reviewed reference and the laid-out rows below expose that regression. Baselines live in
/// `Tests/References/Snapshots/InlineFlow/<platform>/`; commands, review, and limits are in
/// [the testing guide](../../README.md#snapshot-baselines). Pixels establish presentation only: no
/// claim about activation, VoiceOver, or gestures follows from these images. The image carries
/// absolute URLs and no loader is supplied, so FlatMark draws its own alt-text placeholder and
/// navigation is never exercised here.
@Suite(.serialized)
@MainActor
struct FlatMarkInlineFlowSnapshotTests {
    private static let imageURL = "https://example.com/image.png"
    private static let detailsURL = "https://example.com/details"

    /// A CommonMark hard line break: a trailing backslash then a newline, projected to one row break.
    private static let hardBreak = "\u{5C}\n"

    /// Mixed inline content followed by two hard breaks with nothing between them.
    private static let consecutiveBreaksMarkdown = """
    Before the breaks [![Diagram](\(imageURL))](\(detailsURL)) and <badge/>\(hardBreak)\(hardBreak)\
    After two consecutive hard breaks.
    """

    /// Two consecutive hard breaks keep one empty row with body metrics between their neighbors.
    @Test
    func consecutiveHardBreaksRetainOneBlankRow() async throws {
        let environment = FlatMarkSnapshotEnvironment.standard
        var paragraphs: [LaidOutParagraph] = []
        let image = try await flatMarkSnapshotImage(
            of: FlatMarkView(markdown: Self.consecutiveBreaksMarkdown)
                .fixedSize(horizontal: false, vertical: true),
            environment: environment,
            prepareMountedView: { root in
                paragraphs = laidOutParagraphs(in: root)
            }
        )
        assertFlatMarkSnapshot(
            image, suite: .inlineFlow, named: "consecutiveBreaks",
            environment: environment, testName: #function
        )

        let paragraph = try #require(paragraphs.first)
        #expect(paragraphs.count == 1)
        let breakRow = try #require(paragraph.rows.first { $0.text.contains("<badge/>") })
        let afterRow = try #require(paragraph.rows.first { $0.text.contains("After two consecutive") })
        let rowsBetween = paragraph.rows.filter { $0.top > breakRow.top && $0.top < afterRow.top }

        // One row, and it carries no wording: the separation survives as an empty row.
        #expect(rowsBetween.count == 1)
        let blankRow = try #require(rowsBetween.first)
        #expect(blankRow.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        // The blank row keeps a line of text metrics instead of collapsing to nothing.
        #expect(abs(blankRow.height - afterRow.height) <= 1)

        // Fitted height and placement agree: rows stack without gaps or overlap, and the mounted
        // paragraph is at least as tall as its laid-out content.
        var previousBottom: CGFloat?
        for row in paragraph.rows {
            if let previousBottom {
                #expect(abs(row.top - previousBottom) <= 1)
            }
            previousBottom = row.top + row.height
        }
        let laidOutBottom = paragraph.rows.map { $0.top + $0.height }.max() ?? 0
        // Both platforms fit the paragraph by rounding its laid-out height up, so a whole missing
        // row is the failure this bound catches; sub-point rounding is not.
        #expect(paragraph.height >= floor(laidOutBottom))
    }
}

// MARK: - Laid-out rows

/// One laid-out row of a mounted native paragraph.
///
/// `top` and `height` are in the paragraph's own coordinates; `text` is the wording the row carries.
private struct LaidOutRow {
    let top: CGFloat
    let height: CGFloat
    let text: String
}

/// A mounted native paragraph: its frame height and the rows it lays out.
private struct LaidOutParagraph {
    let height: CGFloat
    let rows: [LaidOutRow]
}

private extension FlatMarkInlineFlowSnapshotTests {
    /// Reads the rows every native paragraph under `root` lays out, from the platform's own layout
    /// manager: TextKit 2 on iOS, TextKit 1 on macOS.
    func laidOutParagraphs(in root: FlatMarkSnapshotNativeView) -> [LaidOutParagraph] {
        var paragraphs: [LaidOutParagraph] = []
        collectParagraphs(in: root, into: &paragraphs)
        return paragraphs
    }

    func collectParagraphs(in view: FlatMarkSnapshotNativeView, into paragraphs: inout [LaidOutParagraph]) {
        // The native bridge is the paragraph: neither platform nests another native text view inside it.
        #if os(macOS)
            if let text = view as? NSTextView, let manager = text.layoutManager,
               let container = text.textContainer {
                manager.ensureLayout(for: container)
                let source = text.string as NSString
                var rows: [LaidOutRow] = []
                manager.enumerateLineFragments(
                    forGlyphRange: manager.glyphRange(for: container)
                ) { rect, _, _, glyphRange, _ in
                    let characters = manager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
                    rows.append(LaidOutRow(
                        top: rect.minY,
                        height: rect.height,
                        text: source.substring(with: characters)
                    ))
                }
                paragraphs.append(LaidOutParagraph(height: text.bounds.height, rows: rows))
                return
            }
        #elseif os(iOS)
            if let text = view as? UITextView, let manager = text.textLayoutManager {
                manager.ensureLayout(for: manager.documentRange)
                var rows: [LaidOutRow] = []
                manager.enumerateTextLayoutFragments(
                    from: manager.documentRange.location,
                    options: [.ensuresLayout]
                ) { fragment in
                    for line in fragment.textLineFragments {
                        rows.append(LaidOutRow(
                            top: fragment.layoutFragmentFrame.minY + line.typographicBounds.minY,
                            height: line.typographicBounds.height,
                            text: (line.attributedString.string as NSString)
                                .substring(with: line.characterRange)
                        ))
                    }
                    return true
                }
                paragraphs.append(LaidOutParagraph(height: text.bounds.height, rows: rows))
                return
            }
        #endif
        for subview in view.subviews {
            collectParagraphs(in: subview, into: &paragraphs)
        }
    }
}
