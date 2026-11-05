#if os(macOS)
import SwiftUI
import Testing
@testable import FlatMark

@MainActor
struct FlatMarkAppKitMinimumProposalTests {
    @Test func zeroWidthProposalDoesNotReportUnwrappedIdealWidth() async throws {
        _ = try await flatMarkSnapshotImage(
            of: MinimumWidthProbe {
                FlatMarkParagraphText(
                    content: .init(text: AttributedString("A paragraph with enough words to wrap at the offered width.")),
                    role: .body, context: .readOnly
                )
            },
            environment: .standard
        )
    }
}

private struct MinimumWidthProbe: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let minimum = subviews[0].sizeThatFits(.zero)
        let ideal = subviews[0].sizeThatFits(.unspecified)
        let offered = subviews[0].sizeThatFits(ProposedViewSize(width: 140, height: nil))
        #expect(minimum.width == 0)
        #expect(ideal.width > minimum.width)
        #expect(offered.width == 140)
        return offered
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(width: 140, height: nil))
    }
}
#endif
