import SwiftUI

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

        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
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

private struct Item {
    let index: Int
    let size: CGSize
    let baseline: CGFloat
}

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
