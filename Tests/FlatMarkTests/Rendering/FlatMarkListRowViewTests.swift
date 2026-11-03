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

    @Test(arguments: [
        ("literal", "Level 1 task: Buy <u>milk</u>", "Level 1 task: Call <u>doctor</u>"),
        ("omit", "Level 1 task: Buy milk", "Level 1 task: Call doctor"),
        ("custom", "Level 1 task: Buy milk", "Level 1 task: Call doctor"),
    ] as [(String, String, String)])
    func `task controls resolve distinct names under every unsupported-content policy`(
        policyName: String,
        firstName: String,
        secondName: String
    ) throws {
        let policy: FlatMarkUnsupportedContentPolicy =
            switch policyName {
            case "literal": .literal
            case "omit": .omit
            default: .custom(inline: { _ in AttributedString() })
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
