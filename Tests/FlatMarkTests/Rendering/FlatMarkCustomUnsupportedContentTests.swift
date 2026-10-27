@testable import FlatMark
import FlatMarkFixtures
import Markdown
import SwiftUI
import Testing

// MARK: - BlockPayloadRecorder

/// What the host renderer received, recorded per presentation rather than per lifecycle:
/// SwiftUI may present the same document more than once, and no count is a guarantee.
final class BlockPayloadRecorder {
    var payloads: [String] = []
}

// MARK: - FlatMarkCustomRenderingTests

/// Where the `.custom` policy places a host view, stated from the render tree.
///
/// These checks need neither AppKit nor a window, so they run in the iOS build as well. Every
/// expectation here is a projection fact: which unsupported node a host would be handed, in what
/// order, and at which position in the document. None of them is an observation of SwiftUI output:
/// which nodes the closure was really asked about, what a presentation drew, and whether a
/// replacement still takes space belong to the mounted ``FlatMarkCustomUnsupportedContentTests``
/// and to platform runtime observation.
struct FlatMarkCustomRenderingTests {
    /// A whole block keeps its own slot and is handed over as one host.
    @Test(arguments: [
        (
            "Before\n\n<div>raw</div>\n\nAfter",
            "Before\n\nAfter",
            [host("<div>raw</div>\n", path: [1])]
        ),
        (
            "> Before\n>\n> <div>raw</div>\n",
            "> Before\n",
            [host("<div>raw</div>\n", path: [0, 1])]
        ),
        (
            "- item\n\n  <div>raw</div>\n",
            "- item\n",
            [host("<div>raw</div>\n", path: [0, 0, 1])]
        ),
        (
            "- item\n\n  > <div>raw</div>\n",
            "- item\n",
            [host("<div>raw</div>\n", path: [0, 0, 1, 0])]
        ),
    ] as [(String, String, [FlatMarkHostAddress])])
    func `places one whole-block host at the position its source had`(
        markdown: String,
        reference: String,
        hosts: [FlatMarkHostAddress]
    ) throws {
        let document = FlatMarkRenderProjector.project(markdown: markdown)

        // Exactly one block hand-over, addressed inside the quote or list continuation that carried
        // it, carrying the extraction every policy is handed.
        #expect(customHosts(in: document) == hosts)
        // Nothing around it moved: with the block omitted instead of replaced, what is left is the
        // same document typed by hand without it. Whether a host view then fills that slot on
        // screen is a mounted question, not one this comparison answers.
        #expect(visibleDocument(document, policy: .omit)
            == visibleDocument(FlatMarkRenderProjector.project(markdown: reference), policy: .omit))
    }

    /// Inside a supported span, each parser node is its own host slot, addressed by component index.
    @Test(arguments: [
        (
            "before <u>x</u> after",
            [host("<u>", path: [0], component: 1), host("</u>", path: [0], component: 3)]
        ),
        (
            "# before <u>x</u> after",
            [host("<u>", path: [0], component: 1), host("</u>", path: [0], component: 3)]
        ),
        (
            "- before <u>x</u> after",
            [host("<u>", path: [0, 0], component: 1), host("</u>", path: [0, 0], component: 3)]
        ),
        (
            "7. first <u>x</u> end\n8. second <u>y</u> end",
            [
                host("<u>", path: [0, 0], component: 1), host("</u>", path: [0, 0], component: 3),
                host("<u>", path: [0, 1], component: 1), host("</u>", path: [0, 1], component: 3),
            ]
        ),
        (
            "- [ ] before <u>x</u> after",
            [host("<u>", path: [0, 0], component: 1), host("</u>", path: [0, 0], component: 3)]
        ),
        (
            "> > before <u>x</u> after",
            [host("<u>", path: [0, 0, 0], component: 1), host("</u>", path: [0, 0, 0], component: 3)]
        ),
        (
            "| before <u>x</u> |\n| - |\n| cell <u>y</u> |",
            [
                host("<u>", path: [0, 0, 0], component: 1), host("</u>", path: [0, 0, 0], component: 3),
                host("<u>", path: [0, 1, 0, 0], component: 1), host("</u>", path: [0, 1, 0, 0], component: 3),
            ]
        ),
    ] as [(String, [FlatMarkHostAddress])])
    func `places one host slot per unsupported inline node inside its span`(
        markdown: String,
        hosts: [FlatMarkHostAddress]
    ) throws {
        let document = FlatMarkRenderProjector.project(markdown: markdown)

        // One entry per parser node, in document order, each addressed to the span that carried it
        // and to the component index its tags occupied: paragraph, heading, ordinary and task list
        // rows, ordered rows, a nested quote, and both header and body table cells. A pair is two
        // entries, because the parser gave it two nodes.
        #expect(customHosts(in: document) == hosts)
    }

    @Test
    func `unsupported inline nodes keep separate slots inside supported text`() throws {
        let document = FlatMarkRenderProjector.project(markdown: "# before <u>x</u> after")
        guard case let .heading(level, content)? = document.blocks.first?.kind else {
            Issue.record("Expected one heading")
            return
        }

        // The heading arrives as a heading, at its level, with supported runs and unsupported nodes
        // as distinct components in source order. Which font a host view is drawn in is an
        // environment question about the mounted view, not a fact about this tree.
        #expect(level == 1)
        #expect(content.components.map(\.isUnsupported) == [false, true, false, true, false])
        #expect(content.plainText == "before <u>x</u> after")
        #expect(customHosts(in: document) == [
            host("<u>", path: [0], component: 1),
            host("</u>", path: [0], component: 3),
        ])
    }

    @Test
    func `a slot with nothing between its tags is still two slots`() throws {
        let document = FlatMarkRenderProjector.project(markdown: "a<u></u>b")
        guard case let .paragraph(content)? = document.blocks.first?.kind else {
            Issue.record("Expected one paragraph")
            return
        }

        // Both tags reach the host separately, and only the authored text is supported: under
        // omission that is what the reader gets, which is the other way to the same wording. What a
        // host that draws nothing leaves on screen is only observable mounted.
        #expect(customHosts(in: document) == [
            host("<u>", path: [0], component: 1),
            host("</u>", path: [0], component: 2),
        ])
        #expect(FlatMarkUnsupportedContentPolicy.omit.plainText(for: content) == "ab")
    }

    @Test(arguments: [
        "before \\<u> after", "text `<u>x</u>` here",
        "```\n<div>not HTML</div>\n```", "before <not a tag after",
    ] as [String])
    func `supported text, escapes, and code reach no host at all`(markdown: String) throws {
        let document = FlatMarkRenderProjector.project(markdown: markdown)

        // Nothing in these documents is unsupported, so the tree carries no node a host could be
        // handed, and a custom document reads exactly as the literal one.
        #expect(customHosts(in: document).isEmpty)
    }
}

// MARK: - FlatMarkCustomUnsupportedContentTests

/// Mounted `.custom` checks: these need a real body-evaluation context, because the host closure
/// runs while the view is built rather than while the tree is projected.
/// VoiceOver semantics still require platform runtime observation.
#if os(macOS)
    @MainActor
    struct FlatMarkCustomUnsupportedContentTests {
        @Test
        func `says nothing for a block whose host view is empty`() async throws {
            let recorder = BlockPayloadRecorder()
            let hosted = await mountTestView(FlatMarkView(
                markdown: "Before\n\n<div>raw</div>\n\nAfter",
                unsupportedContentPolicy: .custom { payload in
                    recorder.payloads.append(payload)
                    return AnyView(EmptyView())
                }
            ))
            defer { hosted.close() }

            // One node, asked about once per presentation, and the supported paragraphs around it
            // keep their own space. What the host was given is a set here, because the view may
            // present the same document more than once.
            #expect(Set(recorder.payloads) == ["<div>raw</div>\n"])
            #expect(hosted.showsContent)
        }

        /// The exact text one host closure is handed for every unsupported HTML shape in the corpus.
        ///
        /// Expectations are transcribed from the pinned parser rather than derived from the renderer:
        /// an HTML block keeps the trailing newline the parser reports on `rawHTML`, an inline node
        /// carries none, attribute text survives verbatim, and one tag pair is still two calls.
        @Test(arguments: [
            (
                markdown: "<script>go()</script>",
                dispatched: ["<script>go()</script>\n"]
            ),
            (
                markdown: "<iframe src=\"https://evil.example/e\"></iframe>",
                dispatched: ["<iframe src=\"https://evil.example/e\"></iframe>\n"]
            ),
            (
                markdown: "<img src=\"https://evil.example/x.png\" onclick=\"go()\">",
                dispatched: ["<img src=\"https://evil.example/x.png\" onclick=\"go()\">\n"]
            ),
            (
                markdown: "before <a href=\"javascript:go()\" onclick=\"go()\">tap</a> after",
                dispatched: ["<a href=\"javascript:go()\" onclick=\"go()\">", "</a>"]
            ),
            (
                markdown: "before <img src=\"https://evil.example/x.png\" onerror=\"go()\"> after",
                dispatched: ["<img src=\"https://evil.example/x.png\" onerror=\"go()\">"]
            ),
            (
                markdown: "before <span>safe</span> after",
                dispatched: ["<span>", "</span>"]
            ),
            (
                markdown: "before <u>unclosed",
                dispatched: ["<u>"]
            ),
        ] as [(markdown: String, dispatched: [String])])
        func `hands the host the parser's own text for every unsupported HTML shape`(
            markdown: String,
            dispatched: [String]
        ) async throws {
            let recorder = BlockPayloadRecorder()
            let hosted = await mountTestView(FlatMarkView(
                markdown: markdown,
                unsupportedContentPolicy: .custom { payload in
                    recorder.payloads.append(payload)
                    return AnyView(Text("Replacement"))
                }
            ))
            defer { hosted.close() }

            // A set, because SwiftUI may evaluate one position more than once: which node reached the
            // host is decided here, while multiplicity and order stay with the projection checks.
            #expect(await dispatchedPayloads(matching: Set(dispatched), in: recorder) == Set(dispatched))
            #expect(hosted.showsContent)
        }

        /// Mounted checks that supported syntax never reaches a host at all.
        ///
        /// Escape, inline code, a fenced block, and a malformed tag: the parser gives the renderer
        /// nothing to hand over in any of them, so the closure is never asked about them. The last case
        /// is the positive control on the same recorder and hosting path: the same syntax does dispatch
        /// once it is really a tag, so a host that never rendered cannot pass the other four.
        @Test(arguments: [
            (markdown: "before \\<u> after", wording: "before <u> after", dispatched: []),
            (markdown: "text `<u>x</u>` here", wording: "text <u>x</u> here", dispatched: []),
            (markdown: "before <not a tag after", wording: "before <not a tag after", dispatched: []),
            (markdown: "```\n<div>code</div>\n```", wording: "<div>code</div>", dispatched: []),
            (markdown: "before <u>x</u> after", wording: "before", dispatched: ["<u>", "</u>"]),
        ] as [(markdown: String, wording: String, dispatched: [String])])
        func `mounts escaped, coded, and malformed HTML without a host and dispatches the real tag`(
            markdown: String,
            wording: String,
            dispatched: [String]
        ) async throws {
            let recorder = BlockPayloadRecorder()
            let hosted = await mountTestView(FlatMarkView(
                markdown: markdown,
                unsupportedContentPolicy: .custom { payload in
                    recorder.payloads.append(payload)
                    return AnyView(Text("Replacement"))
                }
            ))
            defer { hosted.close() }

            // Wait for visible wording before checking dispatch: `showsContent` alone would say only
            // that some view exists, and an empty payload set could otherwise pass before rendering.
            #expect(try await visibleText(showing: wording, in: hosted).contains(wording))
            #expect(await dispatchedPayloads(matching: Set(dispatched), in: recorder) == Set(dispatched))
        }

        @Test
        func `replaces separate inline tags in source order as well as blocks`() async throws {
            let markdown = "before <u>important</u> after\n\n<div>raw</div>\n\nAfter"
            let recorder = BlockPayloadRecorder()
            let hosted = await mountTestView(FlatMarkView(
                markdown: markdown,
                unsupportedContentPolicy: .custom { payload in
                    recorder.payloads.append(payload)
                    return AnyView(Text(payload == "<u>" ? "[" : payload == "</u>" ? "]" : "Replacement"))
                }
            ))
            defer { hosted.close() }

            // Separate parser nodes reach the closure separately, including both tags of a pair.
            // Which view is asked first is SwiftUI's business, so the set decides which nodes were
            // asked about and the tree below says where each one sits.
            #expect(Set(recorder.payloads) == ["<u>", "</u>", "<div>raw</div>\n"])
            #expect(hosted.showsContent)
            // Where the tree says each of those nodes sits: both tags inside their own paragraph,
            // the HTML block in the next block slot. The set above says which nodes were asked
            // about; only the tree gives them an order and a position.
            #expect(customHosts(in: FlatMarkRenderProjector.project(markdown: markdown)) == [
                host("<u>", path: [0], component: 1),
                host("</u>", path: [0], component: 3),
                host("<div>raw</div>\n", path: [1]),
            ])
        }

        @Test
        func `unknown inline nodes dispatch the shared source descendant and empty extraction`() async throws {
            let source = "hé see ``Foo`` here"
            let parsed = Document(parsing: source, options: [.parseSymbolLinks])
            let cases: [(FlatMarkRenderDocument, String)] = [
                (FlatMarkRenderProjector.project(parsed, source: source), "``Foo``"),
                (FlatMarkRenderProjector.project(Document(Paragraph(
                    InlineAttributes(attributes: "{}", Markdown.Text("readable"))
                )), source: ""), "readable"),
                (FlatMarkRenderProjector.project(Document(Paragraph(
                    SymbolLink(destination: "Symbol")
                )), source: ""), ""),
            ]
            for (document, expected) in cases {
                let recorder = try await recorder(for: document)
                #expect(Set(recorder.payloads) == [expected])
            }
        }

        @Test
        func `inline host button does not activate its enclosing Markdown link`() async throws {
            let report = try await navigationReport(
                markdown: "line\n\n[<u>x](https://example.com/md)\n\nline",
                decision: "default", unsupportedPolicy: "custom"
            )
            #expect(report["customActivations"] == ["1"])
            #expect(report["activated"] == [])
            #expect(report["opened"] == [])
            #expect(Set(report["customPayloads"] ?? []) == ["<u>"])
        }

        @Test
        func `supported linked neighbor still activates independently of the host button`() async throws {
            let report = try await navigationReport(
                markdown: "line\n\n[linked <u>x](https://example.com/md)\n\nline",
                decision: "default", unsupportedPolicy: "custom"
            )
            #expect(report["customActivations"] == ["0"])
            #expect(report["activated"] == ["https://example.com/md"])
            #expect(report["opened"] == ["https://example.com/md"])
        }

        @Test
        func `hands blocks the extraction every policy shows, never a diagnostic label`() async throws {
            let source = "@Foo(bar) {\nvisible source\n}"
            let addressed = try await recorder(for: FlatMarkRenderProjector.project(
                Document(parsing: source, options: [.parseBlockDirectives]), source: source
            ))
            // A range that addresses no usable snapshot leaves the shared descendant fallback.
            let unaddressable = try await recorder(for: FlatMarkRenderProjector.project(
                Document(parsing: source, options: [.parseBlockDirectives]), source: ""
            ))
            // A node with neither range nor readable descendants is still a call, with empty text.
            let empty = try await recorder(for: FlatMarkRenderProjector.project(
                Document(CustomBlock([])), source: "irrelevant"
            ))
            // Block leaves carry their content in `code` and `rawHTML` rather than in text
            // children, so each host has to be handed the same exact text the literal policy prints.
            let blockLeafChildren: [any BlockMarkup] = [
                CustomBlock([CodeBlock(language: "swift", "café 🧪\n你好\n")]),
                CustomBlock([HTMLBlock("<div>raw</div>\n")]),
            ]
            let leaves = try await recorder(for: FlatMarkRenderProjector.project(
                Document(blockLeafChildren), source: "irrelevant"
            ))

            #expect(Set(addressed.payloads) == [source])
            #expect(Set(unaddressable.payloads) == ["visible source"])
            #expect(Set(empty.payloads) == [""])
            #expect(Set(leaves.payloads) == ["café 🧪\n你好\n", "<div>raw</div>\n"])
        }

        @Test
        func `unsupported block becomes the host control one click activates once`() async throws {
            // The native host runs its own application event loop, so the click reaches the view the
            // way a real click would. The middle block is the replacement, so the host's midpoint
            // click lands on it.
            let report = try await navigationReport(
                markdown: "line\n\n<div>raw</div>\n\nline",
                decision: "default",
                unsupportedPolicy: "custom"
            )

            #expect(report["customActivations"] == ["1"])
            #expect(Set(report["customPayloads"] ?? []) == Set(["<div>raw</div>\n"]))
        }

        @Test
        func `switching policies on unchanged Markdown refreshes inline and block output`() async throws {
            let model = FlatMarkCustomFixtureModel()
            let hosted = await mountTestView(
                FlatMarkCustomDocumentFixture(model: model)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            )
            defer { hosted.close() }
            try await waitForImage(in: model.imageCalls)

            let dispatched: Set<String> = ["<div>hidden block</div>\n", "<div>quoted block</div>\n", "<u>", "</u>"]
            // Starting with Literal, this sequence exercises all six directed edges and returns
            // to Literal without changing the source.
            for policy in [FlatMarkCustomPolicyKind.custom, .omit, .literal, .omit, .custom, .literal] {
                model.policyKind = policy
                await settleMountedRendering()
                #expect(model.markdown == FlatMarkCustomFixtureModel.markdown)
                #expect(model.imageCalls.urls.count == 1)
                #expect(model.taskUpdates == 0)
                switch policy {
                case .literal:
                    #expect(model.payloads.isEmpty)
                    #expect(try hosted.visibleText.contains("important"))
                    #expect(try hosted.visibleText.contains("hidden block"))
                case .omit:
                    #expect(model.payloads.isEmpty)
                    #expect(try !hosted.visibleText.contains("<u>"))
                    #expect(try !hosted.visibleText.contains("hidden block"))
                    #expect(try hosted.visibleText.contains("important"))
                    #expect(try hosted.visibleText.contains("Before"))
                case .custom:
                    #expect(Set(model.payloads) == dispatched)
                    #expect(Set(model.presentedLabels) == [model.replacementLabel])
                    #expect(try hosted.visibleText.contains(model.replacementLabel))
                }
            }

            // Update the host label while Custom remains selected; assert presented native text,
            // not just the closure's recorded argument.
            model.policyKind = .custom
            await settleMountedRendering()
            model.payloads = []
            model.presentedLabels = []
            model.replacementLabel = "Other replacement"
            await settleMountedRendering()
            #expect(Set(model.presentedLabels) == ["Other replacement"])
            #expect(Set(model.payloads) == dispatched)
            #expect(try hosted.visibleText.contains("Other replacement"))
            #expect(try !hosted.visibleText.contains("Replacement"))
            #expect(model.markdown == FlatMarkCustomFixtureModel.markdown)
            #expect(model.imageCalls.urls.count == 1)
        }

        @Test
        func `task checkbox and inline host button activate independently in the same row`() async throws {
            let markdown = "- [x] untouched task\n- [ ] <u>supported text"
            let checkedMarkdown = "- [x] untouched task\n- [x] <u>supported text"
            let report = try await nativeHostReport(arguments: ["--task-interaction", "custom", markdown])
            #expect(report["completed"] == ["true"])
            #expect(report["initialMarkdown"] == [markdown])
            #expect(report["initialCheckboxStates"] == ["0", "1"])
            #expect(report["checkboxEnabled"] == ["true"])
            #expect(report["initialCustomActivations"] == ["0"])
            #expect(report["initialTaskUpdates"] == ["0"])
            #expect(Set(report["customPayloads"] ?? []) == ["<u>"])
            #expect(report["customActivations"] == ["1", "1", "2"])
            #expect(report["taskUpdates"] == ["0", "1", "1"])
            #expect(report["markdown"] == [markdown, checkedMarkdown, checkedMarkdown])
            #expect(report["updates"] == [checkedMarkdown])
            #expect(report["linkActivations"] == ["0", "0", "0"])
            #expect(report["finalCheckboxStates"] == ["1", "1"])
        }

        @Test(arguments: [false, true])
        func `policy changes do not reload an image inside a task row`(allowsTaskEditing: Bool) async throws {
            let model = FlatMarkCustomFixtureModel()
            let markdown = "- [ ] before <u>x</u> ![Supported image](image.png)"
            model.markdown = markdown
            model.allowsTaskEditing = allowsTaskEditing
            model.showsButtons = true
            let hosted = await mountTestView(
                FlatMarkCustomDocumentFixture(model: model)
                    .fixedSize(horizontal: false, vertical: true)
            )
            defer { hosted.close() }
            try await waitForImage(in: model.imageCalls)
            let imageURL = try #require(URL(string: "https://example.com/image.png"))
            #expect(model.imageCalls.urls == [imageURL])
            #expect(model.markdown == markdown)

            // Starting in literal, this path covers all six directed policy transitions.
            let policies: [FlatMarkCustomPolicyKind] = [.custom, .omit, .literal, .omit, .custom, .literal]
            for policy in policies {
                model.policyKind = policy
                await settleMountedRendering()
                #expect(model.imageCalls.urls.count == 1, "Image restarted after switching to \(policy.title)")
                #expect(model.markdown == markdown)
                #expect(model.taskUpdates == 0)
                #expect(hosted.showsContent)
                if policy == .custom {
                    #expect(Set(model.payloads) == ["<u>", "</u>"])
                } else {
                    #expect(model.payloads.isEmpty)
                }
            }
        }

        @Test
        func `policy changes preserve structural IDs and task editing addresses`() throws {
            let markdown = "Before\n\n<div>raw</div>\n\n- [ ] task <u>x</u>\n\n  <div>continuation</div>\n\nAfter"
            let document = FlatMarkRenderProjector.project(markdown: markdown)
            let original = document
            #expect(document.blocks.map(\.id) == (0 ..< 4).map { FlatMarkRenderNodeID(path: [$0]) })
            guard case let .list(entries) = document.blocks[2].kind,
                  case let .row(row) = try #require(entries.first),
                  case let .task(_, optionalAddress) = row.marker
            else {
                Issue.record("Expected an addressable task row")
                return
            }

            let address = try #require(optionalAddress)
            #expect(entries.map(\.id) == [
                FlatMarkRenderNodeID(path: [2, 0]), FlatMarkRenderNodeID(path: [2, 0, 1]),
            ])
            var toggled: [String] = []
            let policies: [FlatMarkUnsupportedContentPolicy] = [
                .literal, .custom { _ in AnyView(Text("Replacement")) }, .omit,
                .custom { _ in AnyView(Text("Other replacement")) }, .literal,
            ]

            for policy in policies {
                let survivors = document.blocks.filter { policy.presents($0) }
                let expectedIDs =
                    if case .omit = policy {
                        [document.blocks[0].id, document.blocks[2].id, document.blocks[3].id]
                    } else {
                        document.blocks.map(\.id)
                    }
                #expect(survivors.map(\.id) == expectedIDs)
                let visibleEntries = entries.filter { entry in
                    if case let .childBlock(child) = entry {
                        return policy.presents(child.block)
                    }
                    return true
                }
                #expect(visibleEntries.first?.id == FlatMarkRenderNodeID(path: [2, 0]))
                if case .omit = policy {
                    #expect(visibleEntries.count == 1)
                } else {
                    #expect(visibleEntries.map(\.id) == entries.map(\.id))
                }
                let view = FlatMarkListRowView(row: row, context: FlatMarkRenderContext(
                    unsupportedContentPolicy: policy,
                    taskToggleAction: { receivedAddress in
                        #expect(receivedAddress == address)
                        if let updated = FlatMarkTaskMarkerToggle.toggledMarkdown(
                            in: markdown, sourceRange: receivedAddress
                        ) {
                            toggled.append(updated)
                        }
                    }
                ))
                let toggle = try #require(view.taskToggleAction)
                toggle()
                #expect(document == original)
            }

            #expect(toggled == Array(
                repeating: markdown.replacingOccurrences(of: "[ ]", with: "[x]"),
                count: policies.count
            ))
        }

        /// The environment an ancestor's enabled state leaves inside a host view, read at both
        /// positions a `.custom` replacement can occupy in one unchanged document.
        ///
        /// Only appearance and a change of the inherited `isEnabled` are recorded, because observing
        /// during ``body`` would report a value the renderer may have rebuilt without any ancestor
        /// changing. Which control a disabled tap really suppresses, and what assistive technology
        /// says about it, is platform runtime observation rather than a fact of this environment.
        @Test
        func `hands an inline and a whole-block host view the ancestor's own enabled state`() async throws {
            let inlineProbe = EnabledStateProbe()
            let blockProbe = EnabledStateProbe()
            let ancestor = EnabledAncestorState()
            let hosted = await mountTestView(EnabledProbeContainer(
                ancestor: ancestor,
                inlineProbe: inlineProbe,
                blockProbe: blockProbe
            ))
            defer { hosted.close() }

            // One unchanged document, read while its ancestor changes under it: both positions get
            // the same sequence, which is the whole of what an inherited environment can prove.
            #expect(await observations(of: inlineProbe, expecting: 1) == [true])
            #expect(await observations(of: blockProbe, expecting: 1) == [true])

            ancestor.disablesInteraction = true
            #expect(await observations(of: inlineProbe, expecting: 2) == [true, false])
            #expect(await observations(of: blockProbe, expecting: 2) == [true, false])

            ancestor.disablesInteraction = false
            #expect(await observations(of: inlineProbe, expecting: 3) == [true, false, true])
            #expect(await observations(of: blockProbe, expecting: 3) == [true, false, true])
            #expect(hosted.showsContent)
        }

        /// Waits within a bound for the host closure to have been asked about every node the document
        /// carries. A view whose body never evaluated fails here with missing payloads instead of
        /// passing on a quiet timeout.
        private func dispatchedPayloads(
            matching expected: Set<String>,
            in recorder: BlockPayloadRecorder
        ) async -> Set<String> {
            for _ in 0 ..< 50 {
                if Set(recorder.payloads).isSuperset(of: expected) {
                    await settleMountedRendering()
                    break
                }

                try? await Task.sleep(for: .milliseconds(10))
            }

            return Set(recorder.payloads)
        }

        /// What one probe recorded once it reached `expecting` values, so a value that never arrives
        /// is reported as the missing observation it is.
        private func observations(of probe: EnabledStateProbe, expecting count: Int) async -> [Bool] {
            for _ in 0 ..< 50 {
                if probe.observations.count >= count {
                    break
                }

                try? await Task.sleep(for: .milliseconds(10))
            }

            return probe.observations
        }

        /// Renders one projected document through the native view with a `.custom` policy and keeps
        /// what the renderer was handed, for the exact-value cases no production parse produces.
        @MainActor
        private func recorder(for document: FlatMarkRenderDocument) async throws -> BlockPayloadRecorder {
            let recorder = BlockPayloadRecorder()
            let hosted = await mountTestView(FlatMarkDocumentView(
                document: document,
                context: FlatMarkRenderContext(unsupportedContentPolicy: .custom { payload in
                    recorder.payloads.append(payload)
                    return AnyView(Text("Replacement"))
                })
            ))
            defer { hosted.close() }
            #expect(
                recorder.payloads.isEmpty == false,
                "The renderer should have been asked about the unsupported node."
            )

            return recorder
        }
    }

    // MARK: - EnabledAncestorState

    /// The one thing an ancestor of a mounted document can change while its content stays the same.
    @MainActor
    @Observable
    final class EnabledAncestorState {
        var disablesInteraction = false
    }

    // MARK: - EnabledStateProbe

    /// What the host views it owns saw as their inherited enabled state, in the order it changed.
    ///
    /// A repeated value is not recorded again: appearance and body re-evaluation both report the same
    /// state, and the sequence under test is the change an ancestor made, not the number of observations.
    @MainActor
    final class EnabledStateProbe {
        private(set) var observations: [Bool] = []

        func record(_ isEnabled: Bool) {
            if observations.last != isEnabled {
                observations.append(isEnabled)
            }
        }
    }

    // MARK: - EnabledProbeHostView

    /// A host-owned view that records the enabled environment it inherits on appearance and on change,
    /// never while ``body`` is built.
    private struct EnabledProbeHostView: View {
        let probe: EnabledStateProbe

        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            Text("Replacement")
                .onAppear { probe.record(isEnabled) }
                .onChange(of: isEnabled) { _, value in
                    probe.record(value)
                }
        }
    }

    // MARK: - EnabledProbeContainer

    /// One unchanged document that carries an unsupported node at both positions a host view can
    /// occupy: one inline tag beside supported text and one whole HTML block of its own.
    private struct EnabledProbeContainer: View {
        static let markdown = "before <img src=\"https://evil.example/x.png\"> after\n\n<div>raw</div>\n\nAfter"
        static let blockPayload = "<div>raw</div>\n"

        let ancestor: EnabledAncestorState
        let inlineProbe: EnabledStateProbe
        let blockProbe: EnabledStateProbe

        var body: some View {
            FlatMarkView(
                markdown: Self.markdown,
                unsupportedContentPolicy: .custom { payload in
                    AnyView(EnabledProbeHostView(probe: payload == Self.blockPayload ? blockProbe : inlineProbe))
                }
            )
            .disabled(ancestor.disablesInteraction)
        }
    }
#endif
