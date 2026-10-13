import SwiftUI
import Testing
@testable import FlatMark

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
