#if os(macOS)
import AppKit
import Testing
@testable import FlatMark

struct FlatMarkAppKitBaselineIsolationTests {
    @MainActor
    @Test func independentBaselineLayoutPreservesWidthContentAndTypography() async {
        let small = AttributedString(NSAttributedString(string: "First ", attributes: [
            .font: NSFont.systemFont(ofSize: 12)
        ]))
        let large = AttributedString(NSAttributedString(string: "Large", attributes: [
            .font: NSFont.systemFont(ofSize: 40)
        ]))
        let mixed = FlatMarkParagraphText(
            content: .init(components: [.text(small), .text(large)]), role: .body, context: .readOnly
        )
        let body = FlatMarkParagraphText(content: "First", role: .body, context: .readOnly)
        let heading = FlatMarkParagraphText(content: "First", role: .heading(level: 1), context: .readOnly)
        let empty = FlatMarkParagraphText(content: "", role: .body, context: .readOnly)
        let expected = mixed.firstBaseline(width: 300)

        // A detached task exercises the same synchronous entry point as the nonisolated guide.
        await Task.detached {
            #expect(mixed.firstBaseline(width: 300) == expected)
            #expect(mixed.firstBaseline(width: 50) < expected)
            #expect(heading.firstBaseline(width: 300) > body.firstBaseline(width: 300))
            #expect(empty.firstBaseline(width: 300) == 0)
        }.value
    }
}
#endif
