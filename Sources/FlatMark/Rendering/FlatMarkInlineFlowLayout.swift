import SwiftUI

// MARK: - FlatMarkInlineFlowLayout

/// Places inline Markdown elements on shared text baselines and wraps them as a paragraph.
struct FlatMarkInlineFlowLayout: Layout {
    struct LineBreakKey: LayoutValueKey {
        static let defaultValue = false
    }

    let layoutDirection: LayoutDirection

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width)
        let fittingWidth = rows.map(\.width).max() ?? 0
        // Report the width this layout places. Reporting the proposal instead makes the view
        // wider than its own lines, and that unused width shifts the view wherever a frame
        // smaller than the proposal sizes it. A lone item that cannot fit keeps the offer.
        let width = proposal.width.map { min($0, fittingWidth) } ?? fittingWidth

        return CGSize(
            width: width,
            height: rows.reduce(0) { $0 + $1.height }
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        let rows = rows(for: subviews, width: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = layoutDirection == .rightToLeft ? bounds.maxX : bounds.minX

            for item in row.items {
                if layoutDirection == .rightToLeft {
                    x -= item.size.width
                }

                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + row.baseline - item.baseline),
                    proposal: ProposedViewSize(item.size)
                )

                if layoutDirection != .rightToLeft {
                    x += item.size.width
                }
            }

            y += row.height
        }
    }

    private func rows(for subviews: Subviews, width: CGFloat?) -> [Row] {
        let availableWidth = width ?? .infinity
        let itemProposal = ProposedViewSize(width: width, height: nil)
        var rows: [Row] = []
        var row = Row()

        for index in subviews.indices {
            if subviews[index][LineBreakKey.self] {
                if !row.items.isEmpty {
                    rows.append(row)
                    row = Row()
                }
                continue
            }

            let dimensions = subviews[index].dimensions(in: itemProposal)
            let item = Item(
                index: index,
                size: CGSize(width: dimensions.width, height: dimensions.height),
                baseline: dimensions[.firstTextBaseline]
            )

            if !row.items.isEmpty, row.width + item.size.width > availableWidth {
                rows.append(row)
                row = Row()
            }

            row.append(item)
        }

        if !row.items.isEmpty {
            rows.append(row)
        }

        return rows
    }
}

// MARK: - Item

private struct Item {
    let index: Int
    let size: CGSize
    let baseline: CGFloat
}

// MARK: - Row

private struct Row {
    private(set) var items: [Item] = []
    private(set) var width: CGFloat = 0
    private(set) var baseline: CGFloat = 0
    private(set) var descent: CGFloat = 0

    var height: CGFloat {
        baseline + descent
    }

    mutating func append(_ item: Item) {
        items.append(item)
        width += item.size.width
        baseline = max(baseline, item.baseline)
        descent = max(descent, item.size.height - item.baseline)
    }
}
