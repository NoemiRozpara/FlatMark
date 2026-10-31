@testable import FlatMark
import Foundation
import SwiftUI
import Testing

#if os(macOS)
    import AppKit
#elseif os(iOS)
    import UIKit
#endif

@Suite(.serialized)
@MainActor
struct FlatMarkTableSnapshotTests {
    private static let longTable = """
    | First column with a long wrapping header | Second column with a long wrapping header | Third column with a long wrapping header | Final column with a long wrapping header |
    | --- | :---: | ---: | --- |
    | **Long first cell** keeps wrapping through several lines until the final words FIRST END. | A short middle cell. | | *Trailing long cell* keeps wrapping through several lines until the final words LAST END. |
    | | Supported **bold**, *italic*, and `code`. | Third body cell. | Last body cell. |
    """

    @Test func wideLongCells() async throws {
        try await capture(FlatMarkView(markdown: Self.longTable), column: 700, testName: #function)
    }

    @Test func narrowLeading() async throws {
        try await capture(FlatMarkView(markdown: Self.longTable), column: 240, trailing: false, testName: #function)
    }

    @Test func narrowTrailing() async throws {
        try await capture(FlatMarkView(markdown: Self.longTable), column: 240, trailing: true, testName: #function)
    }

    @Test func enlargedLongCells() async throws {
        try await capture(FlatMarkView(markdown: Self.longTable), column: 320, textSize: .enlarged, testName: #function)
    }

    @Test func headerOnly() async throws {
        try await capture(FlatMarkView(markdown: """
        | Header name | Header state |
        | --- | --- |
        """), column: 360, testName: #function)
    }

    @Test func emptyInternalTableBetweenNeighbors() async throws {
        // Internal-only fixture: public Markdown cannot express a headerless empty table.
        var blocks = FlatMarkRenderProjector.project(markdown: "Before the table.\n\nAfter the table.").blocks
        blocks.insert(.init(id: .init(path: [99]), kind: .table(.init(header: [], rows: []))), at: 1)
        try await capture(FlatMarkDocumentView(document: .init(blocks: blocks), context: .readOnly), column: 360, testName: #function)
    }

    @Test func visiblePublicTableBetweenNeighbors() async throws {
        try await capture(FlatMarkView(markdown: """
        Before the table.

        | Visible table |
        | --- |

        After the table.
        """), column: 360, testName: #function)
    }

    private func capture<V: View>(
        _ view: V,
        column: CGFloat,
        trailing: Bool? = nil,
        textSize: FlatMarkSnapshotEnvironment.TextSize = .body,
        testName: String
    ) async throws {
        let environment = FlatMarkSnapshotEnvironment(
            captureSize: CGSize(width: column + 200, height: textSize == .enlarged ? 1900 : 750),
            columnWidth: column, contentInset: 100, pixelScale: 2,
            appearance: .light, localeIdentifier: "en_US", layoutDirection: .leftToRight, textSize: textSize
        )
        var prepare: (@MainActor (FlatMarkSnapshotNativeView) async -> Void)?
        if let atEnd = trailing {
            prepare = { root in
                #if os(macOS)
                    let scrolls = Self.descendants(root).compactMap { $0 as? NSScrollView }
                    let scroll = scrolls.first { ($0.documentView?.frame.width ?? 0) > $0.contentView.bounds.width }
                    guard let scroll, let document = scroll.documentView else {
                        Issue.record("Horizontal table scroll view unavailable")
                        return
                    }
                    let offset = atEnd ? max(0, document.frame.width - scroll.contentView.bounds.width) : 0
                    scroll.contentView.scroll(to: CGPoint(x: offset, y: 0))
                    scroll.reflectScrolledClipView(scroll.contentView)
                    root.layoutSubtreeIfNeeded()
                    root.displayIfNeeded()
                #else
                    let scrolls = Self.descendants(root).compactMap { $0 as? UIScrollView }
                    guard let scroll = scrolls.first(where: { $0.contentSize.width > $0.bounds.width }) else {
                        Issue.record("Horizontal table scroll view unavailable")
                        return
                    }
                    let offset = atEnd ? max(0, scroll.contentSize.width - scroll.bounds.width) : 0
                    scroll.setContentOffset(CGPoint(x: offset, y: 0), animated: false)
                    root.layoutIfNeeded()
                #endif
                await Task.yield()
                #if os(macOS)
                    let contentWidth = document.frame.width
                    let viewportWidth = scroll.contentView.bounds.width
                    let achievedOffset = scroll.contentView.bounds.origin.x
                #else
                    let contentWidth = scroll.contentSize.width
                    let viewportWidth = scroll.bounds.width
                    let achievedOffset = scroll.contentOffset.x
                #endif
                // Four fixed 160pt cells minus the 240pt viewport give a 400pt trailing offset.
                let intendedOffset: CGFloat = atEnd ? 400 : 0
                let diagnostic = "\(testName): intended offset \(intendedOffset), achieved offset \(achievedOffset), content width \(contentWidth), viewport width \(viewportWidth)"
                #expect(contentWidth == 640, "\(diagnostic)")
                #expect(viewportWidth == 240, "\(diagnostic)")
                #expect(achievedOffset == intendedOffset, "\(diagnostic)")
            }
        }
        let image = try await flatMarkSnapshotImage(
            of: view.fixedSize(horizontal: false, vertical: true), environment: environment,
            prepareMountedView: prepare
        )
        assertFlatMarkSnapshot(image, suite: .tables, named: "table", environment: environment, testName: testName)
    }

    private static func descendants(_ view: FlatMarkSnapshotNativeView) -> [FlatMarkSnapshotNativeView] {
        [view] + view.subviews.flatMap { descendants($0) }
    }
}
