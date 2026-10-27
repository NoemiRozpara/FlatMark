#if os(macOS)
    import FlatMark
    import SwiftUI
    import Testing

    @MainActor
    struct FlatMarkTaskMarkerTests {
        @Test(arguments: ["interactive", "readOnly", "disabled"])
        func `custom markers preserve task editing policy and source`(mode: String) async throws {
            let markdown = "- [x] Parent\n  - [ ] Child [Details](https://example.com/details)"
            let report = try await nativeHostReport(arguments: ["--task-interaction", "marker-" + mode, markdown])
            #expect(report["states"] == ["false", "true"])
            #expect(report["updates"] == (mode == "interactive"
                ? ["- [x] Parent\n  - [x] Child [Details](https://example.com/details)"] : []))
            #expect(report["completed"] == ["true"])
        }

        @Test(arguments: [false, true], [false, true])
        func `host draws checked and nested unchecked markers through either initializer`(
            retainedDocument: Bool, interactive: Bool
        ) async throws {
            let markdown = "- [x] Parent\n  - [ ] Child"
            var states: Set<Bool> = []
            let marker = FlatMarkTaskMarker.custom { isChecked in
                states.insert(isChecked)
                return Image(systemName: isChecked ? "checkmark.circle" : "circle")
            }
            let action: ((String) -> Void)? = interactive ? { _ in } : nil
            let view = retainedDocument
                ? FlatMarkView(document: FlatMarkDocument(markdown: markdown), taskToggleAction: action, taskMarker: marker)
                : FlatMarkView(markdown: markdown, taskToggleAction: action, taskMarker: marker)
            let hosted = await mountTestView(view)
            defer { hosted.close() }

            #expect(states == [false, true])
            #expect(try hosted.visibleText == "ParentChild")
        }
    }
#endif
