import SwiftUI

// MARK: - FlatMarkDocumentView

struct FlatMarkDocumentView: View {
    let document: FlatMarkRenderDocument
    let context: FlatMarkRenderContext

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            FlatMarkBlocks(blocks: document.blocks, context: context)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - FlatMarkBlocks

private struct FlatMarkBlocks: View {
    let blocks: [FlatMarkRenderBlock]
    let context: FlatMarkRenderContext

    var body: some View {
        ForEach(visibleBlocks) { block in
            FlatMarkBlockView(
                block: block,
                context: context
            )
        }
    }

    /// The blocks this policy lays out, in document order.
    ///
    /// Omitted blocks are absent from the list rather than emptied, so the gap between two
    /// supported blocks matches the same document without the unsupported one.
    private var visibleBlocks: [FlatMarkRenderBlock] {
        blocks.filter { context.unsupportedContentPolicy.presents($0) }
    }
}

// MARK: - FlatMarkBlockView

struct FlatMarkBlockView: View {
    let block: FlatMarkRenderBlock
    let context: FlatMarkRenderContext

    var body: some View {
        switch block.kind {
        case let .paragraph(content):
            FlatMarkInlineView(content: content, context: context)

        case let .heading(level, content):
            FlatMarkInlineView(content: content, context: context, role: .heading(level: level))
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

                VStack(alignment: .leading, spacing: 16) {
                    FlatMarkBlocks(blocks: blocks, context: context)
                }
            }

        case let .list(entries):
            FlatMarkListView(entries: entries, context: context)

        case .thematicBreak:
            Divider()

        case let .table(table):
            FlatMarkTableView(table: table, context: context)

        case let .unsupported(content):
            FlatMarkInlineView(
                content: FlatMarkRenderInlineContent(components: [.unsupported(content)]),
                context: context
            )
        }
    }
}
