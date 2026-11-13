@testable import FlatMark
import Foundation
import Testing

// MARK: - Reader-visible shape

/// The projected shape of a document under one of the two built-in policies: one entry per block
/// that survives `policy`, saying what kind of block it is, in what order and nesting, and which
/// wording it carries.
///
/// This is the oracle for "which blocks survive a policy, and what do they say" assertions, and
/// for nothing else. Geometry is deliberately absent, because SwiftUI is free to re-layout the
/// same document.
func visibleDocument(
    _ document: FlatMarkRenderDocument,
    policy: FlatMarkUnsupportedContentPolicy
) -> [String] {
    return document.blocks.filter(policy.presents).map { visible($0, policy: policy) }
}

/// The wording one inline span contributes under `policy`, in source order: supported text and
/// images as themselves, and unsupported nodes either as their inert literal text (`.literal`) or
/// as nothing (`.omit`).
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
