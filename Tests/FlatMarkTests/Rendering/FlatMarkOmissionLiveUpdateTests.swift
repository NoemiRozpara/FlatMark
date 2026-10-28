#if os(macOS)
    @testable import FlatMark
    import FlatMarkFixtures
    import Foundation
    import Testing

    @MainActor
    struct FlatMarkOmissionLiveUpdateTests {
        @Test
        func `public view restores omitted content without reloading its image`() async throws {
            let model = FlatMarkCustomFixtureModel(markdown: OmissionSample.markdown)
            let mounted = await mountTestView(
                FlatMarkCustomDocumentFixture(model: model), size: CGSize(width: 400, height: 1000)
            )
            defer { mounted.close() }
            try await waitForImage(in: model.imageCalls)
            let imageURL = try #require(URL(string: "https://example.com/image.png"))
            #expect(mounted.showsContent)
            #expect(model.markdown == OmissionSample.markdown)
            #expect(try model.imageCalls.urls == [imageURL])

            model.policyKind = .omit
            await settleMountedRendering()
            #expect(mounted.showsContent)
            #expect(model.markdown == OmissionSample.markdown)
            #expect(model.imageCalls.urls == [imageURL])
            #expect(model.taskUpdates == 0)

            let original = FlatMarkRenderProjector.project(
                markdown: OmissionSample.markdown,
                baseURL: URL(string: "https://example.com/")
            )
            let reference = FlatMarkRenderProjector.project(
                markdown: OmissionSample.referenceMarkdown,
                baseURL: URL(string: "https://example.com/")
            )
            #expect(visibleDocument(original, policy: .omit) == visibleDocument(reference, policy: .omit))
            #expect(reference.blocks.allSatisfy { FlatMarkUnsupportedContentPolicy.omit.presents($0) })

            model.policyKind = .literal
            await settleMountedRendering()
            #expect(mounted.showsContent)
            #expect(model.markdown == OmissionSample.markdown)
            #expect(model.taskUpdates == 0)
            #expect(model.imageCalls.urls.count == 1)
        }

        @Test
        func `omitted-label checkbox toggles only its own source byte after switching`() async throws {
            let markdown = OmissionSample.markdown
            let report = try await nativeHostReport(arguments: ["--task-interaction", "omit", markdown])
            let expected = markdown.replacingOccurrences(of: "- [ ] <u></u>", with: "- [x] <u></u>")
            #expect(report["completed"] == ["true"])
            #expect(report["initialMarkdown"] == [markdown])
            #expect(report["initialTaskUpdates"] == ["0"])
            #expect(report["updates"] == [expected])
            #expect(report["markdown"] == [expected])
            #expect(report["taskUpdates"] == ["1"])
            #expect(report["initialLoaded"] == ["https://example.com/image.png"])
            #expect(report["loaded"] == report["initialLoaded"])
        }
    }
    /// Independent minimal oracle: deliberately blank rows stay out of the readable recipe.
    private enum OmissionSample {
        static let markdown = """
        Before

        <div>hidden block</div>

        > > <u></u>

        - [x] Keep checked
        - [ ] <u></u>

          > <u></u>

          > Supported continuation

        ![Supported image](image.png)

        7. <u></u>
        8. keep

        | A | B |
        | --- | --- |
        | <u></u> | keep |

        [Details](details)

        After
        """

        static let referenceMarkdown = """
        Before

        - [x] Keep checked
        - [ ] <u></u>

          > Supported continuation

        ![Supported image](image.png)

        7.
        8. keep

        | A | B |
        | --- | --- |
        | | keep |

        [Details](details)

        After
        """
    }
#endif
