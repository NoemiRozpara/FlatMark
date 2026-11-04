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
    private static let markdown = """
    - [x] Checked parent
      - [ ] Unchecked nested label wraps with enough wording to expose its first text baseline.
      - [x] Checked nested
    - [ ] Unchecked parent
    """

    @Test func defaultInteractive() async throws { try await capture(testName: #function) }
    @Test func defaultReadOnly() async throws { try await capture(interactive: false, testName: #function) }
    @Test func defaultDisabled() async throws { try await capture(disabled: true, testName: #function) }
    @Test func customInteractive() async throws { try await capture(custom: true, testName: #function) }
    @Test func customReadOnly() async throws { try await capture(custom: true, interactive: false, testName: #function) }
    @Test func customDisabled() async throws { try await capture(custom: true, disabled: true, testName: #function) }
    @Test func customRetainedDocument() async throws { try await capture(custom: true, retained: true, testName: #function) }
    #if os(iOS)
    @Test func enlargedDefault() async throws { try await capture(enlarged: true, testName: #function) }
    @Test func enlargedCustom() async throws { try await capture(custom: true, enlarged: true, testName: #function) }
    #endif
    @Test func rtlDefaultInteractive() async throws { try await capture(direction: .rightToLeft, testName: #function) }
    @Test func rtlCustomInteractive() async throws { try await capture(custom: true, direction: .rightToLeft, testName: #function) }
    #if os(iOS)
    @Test func rtlEnlargedDefault() async throws { try await capture(enlarged: true, direction: .rightToLeft, testName: #function) }
    #endif

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
            }.dynamicTypeSize(.accessibility3), environment: .standard
        )
    }
    #endif

    private func capture(
        custom: Bool = false, interactive: Bool = true, disabled: Bool = false,
        retained: Bool = false, enlarged: Bool = false,
        direction: FlatMarkSnapshotEnvironment.LayoutDirection = .leftToRight,
        testName: String
    ) async throws {
        let environment = FlatMarkSnapshotEnvironment(
            captureSize: CGSize(width: 700, height: enlarged ? 1500 : 650),
            columnWidth: 280, contentInset: 150, pixelScale: 2, appearance: .light,
            localeIdentifier: "en_US", layoutDirection: direction,
            textSize: enlarged ? .enlarged : .body
        )
        // The shared fixture is not compiled into the snapshot targets.
        let marker: FlatMarkTaskMarker = custom ? .custom { checked in
            Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .foregroundStyle(.purple)
        } : .default
        let action: ((String) -> Void)? = interactive ? { _ in } : nil
        let view = retained
            ? FlatMarkView(document: FlatMarkDocument(markdown: Self.markdown), taskToggleAction: action, taskMarker: marker)
            : FlatMarkView(markdown: Self.markdown, taskToggleAction: action, taskMarker: marker)
        let image = try await flatMarkSnapshotImage(
            of: view.disabled(disabled).fixedSize(horizontal: false, vertical: true), environment: environment
        )
        assertFlatMarkSnapshot(image, suite: .taskMarkers, named: "document", environment: environment, testName: testName)
    }
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
