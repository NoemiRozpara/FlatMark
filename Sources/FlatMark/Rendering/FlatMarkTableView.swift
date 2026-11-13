import SwiftUI

// MARK: - FlatMarkTableView

struct FlatMarkTableView: View {
    private let cellWidth: CGFloat = 160

    let table: FlatMarkRenderTable
    let context: FlatMarkRenderContext

    var rendersTable: Bool {
        !table.header.isEmpty
    }

    var body: some View {
        if rendersTable {
            ScrollView(.horizontal) {
                Grid(
                    alignment: .topLeading,
                    horizontalSpacing: 0,
                    verticalSpacing: 0
                ) {
                    GridRow {
                        ForEach(table.header) { cell in
                            fixedWidthCell(FlatMarkInlineView(content: cell.content, context: context, role: .tableHeader))
                                .accessibilityAddTraits(.isHeader)
                        }
                    }

                    ForEach(table.rows) { row in
                        Divider()
                            .gridCellUnsizedAxes(.horizontal)
                            .background(.secondary)
                        GridRow {
                            ForEach(row.cells) { cell in
                                fixedWidthCell(FlatMarkInlineView(content: cell.content, context: context))
                                    .gridCellColumns(cell.colspan)
                            }
                        }
                    }
                }
                .border(.secondary)
            }
        }
    }

    private func fixedWidthCell(_ view: some View) -> some View {
        view
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(8)
            .frame(width: cellWidth, alignment: .topLeading)
    }
}

#Preview("Markdown Table") {
    FlatMarkTableView(
        table: FlatMarkRenderTable(
            header: [
                .init(id: .init(path: [0, 0, 0]), content: "Owner", colspan: 1),
                .init(id: .init(path: [0, 0, 1]), content: "Status", colspan: 1),
                .init(id: .init(path: [0, 0, 2]), content: "Notes", colspan: 1),
            ],
            rows: [
                .init(
                    id: .init(path: [0, 1, 0]),
                    cells: [
                        .init(id: .init(path: [0, 1, 0, 0]), content: "Alice", colspan: 2),
                        .init(
                            id: .init(path: [0, 1, 0, 2]),
                            content: "Confirm the release notes before publishing. Some very long text. Confirm the release notes before publishing. Some very long text. Confirm the release notes before publishing. Some very long text.",
                            colspan: 1
                        ),
                    ]
                ),
                .init(
                    id: .init(path: [0, 1, 1]),
                    cells: [
                        .init(id: .init(path: [0, 1, 1, 0]), content: "Alex", colspan: 1),
                        .init(id: .init(path: [0, 1, 1, 1]), content: "In progress", colspan: 1),
                        .init(id: .init(path: [0, 1, 1, 2]), content: "Waiting for review.", colspan: 1),
                    ]
                ),
            ]
        ),
        context: .readOnly
    )
    .padding()
}
