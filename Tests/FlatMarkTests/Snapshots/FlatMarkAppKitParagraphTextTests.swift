#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import FlatMark

@MainActor
struct FlatMarkAppKitParagraphTextTests {
    @Test func imagePlaceholderSharesNativeParagraphWithProse() async throws {
        let hosted = await mountTestView(
            FlatMarkView(markdown: "Before ![diagram](https://example.com/image.png) after."),
            size: CGSize(width: 180, height: 300)
        )
        defer { hosted.close() }
        let text = try #require(firstTextView(in: hosted.view))
        #expect(text.string == "Before \u{FFFC} diagram after.")
        let storage = try #require(text.textStorage)
        #expect(storage.attribute(.attachment, at: 7, effectiveRange: nil) is NSTextAttachment)
        #expect(text.isSelectable && !text.isEditable)
    }

    @Test func imageOnlyParagraphExposesOneLinkWithoutTextAreaChildren() async throws {
        let url = try #require(URL(string: "https://example.com/details"))
        var activated: [URL] = []
        let content = FlatMarkRenderInlineContent(components: [
            .image(.init(url: nil, altText: "diagram", link: url))
        ])
        for phase in [FlatMarkInlineView.ImagePhase.placeholder, .loading, .failed,
                      .loaded(NSImage(size: CGSize(width: 40, height: 20)))] {
            let hosted = await mountTestView(
                FlatMarkParagraphText(content: content, role: .body, context: .readOnly,
                                      imagePhases: [0: phase])
                    .environment(\.openURL, OpenURLAction { activated.append($0); return .handled }),
                size: CGSize(width: 180, height: 100)
            )
            let text = try #require(firstTextView(in: hosted.view))
            #expect(text.accessibilityRole() == .link)
            #expect(text.accessibilityLabel() == url.absoluteString + phase.accessibilitySuffix)
            #expect(text.accessibilityURL() == url)
            #expect(text.accessibilityValue() == nil)
            #expect(text.accessibilityChildren()?.isEmpty == true)
            #expect(text.accessibilityPerformPress())
            hosted.close()
        }
        #expect(activated == Array(repeating: url, count: 4))
    }

    @Test func repeatedImageDestinationsKeepCurrentSeparateAccessibilityTargets() async throws {
        let url = try #require(URL(string: "https://example.com/details"))
        var ordinary = AttributedString(" between ")
        ordinary.link = URL(string: "https://example.com/page")
        let content = FlatMarkRenderInlineContent(components: [
            .text(AttributedString("Before ")),
            .image(.init(url: nil, altText: "A very long first description", link: url)),
            .text(ordinary),
            .image(.init(url: nil, altText: "second", link: url)),
            .text(AttributedString(" after")),
        ])
        var activated: [URL] = []
        func root(_ phase: FlatMarkInlineView.ImagePhase) -> some View {
            FlatMarkParagraphText(content: content, role: .body, context: .readOnly,
                                  imagePhases: [1: phase, 3: .failed])
                .environment(\.openURL, OpenURLAction { activated.append($0); return .handled })
        }
        let hosted = await mountTestView(root(.loading), size: CGSize(width: 180, height: 500))
        defer { hosted.close() }
        let text = try #require(firstTextView(in: hosted.view))
        let children = (text.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityProtocol }
        #expect(children.filter { $0.accessibilityRole() == .link }.map { $0.accessibilityTitle() } == [
            url.absoluteString + ", loading", " between ", url.absoluteString + ", failed to load"
        ])
        let links = (text.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
            .filter { $0.accessibilityURL() == url }
        #expect(links.map { $0.accessibilityTitle() } == [url.absoluteString + ", loading", url.absoluteString + ", failed to load"])
        #expect(links.count == 2)
        guard links.count == 2 else { return }
        #expect(links[0].accessibilityFrame() != links[1].accessibilityFrame())
        #expect(links[0].accessibilityPerformPress())
        #expect(activated == [url])
        hosted.view.rootView = root(.placeholder)
        await settleMountedRendering()
        #expect(!links[0].accessibilityPerformPress())
        let updated = (text.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
            .filter { $0.accessibilityURL() == url }
        #expect(updated.first?.accessibilityTitle() == url.absoluteString + ", not loaded")
        #expect(text.accessibilityLabel() == nil)
        #expect(text.accessibilityValue() == "Before \u{FFFC} A very long first description between \u{FFFC} second after")
        hosted.view.rootView = root(.loaded(NSImage(size: CGSize(width: 300, height: 150))))
        await settleMountedRendering()
        let loaded = (text.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
            .filter { $0.accessibilityURL() == url }
        #expect(loaded.first?.accessibilityTitle() == url.absoluteString)
        let previousFrame = loaded.first?.accessibilityFrame()
        hosted.view.setFrameSize(CGSize(width: 320, height: 500))
        await settleMountedRendering()
        hosted.view.layoutSubtreeIfNeeded()
        let resized = (text.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
            .filter { $0.accessibilityURL() == url }
        #expect(resized.count == 2)
        #expect(resized.first?.accessibilityFrame() != previousFrame)
        #expect(resized.first?.accessibilityPerformPress() == true)
        #expect(activated == [url, url])
    }

    @Test func attachmentProbesDoNotMutateDisplayedBounds() async throws {
        let large = NSImage(size: CGSize(width: 600, height: 300))
        let small = NSImage(size: CGSize(width: 20, height: 10))
        let content = FlatMarkRenderInlineContent(components: [
            .image(.init(url: nil, altText: "large")),
            .text(AttributedString(" after\n")),
            .image(.init(url: nil, altText: "small")),
        ])
        let hosted = await mountTestView(AppKitParagraphProposalProbe {
            FlatMarkParagraphText(content: content, role: .body, context: .readOnly,
                                  imagePhases: [0: .loaded(large), 2: .loaded(small)])
        }, size: CGSize(width: 400, height: 600))
        defer { hosted.close() }
        let text = try #require(firstTextView(in: hosted.view))
        let storage = try #require(text.textStorage)
        let first = try #require(storage.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment)
        let last = try #require(storage.attribute(.attachment, at: storage.length - 1, effectiveRange: nil) as? NSTextAttachment)
        #expect(first.bounds.size == CGSize(width: 140, height: 70))
        #expect(last.bounds.size == CGSize(width: 20, height: 10))
        #expect(text.textContainer?.containerSize.width == 140)
    }

    @Test func combinedIntentsPreserveUnicodeAndConsecutiveNewlines() throws {
        var text = AttributedString("👩🏽‍💻 cafe\u{301}\n\n漢字 English עברית العربية\n")
        text.inlinePresentationIntent = [.code, .stronglyEmphasized, .emphasized, .strikethrough]
        let native = render(.init(text: text))
        #expect(native.string == String(text.characters))
        #expect(native.length == (native.string as NSString).length)
        for offset in 0..<native.length {
            let font = try #require(native.attribute(.font, at: offset, effectiveRange: nil) as? NSFont)
            #expect(font.fontDescriptor.symbolicTraits.contains(.monoSpace))
            #expect(font.fontDescriptor.symbolicTraits.contains(.bold))
            #expect(font.fontDescriptor.symbolicTraits.contains(.italic))
            #expect(native.attribute(.strikethroughStyle, at: offset, effectiveRange: nil) as? Int
                == NSUnderlineStyle.single.rawValue)
        }
    }

    @Test(arguments: [false, true])
    func literalAndOmittedUnicodeComposeWithoutSpaces(omitted: Bool) throws {
        let url = try #require(URL(string: "https://example.com/unicode"))
        var literal = AttributedString("👩🏽‍💻e\u{301}漢字עברית")
        literal.link = url
        let native = render(.init(components: [
            .text(AttributedString("before\n")),
            .unsupported(.init(literalText: literal)),
            .text(AttributedString("\n\nafter\n")),
        ]), policy: omitted ? .omit : .literal)
        let middle = omitted ? "" : String(literal.characters)
        #expect(Array(native.string.utf16) == Array("before\n\(middle)\n\nafter\n".utf16))
        if !omitted {
            var range = NSRange()
            #expect(native.attribute(.link, at: 7, effectiveRange: &range) as? URL == url)
            #expect(range == NSRange(location: 7, length: middle.utf16.count))
            for offset in range.location..<NSMaxRange(range) {
                #expect(native.attribute(.foregroundColor, at: offset, effectiveRange: nil) as? NSColor == .linkColor)
            }
        }
        #expect(native.attribute(.link, at: 0, effectiveRange: nil) == nil)
        #expect(native.attribute(.link, at: native.length - 1, effectiveRange: nil) == nil)
    }

    @Test func bodyUsesPreferredSemanticFont() throws {
        let native = render(.init(text: AttributedString("Body")))
        #expect(native.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
            == NSFont.preferredFont(forTextStyle: .body))
    }

    @Test(arguments: [TextAlignment.leading, .center, .trailing])
    func writingDirectionIsSeparateFromAlignment(alignment: TextAlignment) throws {
        let native = FlatMarkParagraphText.attributedText(
            for: .init(text: AttributedString("مرحبا café")), policy: .literal,
            layoutDirection: .rightToLeft, alignment: alignment
        )
        let paragraph = try #require(native.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        #expect(native.string == "مرحبا café")
        #expect(paragraph.baseWritingDirection == .rightToLeft)
        let expected: NSTextAlignment = alignment == .leading ? .right : alignment == .trailing ? .left : .center
        #expect(paragraph.alignment == expected)
    }

    @Test(arguments: [CGFloat(140), CGFloat(280)])
    func nativeParagraphsMeasureOfferedWidthWithoutOverlappingFollowingText(width: CGFloat) async throws {
        let environment = FlatMarkSnapshotEnvironment(
            captureSize: CGSize(width: 340, height: 800), columnWidth: width, contentInset: 20,
            pixelScale: 2, appearance: .light, localeIdentifier: "en_US",
            layoutDirection: .leftToRight, textSize: .body
        )
        _ = try await flatMarkSnapshotImage(
            of: FlatMarkView(markdown: "A long paragraph with enough words to wrap at both offered widths. Unicode café 漢字.\n\nFollowing paragraph."),
            environment: environment,
            prepareMountedView: { root in
                @MainActor func textViews(in view: NSView) -> [NSTextView] {
                    if let text = view as? NSTextView { return [text] }
                    return view.subviews.flatMap { textViews(in: $0) }
                }
                let views = textViews(in: root)
                #expect(views.count == 2)
                guard views.count == 2 else { return }
                let first = views[0]
                let second = views[1]
                #expect(first.isSelectable && !first.isEditable)
                #expect(first.textContainerInset == .zero)
                #expect(first.textContainer?.lineFragmentPadding == 0)
                #expect(abs(first.bounds.width - width) < 1)
                if let manager = first.layoutManager, let container = first.textContainer {
                    manager.ensureLayout(for: container)
                    #expect(abs(container.containerSize.width - width) < 1)
                    #expect(!container.widthTracksTextView && !container.heightTracksTextView)
                    #expect(!first.drawsBackground)
                    #expect(first.bounds.height >= ceil(manager.usedRect(for: container).height))
                } else {
                    Issue.record("Paragraph must expose its native text layout")
                }
                let firstFrame = first.convert(first.bounds, to: root)
                let secondFrame = second.convert(second.bounds, to: root)
                if root.isFlipped {
                    #expect(firstFrame.maxY <= secondFrame.minY)
                } else {
                    #expect(secondFrame.maxY <= firstFrame.minY)
                }
            }
        )
    }

    @Test func retainedParagraphReflowsNarrowWideNarrowWithoutOverlappingItsNeighbor() async throws {
        let document = FlatMarkDocument(markdown: "A long paragraph with enough words to wrap repeatedly at a narrow width. Unicode café 漢字 and more words to establish several native lines.\n\nFollowing paragraph.")
        let hosted = await mountTestView(FlatMarkView(document: document), size: CGSize(width: 140, height: 800))
        defer { hosted.close() }
        func textViews(in view: NSView) -> [NSTextView] {
            if let text = view as? NSTextView { return [text] }
            return view.subviews.flatMap { textViews(in: $0) }
        }
        let original = try #require(textViews(in: hosted.view).first)
        var heights: [CGFloat] = []
        for width in [CGFloat(140), 400, 140] {
            hosted.view.setFrameSize(CGSize(width: width, height: 800))
            await settleMountedRendering()
            hosted.view.layoutSubtreeIfNeeded()
            hosted.view.displayIfNeeded()
            let views = textViews(in: hosted.view)
            #expect(views.count == 2)
            let first = try #require(views.first)
            let second = try #require(views.last)
            #expect(first === original)
            #expect(abs(first.bounds.width - width) < 1)
            let manager = try #require(first.layoutManager)
            let container = try #require(first.textContainer)
            manager.ensureLayout(for: container)
            #expect(abs(container.containerSize.width - width) < 1)
            #expect(first.bounds.height >= ceil(manager.usedRect(for: container).maxY))
            let firstFrame = first.convert(first.bounds, to: hosted.view)
            let secondFrame = second.convert(second.bounds, to: hosted.view)
            if hosted.view.isFlipped {
                #expect(firstFrame.maxY <= secondFrame.minY)
            } else {
                #expect(secondFrame.maxY <= firstFrame.minY)
            }
            heights.append(first.bounds.height)
        }
        #expect(heights[0] > heights[1])
        #expect(heights[0] == heights[2])
    }

    @Test func retainedLiteralContentFollowsLayoutDirectionWithoutOverlappingItsNeighbor() async throws {
        let document = FlatMarkDocument(markdown: "Before <tag> after.\n\nFollowing paragraph.")
        func root(_ direction: LayoutDirection) -> some View {
            FlatMarkView(document: document, unsupportedContentPolicy: .literal)
                .environment(\.layoutDirection, direction)
        }
        let hosted = await mountTestView(root(.leftToRight), size: CGSize(width: 260, height: 800))
        defer { hosted.close() }
        func textViews(in view: NSView) -> [NSTextView] {
            if let text = view as? NSTextView { return [text] }
            return view.subviews.flatMap { textViews(in: $0) }
        }
        let original = try #require(textViews(in: hosted.view).first)
        var heights: [CGFloat] = []
        for direction in [LayoutDirection.leftToRight, .rightToLeft, .leftToRight] {
            hosted.view.rootView = root(direction)
            await settleMountedRendering()
            hosted.view.layoutSubtreeIfNeeded()
            let views = textViews(in: hosted.view)
            #expect(views.count == 2)
            let first = try #require(views.first)
            #expect(first === original)
            #expect(first.string == "Before <tag> after.")
            let storage = try #require(first.textStorage)
            let paragraph = try #require(storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
            #expect(paragraph.baseWritingDirection == (direction == .rightToLeft ? .rightToLeft : .leftToRight))
            #expect(paragraph.alignment == (direction == .rightToLeft ? .right : .left))
            let manager = try #require(first.layoutManager)
            let container = try #require(first.textContainer)
            manager.ensureLayout(for: container)
            let glyphs = manager.boundingRect(forGlyphRange: manager.glyphRange(for: container), in: container)
            #expect(first.bounds.height >= ceil(max(manager.usedRect(for: container).maxY,
                                                    glyphs.maxY, manager.extraLineFragmentRect.maxY)))
            let second = try #require(views.last)
            let firstFrame = first.convert(first.bounds, to: hosted.view)
            let secondFrame = second.convert(second.bounds, to: hosted.view)
            if hosted.view.isFlipped {
                #expect(firstFrame.maxY <= secondFrame.minY)
            } else {
                #expect(secondFrame.maxY <= firstFrame.minY)
            }
            heights.append(first.bounds.height)
        }
        #expect(heights[0] == heights[1])
        #expect(heights[0] == heights[2])
    }

    @Test func unchosenProposalsDoNotChangeCommittedNativeWidth() async throws {
        _ = try await flatMarkSnapshotImage(
            of: AppKitParagraphProposalProbe {
                FlatMarkParagraphText(content: .init(text: AttributedString("A paragraph with enough words to wrap repeatedly at a narrow committed width.")), role: .body, context: .readOnly)
            }, environment: .standard,
            prepareMountedView: { root in
                @MainActor func find(_ view: NSView) -> NSTextView? {
                    if let text = view as? NSTextView { return text }
                    return view.subviews.lazy.compactMap { find($0) }.first
                }
                guard let view = find(root), let container = view.textContainer,
                      let manager = view.layoutManager else {
                    Issue.record("Paragraph must expose native layout")
                    return
                }
                manager.ensureLayout(for: container)
                #expect(abs(view.bounds.width - 140) < 1)
                #expect(abs(container.containerSize.width - 140) < 1)
                #expect(view.bounds.height >= ceil(manager.usedRect(for: container).maxY))
            })
    }

    @Test func trailingBreaksReserveEmptyNativeLines() async throws {
        let environment = FlatMarkSnapshotEnvironment(
            captureSize: CGSize(width: 220, height: 200), columnWidth: 140, contentInset: 20,
            pixelScale: 2, appearance: .light, localeIdentifier: "en_US",
            layoutDirection: .leftToRight, textSize: .body
        )
        _ = try await flatMarkSnapshotImage(
            of: FlatMarkParagraphText(content: .init(text: AttributedString("one\n\n")), role: .body, context: .readOnly),
            environment: environment,
            prepareMountedView: { root in
                @MainActor func findText(in view: NSView) -> NSTextView? {
                    if let text = view as? NSTextView { return text }
                    return view.subviews.lazy.compactMap { findText(in: $0) }.first
                }
                guard let view = findText(in: root), let manager = view.layoutManager else {
                    Issue.record("Paragraph must expose its native text layout")
                    return
                }
                let lineHeight = manager.defaultLineHeight(for: NSFont.preferredFont(forTextStyle: .body))
                #expect(view.string == "one\n\n")
                #expect(view.bounds.height >= 3 * lineHeight)
            }
        )
    }

    /// A SwiftUI `Font` attribute never drives the native path: each heading level resolves its own
    /// semantic system font, and the role adds bold emphasis on top.
    @Test(arguments: [
        (1, NSFont.TextStyle.title1), (2, .title2), (3, .title3),
        (4, .headline), (5, .headline), (6, .headline),
    ] as [(Int, NSFont.TextStyle)])
    func headingRolesResolveSemanticBoldTypeWithoutFixedSizes(level: Int, style: NSFont.TextStyle) throws {
        let native = render(.init(text: AttributedString("Head")), role: .heading(level: level))
        let font = try #require(native.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let expected = NSFont.preferredFont(forTextStyle: style)
        #expect(font.pointSize == expected.pointSize)
        #expect(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
    }

    @Test func tableHeaderRoleBoldensBodyTypeWithoutChangingSize() throws {
        let native = render(.init(text: AttributedString("Owner")), role: .tableHeader)
        let font = try #require(native.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(font.pointSize == NSFont.preferredFont(forTextStyle: .body).pointSize)
        #expect(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
    }

    /// Emphasis, strong text, and inline code derive their typography from the resolved heading role.
    @Test func inlineTraitsDeriveFromTheHeadingRoleFont() throws {
        var code = AttributedString("code")
        code.inlinePresentationIntent = .code
        var emphasis = AttributedString("em")
        emphasis.inlinePresentationIntent = .emphasized
        let native = render(.init(components: [.text(code), .text(emphasis)]), role: .heading(level: 1))
        let titleSize = NSFont.preferredFont(forTextStyle: .title1).pointSize
        let codeFont = try #require(native.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(codeFont.pointSize == titleSize)
        #expect(codeFont.fontDescriptor.symbolicTraits.contains(.monoSpace))
        let emphasisFont = try #require(native.attribute(.font, at: 5, effectiveRange: nil) as? NSFont)
        #expect(emphasisFont.pointSize == titleSize)
        #expect(NSFontManager.shared.traits(of: emphasisFont).contains(.italicFontMask))
    }

    @Test func hostFontAndColorOverrideTheRoleDefaultWhileNeighborsKeepIt() throws {
        let hostFont = NSFont.boldSystemFont(ofSize: 21)
        var host = AttributedString(NSAttributedString(string: "host", attributes: [
            .font: hostFont, .foregroundColor: NSColor.systemTeal
        ]))
        let native = render(.init(components: [.text(host), .text(AttributedString(" x"))]), role: .heading(level: 1))
        #expect(native.attribute(.font, at: 0, effectiveRange: nil) as? NSFont == hostFont)
        #expect(native.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == .systemTeal)
        let titleSize = NSFont.preferredFont(forTextStyle: .title1).pointSize
        let neighborFont = try #require(native.attribute(.font, at: 5, effectiveRange: nil) as? NSFont)
        #expect(neighborFont.pointSize == titleSize)
        #expect(NSFontManager.shared.traits(of: neighborFont).contains(.boldFontMask))
    }

    @Test func inlineTextExportsTheFirstLineBaselineToSwiftUI() async throws {
        _ = try await flatMarkSnapshotImage(
            of: NativeBaselineProbe {
                Text("First").font(.body)
                FlatMarkInlineView(content: "First\nSecond", context: .readOnly)
            },
            environment: .standard
        )
    }

    private func render(
        _ content: FlatMarkRenderInlineContent,
        policy: FlatMarkUnsupportedContentPolicy = .literal,
        role: FlatMarkTextRole = .body
    ) -> NSAttributedString {
        FlatMarkParagraphText.attributedText(for: content, policy: policy, role: role,
                                            layoutDirection: .leftToRight, alignment: .leading)
    }
}

private struct AppKitParagraphProposalProbe: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        for probe in [ProposedViewSize.unspecified, ProposedViewSize(width: .infinity, height: nil),
                      ProposedViewSize(width: 320, height: nil)] {
            let size = subviews[0].sizeThatFits(probe)
            #expect(size.width.isFinite && size.height.isFinite)
        }
        let size = subviews[0].sizeThatFits(ProposedViewSize(width: 140, height: nil))
        #expect(abs(size.width - 140) < 1)
        return size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(width: 140, height: nil))
        _ = subviews[0].sizeThatFits(ProposedViewSize(width: 320, height: nil))
    }
}

/// Compare the bridge with SwiftUI's own baseline, not a fixture point-size constant.
private struct NativeBaselineProbe: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let proposal = ProposedViewSize(width: 100, height: nil)
        let reference = subviews[0].dimensions(in: proposal)
        let native = subviews[1].dimensions(in: proposal)
        #expect(abs(reference[.firstTextBaseline] - native[.firstTextBaseline]) < 1)
        return CGSize(width: 200, height: max(reference.height, native.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, view) in subviews.enumerated() {
            view.place(at: CGPoint(x: bounds.minX + CGFloat(index) * 100, y: bounds.minY),
                       proposal: ProposedViewSize(width: 100, height: nil))
        }
    }
}
#endif
