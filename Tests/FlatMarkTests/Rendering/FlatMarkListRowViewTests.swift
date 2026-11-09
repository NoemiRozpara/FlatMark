@testable import FlatMark
import SwiftUI
import Testing

// MARK: - FlatMarkListRowViewTests

@MainActor
struct FlatMarkListRowViewTests {
    /// The editing address of a projected task that starts on line 3.
    private let address = FlatMarkSourceRange(
        lowerBound: .init(line: 3, column: 1),
        upperBound: .init(line: 3, column: 13)
    )

    @Test
    func `an addressed task offers the host its editing address only when a callback exists`() throws {
        let spy = ToggleSpy()
        let interactive = makeRowView(marker: .task(isChecked: false, sourceRange: address), hostAction: spy.action)
        let toggle = try #require(interactive.taskToggleAction)

        toggle()
        #expect(spy.addresses == [address])

        // Read-only rendering offers nothing to invoke.
        let readOnly = makeRowView(marker: .task(isChecked: true, sourceRange: address), hostAction: nil)
        #expect(readOnly.taskToggleAction == nil)
    }

    @Test
    func `a task with no editing address stays static content`() {
        // A task that cannot be addressed keeps showing its checked state as ordinary content.
        let readOnly = makeRowView(marker: .task(isChecked: true, sourceRange: nil), hostAction: nil)

        #expect(readOnly.taskToggleAction == nil)

        // An unaddressable task paired with a callback is the debug-asserting branch. It is
        // unreachable through a projected document, and a crash aborts this process rather
        // being observable in place, so it stays out of the automated run.
    }

    @Test
    func `non-task markers are never offered as tasks`() {
        let spy = ToggleSpy()

        for marker: FlatMarkListMarker in [.unordered, .ordered(index: 3)] {
            #expect(makeRowView(marker: marker, hostAction: spy.action).taskToggleAction == nil)
        }
    }

    /// Switching the unsupported-content policy keeps row identity and the task's editing address.
    @Test
    func `policy changes preserve structural IDs and task editing addresses`() throws {
        let markdown = "Before\n\n<div>raw</div>\n\n- [ ] task <u>x</u>\n\n  <div>continuation</div>\n\nAfter"
        let document = FlatMarkRenderProjector.project(markdown: markdown)
        #expect(document.blocks.map(\.id) == (0 ..< 4).map { FlatMarkRenderNodeID(path: [$0]) })
        guard case let .list(entries) = document.blocks[2].kind,
              case let .row(row) = try #require(entries.first),
              case let .task(_, optionalAddress) = row.marker
        else {
            Issue.record("Expected an addressable task row")
            return
        }

        let address = try #require(optionalAddress)
        #expect(entries.map(\.id) == [
            FlatMarkRenderNodeID(path: [2, 0]), FlatMarkRenderNodeID(path: [2, 0, 1]),
        ])

        var toggled: [String] = []
        let policies: [FlatMarkUnsupportedContentPolicy] = [.literal, .omit, .literal]
        for policy in policies {
            let view = FlatMarkListRowView(row: row, context: FlatMarkRenderContext(
                unsupportedContentPolicy: policy,
                taskToggleAction: { receivedAddress in
                    #expect(receivedAddress == address)
                    if let updated = FlatMarkTaskMarkerToggle.toggledMarkdown(
                        in: markdown, sourceRange: receivedAddress
                    ) {
                        toggled.append(updated)
                    }
                }
            ))
            let toggle = try #require(view.taskToggleAction)
            toggle()
        }

        // One address serves every policy, so a switch never strands an edit on a stale range.
        #expect(toggled == Array(
            repeating: markdown.replacingOccurrences(of: "[ ]", with: "[x]"),
            count: policies.count
        ))
    }

    @Test(arguments: [
        ("literal", "Level 1 task: Buy <u>milk</u>", "Level 1 task: Call <u>doctor</u>"),
        ("omit", "Level 1 task: Buy milk", "Level 1 task: Call doctor"),
    ] as [(String, String, String)])
    func `task controls resolve distinct names under every unsupported-content policy`(
        policyName: String,
        firstName: String,
        secondName: String
    ) throws {
        let policy: FlatMarkUnsupportedContentPolicy =
            switch policyName {
            case "literal": .literal
            default: .omit
            }
        let rows = try #require(taskRows(in: "- [ ] Buy <u>milk</u>\n- [ ] Call <u>doctor</u>"))

        // Two tasks at the same level must never collapse into one generic name, under any policy.
        let names = rows.map { row in
            FlatMarkListRowView(
                row: row,
                context: FlatMarkRenderContext(unsupportedContentPolicy: policy)
            ).taskAccessibilityLabel
        }
        #expect(names == [firstName, secondName])
    }

    private func taskRows(in markdown: String) -> [FlatMarkListRenderRow]? {
        guard case let .list(entries)? = FlatMarkRenderProjector.project(markdown: markdown).blocks.first?.kind
        else {
            return nil
        }

        return entries.compactMap { entry -> FlatMarkListRenderRow? in
            guard case let .row(row) = entry else {
                return nil
            }

            return row
        }
    }

    private func makeRowView(
        marker: FlatMarkListMarker,
        hostAction: ((FlatMarkSourceRange) -> Void)?
    ) -> FlatMarkListRowView {
        FlatMarkListRowView(
            row: FlatMarkListRenderRow(
                id: FlatMarkRenderNodeID(path: [0, 1]),
                indentation: 1,
                marker: marker,
                content: "Nested task"
            ),
            context: FlatMarkRenderContext(taskToggleAction: hostAction)
        )
    }
}

// MARK: - ToggleSpy

@MainActor
private final class ToggleSpy {
    private(set) var addresses: [FlatMarkSourceRange] = []

    var action: ((FlatMarkSourceRange) -> Void)? {
        { self.addresses.append($0) }
    }
}
