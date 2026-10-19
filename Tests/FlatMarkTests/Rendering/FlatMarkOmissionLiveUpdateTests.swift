#if os(macOS)
    @testable import FlatMark
    import FlatMarkFixtures
    import Foundation
    import Testing

    @MainActor
    struct FlatMarkOmissionLiveUpdateTests {
        @Test
        func `public view restores omitted content without reloading its image`() async throws {
            let model = FlatMarkCustomFixtureModel(markdown: FlatMarkCustomFixtureModel.omissionMarkdown)
            let mounted = await mountTestView(
                FlatMarkCustomDocumentFixture(model: model), size: CGSize(width: 400, height: 1000)
            )
            defer { mounted.close() }
            try await waitForImage(in: model.imageCalls)
            let imageURL = try #require(URL(string: "https://example.com/image.png"))
            #expect(mounted.showsContent)
            #expect(model.markdown == FlatMarkCustomFixtureModel.omissionMarkdown)
            #expect(try model.imageCalls.urls == [imageURL])

            model.policyKind = .omit
            await settleMountedRendering()
            #expect(mounted.showsContent)
            #expect(model.markdown == FlatMarkCustomFixtureModel.omissionMarkdown)
            #expect(model.imageCalls.urls == [imageURL])
            #expect(model.taskUpdates == 0)

            let original = FlatMarkRenderProjector.project(
                markdown: FlatMarkCustomFixtureModel.omissionMarkdown,
                baseURL: URL(string: "https://example.com/")
            )
            let reference = FlatMarkRenderProjector.project(
                markdown: FlatMarkCustomFixtureModel.omissionReferenceMarkdown,
                baseURL: URL(string: "https://example.com/")
            )
            #expect(visibleDocument(original, policy: .omit) == visibleDocument(reference, policy: .omit))
            #expect(reference.blocks.allSatisfy { FlatMarkUnsupportedContentPolicy.omit.presents($0) })

            model.policyKind = .literal
            await settleMountedRendering()
            #expect(mounted.showsContent)
            #expect(model.markdown == FlatMarkCustomFixtureModel.omissionMarkdown)
            #expect(model.taskUpdates == 0)
            #expect(model.imageCalls.urls.count == 1)
        }

        @Test
        func `omitted-label checkbox toggles only its own source byte after switching`() async throws {
            let markdown = FlatMarkCustomFixtureModel.omissionMarkdown
            let report = try await nativeHostReport(arguments: ["--task-interaction", "omit", markdown])
            let expected = markdown.replacingOccurrences(of: "- [ ] <u></u>", with: "- [x] <u></u>")
            #expect(report["completed"] == ["true"])
            #expect(report["initialMarkdown"] == [markdown])
            #expect(report["initialCheckboxStates"] == ["0", "1", "1"])
            #expect(report["checkboxEnabled"] == ["true"])
            #expect(report["initialTaskUpdates"] == ["0"])
            #expect(report["updates"] == [expected])
            #expect(report["markdown"] == [expected])
            #expect(report["taskUpdates"] == ["1"])
            #expect(report["finalCheckboxStates"] == ["1", "1", "1"])
            #expect(report["initialLoaded"] == ["https://example.com/image.png"])
            #expect(report["loaded"] == report["initialLoaded"])
        }
    }
#endif
