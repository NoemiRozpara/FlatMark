import SwiftUI

// MARK: - FlatMarkDocumentView

struct FlatMarkDocumentView: View {
    let document: FlatMarkRenderDocument
    var taskToggleAction: ((FlatMarkRenderNodeID) -> Void)? = nil

    var body: some View {
        FlatMarkBlockListView(
            blocks: document.blocks,
            taskToggleAction: taskToggleAction
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - FlatMarkBlockListView

private struct FlatMarkBlockListView: View {
    let blocks: [FlatMarkRenderBlock]
    var taskToggleAction: ((FlatMarkRenderNodeID) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(blocks) { block in
                FlatMarkBlockView(
                    block: block,
                    taskToggleAction: taskToggleAction
                )
            }
        }
    }
}

// MARK: - FlatMarkBlockView

struct FlatMarkBlockView: View {
    let block: FlatMarkRenderBlock
    var taskToggleAction: ((FlatMarkRenderNodeID) -> Void)? = nil

    var body: some View {
        switch block.kind {
        case let .paragraph(content):
            Text(content)

        case let .heading(level, content):
            Text(content)
                .font(font(for: level))
                .bold()
                .accessibilityAddTraits(.isHeader)

        case let .codeBlock(content):
            Text(content)
                .font(.body.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

        case let .blockQuote(blocks):
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(.secondary)
                    .frame(width: 2)

                FlatMarkBlockListView(
                    blocks: blocks,
                    taskToggleAction: taskToggleAction
                )
            }

        case let .list(entries):
            FlatMarkListView(
                entries: entries,
                taskToggleAction: taskToggleAction
            )

        case .thematicBreak:
            Divider()

        case let .table(table):
            FlatMarkTableView(table: table)

        case let .fallback(type, content):
            Text("\(type): \(content)")
                .foregroundStyle(.secondary)
        }
    }

    private func font(for level: Int) -> Font {
        switch level {
        case 1:
            .title
        case 2:
            .title2
        case 3:
            .title3
        default:
            .headline
        }
    }
}

// MARK: - FlatMarkTableView

struct FlatMarkTableView: View {
    private let cellWidth: CGFloat = 160

    let table: FlatMarkRenderTable

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
                            adaptivelySized(Text(cell.content))
                                .bold()
                                .accessibilityAddTraits(.isHeader)
                        }
                    }

                    ForEach(table.rows) { row in
                        Divider()
                            .gridCellUnsizedAxes(.horizontal)
                            .background(.secondary)
                        GridRow {
                            ForEach(row.cells) { cell in
                                adaptivelySized(Text(cell.content))
                                    .gridCellColumns(cell.colspan)
                            }
                        }
                    }
                }
                .border(.secondary)
            }
        }
    }

    private func adaptivelySized(_ view: Text) -> some View {
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
                .init(id: "header.owner", content: "Owner", colspan: 1),
                .init(id: "header.status", content: "Status", colspan: 1),
                .init(id: "header.notes", content: "Notes", colspan: 1),
            ],
            rows: [
                .init(
                    id: "ready",
                    cells: [
                        .init(id: "ready.owner", content: "Noemi", colspan: 2),
                        .init(
                            id: "ready.notes",
                            content: "Confirm the release notes before publishing. Some very long text. Confirm the release notes before publishing. Some very long text. Confirm the release notes before publishing. Some very long text.",
                            colspan: 1
                        ),
                    ]
                ),
                .init(
                    id: "in-progress",
                    cells: [
                        .init(id: "in-progress.owner", content: "Alex", colspan: 1),
                        .init(id: "in-progress.status", content: "In progress", colspan: 1),
                        .init(id: "in-progress.notes", content: "Waiting for review.", colspan: 1),
                    ]
                ),
            ]
        )
    )
    .padding()
}
