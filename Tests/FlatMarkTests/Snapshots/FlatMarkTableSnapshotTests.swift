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

    @Test func multilineNativeCellsStaySeparateFromNextRow() async throws {
        try await checkNativeRows(enlarged: false)
    }

    #if os(iOS)
    @Test func accessibilityMultilineNativeCellsStaySeparateFromNextRow() async throws {
        try await checkNativeRows(enlarged: true)
    }
    #endif

    private func checkNativeRows(enlarged: Bool) async throws {
        let environment = FlatMarkSnapshotEnvironment(
            captureSize: CGSize(width: 700, height: 1900), columnWidth: 360,
            contentInset: 100, pixelScale: 2, appearance: .light,
            localeIdentifier: "en_US", layoutDirection: .leftToRight,
            textSize: enlarged ? .enlarged : .body
        )
        _ = try await flatMarkSnapshotImage(
            of: FlatMarkView(markdown: """
            | Header | Neighbor |
            | --- | --- |
            | Long native cell wraps through several lines and ends with FIRST END. | Short cell. |
            | NEXT ROW | Last cell. |
            """).fixedSize(horizontal: false, vertical: true),
            environment: environment,
            prepareMountedView: { root in
                #if os(macOS)
                let texts = Self.descendants(root).compactMap { $0 as? NSTextView }
                let first = texts.first { $0.string.hasPrefix("Long native") }
                let next = texts.first { $0.string == "NEXT ROW" }
                #else
                let texts = Self.descendants(root).compactMap { $0 as? UITextView }
                let first = texts.first { $0.text.hasPrefix("Long native") }
                let next = texts.first { $0.text == "NEXT ROW" }
                #endif
                guard let first, let next else {
                    Issue.record("Expected native cells in both table rows")
                    return
                }
                let firstFrame = first.convert(first.bounds, to: root)
                let nextFrame = next.convert(next.bounds, to: root)
                #expect(firstFrame.maxY <= nextFrame.minY)
                #expect(first.bounds.height > next.bounds.height * 2)
                #if os(macOS)
                if let manager = first.layoutManager, let container = first.textContainer {
                    manager.ensureLayout(for: container)
                    #expect(manager.usedRect(for: container).maxY <= first.bounds.height + 1)
                } else {
                    Issue.record("Expected native table cell layout")
                }
                #else
                if let manager = first.textLayoutManager {
                    manager.ensureLayout(for: manager.documentRange)
                    var bottom: CGFloat = 0
                    manager.enumerateTextLayoutFragments(from: manager.documentRange.location,
                                                        options: [.ensuresLayout]) { fragment in
                        bottom = max(bottom, fragment.layoutFragmentFrame.maxY)
                        return true
                    }
                    #expect(bottom > 0)
                    #expect(bottom <= first.bounds.height + 1)
                } else {
                    let manager = first.layoutManager
                    manager.ensureLayout(for: first.textContainer)
                    #expect(manager.usedRect(for: first.textContainer).maxY <= first.bounds.height + 1)
                }
                #endif
            }
        )
    }

    @Test func wideLongCells() async throws {
        try await capture(FlatMarkView(markdown: Self.longTable), column: 700, testName: #function)
    }

    @Test func narrowLeading() async throws {
        try await capture(FlatMarkView(markdown: Self.longTable), column: 240, trailing: false, testName: #function)
    }

    @Test func narrowTrailing() async throws {
        try await capture(FlatMarkView(markdown: Self.longTable), column: 240, trailing: true, testName: #function)
    }

    #if os(iOS)
    @Test func enlargedLongCells() async throws {
        try await capture(FlatMarkView(markdown: Self.longTable), column: 320, textSize: .enlarged, testName: #function)
    }
    #endif

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
