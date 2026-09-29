import Testing
@testable import FlatMark

// MARK: - FlatMarkTableViewTests

@MainActor
struct FlatMarkTableViewTests {
    @Test
    func `renders a table with a header and no body rows`() {
        let view = FlatMarkTableView(
            table: FlatMarkRenderTable(
                header: [
                    .init(id: "header.name", content: "Name", colspan: 1),
                ],
                rows: []
            )
        )

        #expect(view.rendersTable)
    }

    @Test
    func `does not render an empty table`() {
        let view = FlatMarkTableView(
            table: FlatMarkRenderTable(header: [], rows: [])
        )

        #expect(!view.rendersTable)
    }
}
