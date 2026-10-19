@testable import FlatMark
import Foundation
import Testing

// MARK: - FlatMarkHostAddress

/// Where a `.custom` policy places one host view: `path` addresses the block, list row, or table
/// cell that carries the unsupported node, and `component` is that node's index inside the span's
/// inline components, or `nil` when a whole block was handed over.
///
/// An address comes from the projection alone, so it states the position the *source* had rather
/// than the position one SwiftUI build happened to lay out.
struct FlatMarkHostAddress: Equatable, Sendable {
    let path: [Int]
    let component: Int?
    let payload: String
}

extension FlatMarkHostAddress: CustomStringConvertible {
    var description: String {
        var text = "host(path: \(path)"
        if let component {
            text += ", component: \(component)"
        }
        return text + ", payload: \(String(reflecting: payload)))"
    }
}

/// An expected host address, spelled compactly in a test's arguments.
func host(_ payload: String, path: [Int], component: Int? = nil) -> FlatMarkHostAddress {
    FlatMarkHostAddress(path: path, component: component, payload: payload)
}

// MARK: - Render-tree attribution

/// Every node a `.custom` policy hands to a host view, in document order.
///
/// An unsupported node inside an image description is not listed: no host view can appear inside
/// an image's label, which is why the label simply drops it.
func customHosts(in document: FlatMarkRenderDocument) -> [FlatMarkHostAddress] {
    customHosts(in: document.blocks)
}

func customHosts(in blocks: [FlatMarkRenderBlock]) -> [FlatMarkHostAddress] {
    blocks.flatMap { block -> [FlatMarkHostAddress] in
        switch block.kind {
        case let .unsupported(unsupported):
            [host(String(unsupported.literalText.characters), path: block.id.path)]
        case let .paragraph(content), let .heading(_, content):
            customHosts(in: content, path: block.id.path)
        case let .blockQuote(children):
            customHosts(in: children)
        case let .list(entries):
            entries.flatMap { entry -> [FlatMarkHostAddress] in
                switch entry {
                case let .row(row):
                    customHosts(in: row.content, path: row.id.path)
                case let .childBlock(childBlock):
                    customHosts(in: [childBlock.block])
                }
            }
        case let .table(table):
            customHosts(in: table.header) + table.rows.flatMap { customHosts(in: $0.cells) }
        case .codeBlock, .thematicBreak:
            []
        }
    }
}

func customHosts(in content: FlatMarkRenderInlineContent, path: [Int]) -> [FlatMarkHostAddress] {
    content.components.enumerated().compactMap { index, component in
        guard case let .unsupported(unsupported) = component else {
            return nil
        }

        return host(String(unsupported.literalText.characters), path: path, component: index)
    }
}

private func customHosts(in cells: [FlatMarkRenderTable.Cell]) -> [FlatMarkHostAddress] {
    cells.flatMap { customHosts(in: $0.content, path: $0.id.path) }
}

// MARK: - Reader-visible shape

/// The projected shape of a document under one of the two built-in policies: one entry per block
/// that survives `policy`, saying what kind of block it is, in what order and nesting, and which
/// wording it carries.
///
/// This is the oracle for "which blocks survive a policy, and what do they say" assertions, and
/// for nothing else. Geometry is deliberately absent, because SwiftUI is free to re-layout the
/// same document. `.custom` is deliberately absent too: what a host view draws is a mounted
/// observation, so the tree only ever says which nodes were handed over and where they sit, which
/// is what ``customHosts(in:)`` answers.
func visibleDocument(
    _ document: FlatMarkRenderDocument,
    policy: FlatMarkUnsupportedContentPolicy
) -> [String] {
    if case .custom = policy {
        Issue.record("A custom host's output is a mounted observation, not a render-tree shape.")
        return []
    }

    return document.blocks.filter(policy.presents).map { visible($0, policy: policy) }
}

/// The wording one inline span contributes under `policy`, in source order: supported text and
/// images as themselves, and unsupported nodes either as their inert literal text (`.literal`) or
/// as nothing (`.omit`). A `.custom` node never reaches here, because `visibleDocument` rejects
/// that policy before asking.
private func visibleText(
    _ content: FlatMarkRenderInlineContent,
    policy: FlatMarkUnsupportedContentPolicy
) -> String {
    content.components.map { component in
        switch component {
        case let .text(text):
            oneLine(String(text.characters))
        case let .image(image):
            "image(\(visibleImage(image, policy: policy)))"
        case let .unsupported(unsupported):
            oneLine(String(policy.literalText(for: unsupported).characters))
        }
    }.joined()
}

private func visible(_ block: FlatMarkRenderBlock, policy: FlatMarkUnsupportedContentPolicy) -> String {
    switch block.kind {
    case let .paragraph(content):
        "paragraph: \(visibleText(content, policy: policy))"
    case let .heading(level, content):
        "h\(level): \(visibleText(content, policy: policy))"
    case let .codeBlock(code):
        "code: \(oneLine(code))"
    case let .blockQuote(children):
        group("quote", lines(of: children, policy: policy))
    case let .list(entries):
        group("list", lines(of: entries, policy: policy))
    case .thematicBreak:
        "divider"
    case let .table(table):
        group("table", lines(of: table, policy: policy))
    case let .unsupported(unsupported):
        "unsupported: \(String(reflecting: String(unsupported.literalText.characters)))"
    }
}

private func lines(of blocks: [FlatMarkRenderBlock], policy: FlatMarkUnsupportedContentPolicy) -> [String] {
    // Whole unsupported blocks only reach here under `.literal`; `.omit` filters them out upstream.
    blocks.filter(policy.presents).map { visible($0, policy: policy) }
}

private func lines(
    of entries: [FlatMarkListRenderEntry],
    policy: FlatMarkUnsupportedContentPolicy
) -> [String] {
    entries.flatMap { entry -> [String] in
        switch entry {
        case let .row(row):
            return ["row \(markerDescription(row.marker)): \(visibleText(row.content, policy: policy))"]
        case let .childBlock(childBlock):
            return policy.presents(childBlock.block)
                ? ["child:\n" + indent(visible(childBlock.block, policy: policy))]
                : []
        }
    }
}

private func lines(of table: FlatMarkRenderTable, policy: FlatMarkUnsupportedContentPolicy) -> [String] {
    [
        "header: \(table.header.map { visibleText($0.content, policy: policy) }.joined(separator: " | "))",
    ] + table.rows.map { row in
        "row: \(row.cells.map { visibleText($0.content, policy: policy) }.joined(separator: " | "))"
    }
}

private func visibleImage(_ image: FlatMarkRenderImage, policy: FlatMarkUnsupportedContentPolicy) -> String {
    var parts: [String] = []
    if let url = image.url {
        parts.append("url: \(url.absoluteString)")
    }
    // An image label is plain text, so this is what a reader hears whatever the policy is.
    parts.append("alt: \(String(reflecting: policy.plainText(for: image.altContent)))")
    if let link = image.link {
        parts.append("link: \(link.absoluteString)")
    }

    return parts.joined(separator: ", ")
}

private func group(_ label: String, _ lines: [String]) -> String {
    guard !lines.isEmpty else {
        return "\(label): {}"
    }

    return "\(label): {\n" + lines.map(indent).joined(separator: "\n") + "\n}"
}

/// Adds one nesting level, so a nested group stays readable inside a group.
private func indent(_ text: String) -> String {
    "  " + text.replacingOccurrences(of: "\n", with: "\n  ")
}

/// Keeps one rendered span inside one line, so a shape stays readable when Markdown breaks a run.
private func oneLine(_ text: String) -> String {
    text.replacingOccurrences(of: "\n", with: "↵")
}

private func markerDescription(_ marker: FlatMarkListMarker) -> String {
    switch marker {
    case .unordered:
        "•"
    case let .ordered(index):
        "\(index)."
    case let .task(isChecked, _):
        isChecked ? "checked" : "unchecked"
    }
}
