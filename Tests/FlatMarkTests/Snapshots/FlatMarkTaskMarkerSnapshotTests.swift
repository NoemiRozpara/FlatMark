@testable import FlatMark
import Foundation
import SwiftUI
import Testing

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@Suite(.serialized)
@MainActor
struct FlatMarkTaskMarkerSnapshotTests {
    @Test func wrappedNativeLabelExportsFirstLineBaseline() async throws {
        var text = AttributedString("Wrapped native label with enough words to occupy several lines.")
        text.font = .systemFont(ofSize: 23)
        _ = try await flatMarkSnapshotImage(
            of: WrappedLabelBaselineProbe {
                Text(text)
                FlatMarkInlineView(content: .init(text: text), context: .readOnly)
            }, environment: .standard
        )
    }

    #if os(iOS)
    @Test func accessibilityWrappedNativeLabelExportsFirstLineBaseline() async throws {
        _ = try await flatMarkSnapshotImage(
            of: WrappedLabelBaselineProbe {
                Text("Wrapped native label with enough words to occupy several lines.").font(.body)
                FlatMarkInlineView(content: "Wrapped native label with enough words to occupy several lines.", context: .readOnly)
            }.dynamicTypeSize(.accessibility5), environment: .standard
        )
    }
    #endif


}

// List rows use firstTextBaseline. Compare the native label's exported first line with
// SwiftUI text, including a host font whose metrics differ from the default body font.
private struct WrappedLabelBaselineProbe: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = ProposedViewSize(width: 140, height: nil)
        let reference = subviews[0].dimensions(in: width)
        let native = subviews[1].dimensions(in: width)
        #expect(abs(reference[.firstTextBaseline] - native[.firstTextBaseline]) < 1)
        #expect(native.height > native[.firstTextBaseline] * 2)
        return CGSize(width: 280, height: max(reference.height, native.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, view) in subviews.enumerated() {
            view.place(at: CGPoint(x: bounds.minX + CGFloat(index) * 140, y: bounds.minY),
                       proposal: ProposedViewSize(width: 140, height: nil))
        }
    }
}
