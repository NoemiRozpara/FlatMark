#if os(macOS)
    @testable import FlatMark
    import FlatMarkFixtures
    import Foundation
    import Testing

    @MainActor
    struct FlatMarkOmissionLiveUpdateTests {
        /// One mounted view, read at each of the three positions: what a reader gets is spelled out
        /// per policy, so a renderer that keeps displaying its first answer while the projection and
        /// the loader keep behaving correctly fails here. Which blocks survive and how an emptied row
        /// keeps its slot are stated at the model layer, in `FlatMarkOmittedContentTests`; this says
        /// what the screen showed. An image is not a text region, so its description is absent from
        /// every wording oracle, and the image-request checks are what say the photo stayed put.
        @Test
        func `public view restores omitted content without reloading its image`() async throws {
            let model = FlatMarkCustomFixtureModel(markdown: FlatMarkOmissionSample.markdown)
            let mounted = await mountTestView(
                FlatMarkCustomDocumentFixture(model: model), size: CGSize(width: 400, height: 1000)
            )
            defer { mounted.close() }
            try await waitForImage(in: model.imageCalls)
            let imageURL = try #require(URL(string: "https://example.com/image.png"))

            // Tags shown as the inert wording they were authored as, supported wording intact.
            #expect(try await visibleText(
                matching: FlatMarkOmissionSample.displayedLiterally,
                in: mounted
            ) == FlatMarkOmissionSample.displayedLiterally)
            #expect(mounted.showsContent)
            #expect(model.markdown == FlatMarkOmissionSample.markdown)
            #expect(model.imageCalls.urls == [imageURL])

            model.policyKind = .omit
            await settleMountedRendering()
            // The same view, the same supported wording in the same order, and no tag left on screen.
            #expect(try await visibleText(
                matching: FlatMarkOmissionSample.displayedOmitted,
                in: mounted
            ) == FlatMarkOmissionSample.displayedOmitted)
            #expect(mounted.showsContent)
            #expect(model.markdown == FlatMarkOmissionSample.markdown)
            #expect(model.imageCalls.urls == [imageURL])
            #expect(model.taskUpdates == 0)

            model.policyKind = .literal
            await settleMountedRendering()
            // Restoration is the same reading as the first one, on the same mounted identity.
            #expect(try await visibleText(
                matching: FlatMarkOmissionSample.displayedLiterally,
                in: mounted
            ) == FlatMarkOmissionSample.displayedLiterally)
            #expect(mounted.showsContent)
            #expect(model.markdown == FlatMarkOmissionSample.markdown)
            #expect(model.taskUpdates == 0)
            #expect(model.imageCalls.urls.count == 1)
        }

        @Test
        func `omitted-label checkbox toggles only its own source byte after switching`() async throws {
            let markdown = FlatMarkOmissionSample.markdown
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
#endif
