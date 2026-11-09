#if os(iOS)
import SwiftUI
import Testing
import UIKit
@testable import FlatMark
#if SWIFT_PACKAGE
import FlatMarkFixtures
#endif

@MainActor
struct FlatMarkParagraphTextTests {
    @Test func combinedIntentsPreserveUnicodeAndConsecutiveNewlines() throws {
        var text = AttributedString("👩🏽‍💻 cafe\u{301}\n\n漢字 English עברית العربية\n")
        text.inlinePresentationIntent = [.code, .stronglyEmphasized, .emphasized, .strikethrough]
        let native = render(.init(text: text))
        #expect(native.string == String(text.characters))
        #expect(native.length == (native.string as NSString).length)
        for offset in 0..<native.length {
            let font = try #require(native.attribute(.font, at: offset, effectiveRange: nil) as? UIFont)
            #expect(font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
            #expect(font.fontDescriptor.symbolicTraits.contains(.traitBold))
            #expect(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
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
                #expect(native.attribute(.foregroundColor, at: offset, effectiveRange: nil) as? UIColor == .link)
            }
        }
        #expect(native.attribute(.link, at: 0, effectiveRange: nil) == nil)
        #expect(native.attribute(.link, at: native.length - 1, effectiveRange: nil) == nil)
    }

    @Test func bodyUsesPreferredSemanticFont() throws {
        let native = render(.init(text: AttributedString("Body")))
        #expect(native.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
            == UIFont.preferredFont(forTextStyle: .body,
                compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)))
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
                @MainActor func textViews(in view: UIView) -> [UITextView] {
                    if let text = view as? UITextView { return [text] }
                    return view.subviews.flatMap { textViews(in: $0) }
                }
                let views = textViews(in: root)
                #expect(views.count == 2)
                guard views.count == 2 else { return }
                let first = views[0]
                let second = views[1]
                #expect(first.isSelectable && !first.isEditable && !first.isScrollEnabled)
                #expect(first.textContainerInset == .zero)
                #expect(first.textContainer.lineFragmentPadding == 0)
                #expect(abs(first.bounds.width - width) < 1)
                let required = first.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
                #expect(first.bounds.height >= floor(required.height))
                #expect(first.convert(first.bounds, to: root).maxY <= second.convert(second.bounds, to: root).minY)
            }
        )
    }

    @Test func recipeNormalTextFollowsMountedAmbientDynamicType() async throws {
        let model = FlatMarkCustomFixtureModel()
        model.markdown = "System size probe."
        func root(_ size: DynamicTypeSize) -> some View {
            FlatMarkCustomFixture(model: model).environment(\.dynamicTypeSize, size)
        }
        let host = UIHostingController(rootView: root(.large))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 2400))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        for (size, category) in [(DynamicTypeSize.large, UIContentSizeCategory.large),
                                 (.accessibility3, .accessibilityExtraLarge), (.large, .large)] {
            host.rootView = root(size)
            await settle(host.view)
            let text = try #require(textViews(in: host.view).first { $0.text == "System size probe." })
            let font = try #require(text.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
            #expect(font.pointSize == UIFont.preferredFont(forTextStyle: .body,
                compatibleWith: UITraitCollection(preferredContentSizeCategory: category)).pointSize)
        }
    }

    @Test func retainedPublicNavigationAdapterUsesCurrentOptionalCallbackAndOpener() async throws {
        let destination = try #require(URL(string: "https://example.com/details"))
        let document = FlatMarkDocument(markdown: "[Details](https://example.com/details) neighbor")
        var activated: [String] = []
        var opened: [String] = []
        func root(_ decision: FlatMarkLinkActivationResult?, generation: String) -> some View {
            let callback: ((URL) -> FlatMarkLinkActivationResult)? = decision.map { result in
                { url in
                    activated.append(generation + ":" + url.absoluteString)
                    return result
                }
            }
            return FlatMarkView(document: document, linkActivationAction: callback)
                .environment(\.openURL, OpenURLAction { url in
                    opened.append(generation + ":" + url.absoluteString)
                    return .discarded
                })
                .frame(width: 300)
        }
        let host = UIHostingController(rootView: root(nil, generation: "initial"))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 340, height: 600))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        await settle(host.view)
        let original = try #require(textViews(in: host.view).first)
        let coordinator = try #require(original.delegate as? FlatMarkParagraphText.Coordinator)
        #expect(activated.isEmpty && opened.isEmpty)
        coordinator.openURL(destination)
        #expect(opened == ["initial:" + destination.absoluteString])
        for (decision, generation) in [(FlatMarkLinkActivationResult?.some(.handled), "handled"),
                                      (.some(.rejected), "rejected"), (.some(.useDefaultOpening), "default"),
                                      (nil, "removed")] {
            let beforeActivation = activated
            let beforeOpening = opened
            host.rootView = root(decision, generation: generation)
            await settle(host.view)
            let current = try #require(textViews(in: host.view).first)
            #expect(current === original)
            #expect(original.delegate === coordinator)
            #expect(activated == beforeActivation)
            #expect(opened == beforeOpening)
            // This isolates bridge-to-public-adapter wiring, not native gesture dispatch.
            coordinator.openURL(destination)
            #expect(activated == beforeActivation + (decision == nil ? [] : [generation + ":" + destination.absoluteString]))
            let delegates = generation == "default" || generation == "removed"
            #expect(opened == beforeOpening + (delegates ? [generation + ":" + destination.absoluteString] : []))
        }
    }

    @Test func retainedParagraphUpdatesDynamicTypeAndWidthWithoutOverlap() async throws {
        let document = FlatMarkDocument(markdown: "A long paragraph with enough words to wrap repeatedly at narrow widths. Unicode café 漢字 and more words for several lines.\n\nFollowing paragraph.")
        func root(_ size: DynamicTypeSize, width: CGFloat) -> some View {
            FlatMarkView(document: document)
                .environment(\.dynamicTypeSize, size)
                .frame(width: width)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        let host = UIHostingController(rootView: root(.large, width: 140))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 1400))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        await settle(host.view)
        let original = try #require(textViews(in: host.view).first)
        var heights: [CGFloat] = []
        var sizes: [CGFloat] = []
        for (size, width) in [(DynamicTypeSize.large, CGFloat(140)), (.large, 400),
                              (.large, 140), (.accessibility3, 140), (.large, 140)] {
            host.rootView = root(size, width: width)
            await settle(host.view)
            let views = textViews(in: host.view)
            #expect(views.count == 2)
            let first = try #require(views.first)
            #expect(first === original)
            #expect(abs(first.bounds.width - width) < 1)
            try expectCompleteLayout(views, in: host.view)
            let font = try #require(first.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
            let category: UIContentSizeCategory = size == .large ? .large : .accessibilityExtraLarge
            #expect(font.pointSize == UIFont.preferredFont(forTextStyle: .body,
                compatibleWith: UITraitCollection(preferredContentSizeCategory: category)).pointSize)
            heights.append(first.bounds.height)
            sizes.append(font.pointSize)
        }
        #expect(heights[0] > heights[1])
        #expect(heights[0] == heights[2])
        #expect(heights[3] > heights[2])
        #expect(heights[4] == heights[0])
        #expect(sizes[3] > sizes[0])
    }

    @Test func retainedLiteralContentUpdatesDirectionTypeSizeAndHeight() async throws {
        let document = FlatMarkDocument(markdown: "Before <tag> after.\n\nFollowing paragraph.")
        func root(_ direction: LayoutDirection, size: DynamicTypeSize = .large) -> some View {
            FlatMarkView(document: document, unsupportedContentPolicy: .literal)
                .environment(\.layoutDirection, direction)
                .environment(\.dynamicTypeSize, size)
                .multilineTextAlignment(.trailing)
                .frame(width: 260)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        let host = UIHostingController(rootView: root(.leftToRight))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 340, height: 900))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        await settle(host.view)
        let original = try #require(textViews(in: host.view).first)
        var heights: [CGFloat] = []
        for (direction, size) in [(LayoutDirection.leftToRight, DynamicTypeSize.large),
                                  (.rightToLeft, DynamicTypeSize.accessibility3),
                                  (.leftToRight, .large)] {
            host.rootView = root(direction, size: size)
            await settle(host.view)
            let views = textViews(in: host.view)
            #expect(views.count == 2)
            let first = try #require(views.first)
            #expect(first === original)
            #expect(first.text == "Before <tag> after.")
            let storage = try #require(first.attributedText)
            let paragraph = try #require(storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
            #expect(paragraph.baseWritingDirection == (direction == .rightToLeft ? .rightToLeft : .leftToRight))
            #expect(paragraph.alignment == (direction == .rightToLeft ? .left : .right))
            try expectCompleteLayout(views, in: host.view)
            heights.append(first.bounds.height)
        }
        #expect(heights[1] > heights[0])
        #expect(heights[2] == heights[0])
    }

    @Test(arguments: [TextAlignment.leading, .center, .trailing])
    func writingDirectionIsSeparateFromAlignment(alignment: TextAlignment) throws {
        let native = FlatMarkParagraphText.attributedText(
            for: .init(text: AttributedString("café مرحبا 123")), policy: .literal,
            dynamicTypeSize: .large, layoutDirection: .rightToLeft, alignment: alignment)
        let paragraph = try #require(native.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        #expect(native.string == "café مرحبا 123")
        #expect(paragraph.baseWritingDirection == .rightToLeft)
        let expected: NSTextAlignment = alignment == .leading ? .right : alignment == .trailing ? .left : .center
        #expect(paragraph.alignment == expected)
    }

    @Test func proposalProbesAndTrailingBreaksKeepCommittedLayoutSeparateFromNeighbor() async throws {
        let host = UIHostingController(rootView: VStack(spacing: 0) {
            ParagraphProposalProbe {
                FlatMarkParagraphText(content: .init(text: AttributedString("A paragraph with enough words to wrap at the committed width.\n\n")), role: .body, context: .readOnly, imagePhases: [:])
            }
            FlatMarkParagraphText(content: .init(text: AttributedString("Following paragraph.")), role: .body, context: .readOnly, imagePhases: [:])
        }.frame(width: 140))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 340, height: 900))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        await settle(host.view)
        let views = textViews(in: host.view)
        #expect(views.count == 2)
        let first = try #require(views.first)
        #expect(first.text.hasSuffix("\n\n"))
        #expect(abs(first.bounds.width - 140) < 1)
        let font = try #require(first.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        #expect(first.bounds.height >= 3 * font.lineHeight)
        try expectCompleteLayout(views, in: host.view, knownTerminalLineIssue: true)
    }

    @Test func imagePhasesComposeInSourceOrderAndFitNativeWidth() throws {
        let content = FlatMarkRenderInlineContent(components: [
            .text(AttributedString("before\n")),
            .image(.init(url: nil, altText: "Diagram")),
            .text(AttributedString("\n\nafter"))
        ])
        let raster = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 300)).image { _ in }
        for width: CGFloat in [140, 280, 700, 140] {
            let native = FlatMarkParagraphText.attributedText(
                for: content, policy: .literal, dynamicTypeSize: .large,
                layoutDirection: .rightToLeft, alignment: .leading,
                imagePhases: [1: .loaded(raster)], width: width)
            #expect(native.string == "before\n\u{FFFC}\n\nafter")
            let attachment = try #require(native.attribute(.attachment, at: 7, effectiveRange: nil) as? NSTextAttachment)
            #expect(attachment.bounds.width == min(width, 600))
            #expect(attachment.bounds.height == min(width, 600) / 2)
            let paragraph = try #require(native.attribute(.paragraphStyle, at: 7, effectiveRange: nil) as? NSParagraphStyle)
            #expect(paragraph.baseWritingDirection == .rightToLeft)
        }
        for phase in [FlatMarkInlineView.ImagePhase.placeholder, .loading, .failed] {
            let native = FlatMarkParagraphText.attributedText(
                for: content, policy: .literal, dynamicTypeSize: .large,
                layoutDirection: .leftToRight, alignment: .leading, imagePhases: [1: phase], width: 140)
            #expect(native.string == "before\n\u{FFFC} Diagram\n\nafter")
            let attachment = try #require(native.attribute(.attachment, at: 7, effectiveRange: nil) as? NSTextAttachment)
            #expect(attachment.bounds.size == .zero)
        }
    }

    @Test func linkedImageAttachmentsKeepTheirDestinationInEveryPhase() throws {
        let destination = try #require(URL(string: "https://example.com/details"))
        let raster = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 10)).image { _ in }
        let image = FlatMarkRenderImage(url: nil, altText: "A long meaningful description", link: destination)
        for phase in [FlatMarkInlineView.ImagePhase.placeholder, .loading, .failed, .loaded(raster)] {
            let native = FlatMarkImagePresentation(image: image, phase: phase, policy: .literal)
                .attributedText(width: 140, font: .preferredFont(forTextStyle: .body))
            #expect(native.attribute(.link, at: 0, effectiveRange: nil) as? URL == destination)
            if case .loaded = phase {
                let attachment = try #require(native.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment)
                #expect(attachment.bounds.size == raster.size)
            } else {
                #expect(native.string.contains("A long meaningful description"))
            }
        }
    }

    private func textViews(in view: UIView) -> [UITextView] {
        if let text = view as? UITextView { return [text] }
        return view.subviews.flatMap { textViews(in: $0) }
    }

    private func settle(_ view: UIView) async {
        for _ in 0..<3 { await Task.yield() }
        try? await Task.sleep(for: .milliseconds(30))
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    private func expectCompleteLayout(_ views: [UITextView], in root: UIView, knownTerminalLineIssue: Bool = false) throws {
        let first = try #require(views.first)
        let second = try #require(views.last)
        #expect(first.isSelectable && !first.isEditable && !first.isScrollEnabled)
        #expect(first.backgroundColor == .clear)
        #expect(first.textContainerInset == .zero)
        #expect(first.textContainer.lineFragmentPadding == 0)
        let container = first.textContainer
        #expect(abs(container.size.width - first.bounds.width) < 1)
        let bottom: CGFloat
        var sourceBottom: CGFloat = 0
        if let manager = first.textLayoutManager {
            manager.ensureLayout(for: manager.documentRange)
            var laidOutBottom: CGFloat = 0
            manager.enumerateTextLayoutFragments(from: manager.documentRange.location,
                                                 options: [.ensuresLayout, .ensuresExtraLineFragment]) { fragment in
                laidOutBottom = max(laidOutBottom, fragment.layoutFragmentFrame.maxY)
                for line in fragment.textLineFragments {
                    if line.characterRange.length > 0 {
                        sourceBottom = max(sourceBottom,
                            fragment.layoutFragmentFrame.minY + line.typographicBounds.maxY)
                    }
                    laidOutBottom = max(laidOutBottom,
                        fragment.layoutFragmentFrame.minY + line.typographicBounds.maxY)
                }
                return true
            }
            bottom = laidOutBottom
        } else {
            // Accessing layoutManager is safe only when TextKit 2 is already absent.
            let manager = first.layoutManager
            manager.ensureLayout(for: container)
            let used = manager.usedRect(for: container)
            let glyphs = manager.boundingRect(forGlyphRange: manager.glyphRange(for: container), in: container)
            sourceBottom = max(used.maxY, glyphs.maxY)
            bottom = max(sourceBottom, manager.extraLineFragmentRect.maxY)
        }
        #expect(first.bounds.height >= ceil(sourceBottom))
        if knownTerminalLineIssue {
            // Owner accepts the #33 terminal-empty-line qualification gap, not a sizing fix.
            withKnownIssue("#33: terminal-empty-line bottom exceeds the allocation; AC-24 failed, AC-25 partial") {
                #expect(first.bounds.height >= ceil(bottom))
            }
        } else {
            #expect(first.bounds.height >= ceil(bottom))
        }
        #expect(first.convert(first.bounds, to: root).maxY <= second.convert(second.bounds, to: root).minY)
    }

    @Test func semanticTypographyScalesAndKeepsDirectionSeparateFromAlignment() throws {
        var text = AttributedString("مرحبا café")
        text.font = .system(size: 99)
        text.foregroundColor = .purple
        text.backgroundColor = .orange
        let content = FlatMarkRenderInlineContent(text: text)
        let body = render(content)
        let enlarged = FlatMarkParagraphText.attributedText(
            for: content, policy: .literal, dynamicTypeSize: .accessibility3,
            layoutDirection: .rightToLeft, alignment: .trailing
        )
        let bodyFont = try #require(body.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        let largeFont = try #require(enlarged.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        #expect(bodyFont.pointSize == UIFont.preferredFont(forTextStyle: .body,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)).pointSize)
        #expect(largeFont.pointSize > bodyFont.pointSize)
        #expect(enlarged.string == "مرحبا café")
        #expect(enlarged.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor == UIColor(Color.purple))
        #expect(enlarged.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? UIColor == UIColor(Color.orange))
        let paragraph = try #require(enlarged.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        #expect(paragraph.baseWritingDirection == .rightToLeft)
        #expect(paragraph.alignment == .left)
    }

    /// A SwiftUI `Font` attribute never drives the native path: each heading level resolves its own
    /// semantic system font, and the role adds bold emphasis on top.
    @Test(arguments: [
        (1, UIFont.TextStyle.title1), (2, .title2), (3, .title3),
        (4, .headline), (5, .headline), (6, .headline),
    ] as [(Int, UIFont.TextStyle)])
    func headingRolesResolveSemanticBoldTypeWithoutFixedSizes(level: Int, style: UIFont.TextStyle) throws {
        var text = AttributedString("Head")
        text.font = .system(size: 1)
        let native = render(.init(text: text), role: .heading(level: level))
        let font = try #require(native.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        let expected = UIFont.preferredFont(
            forTextStyle: style,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
        )
        #expect(font.pointSize == expected.pointSize)
        #expect(font.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    @Test func tableHeaderRoleBoldensBodyTypeWithoutChangingSize() throws {
        let native = render(.init(text: AttributedString("Owner")), role: .tableHeader)
        let font = try #require(native.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        let body = UIFont.preferredFont(
            forTextStyle: .body,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
        )
        #expect(font.pointSize == body.pointSize)
        #expect(font.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    /// Emphasis, strong text, and inline code derive their typography from the resolved heading role.
    @Test func inlineTraitsDeriveFromTheHeadingRoleFont() throws {
        var code = AttributedString("code")
        code.inlinePresentationIntent = .code
        var emphasis = AttributedString("em")
        emphasis.inlinePresentationIntent = .emphasized
        let native = render(.init(components: [.text(code), .text(emphasis)]), role: .heading(level: 1))
        let title = UIFont.preferredFont(
            forTextStyle: .title1,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
        )
        let codeFont = try #require(native.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        #expect(codeFont.pointSize == title.pointSize)
        #expect(codeFont.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
        let emphasisFont = try #require(native.attribute(.font, at: 5, effectiveRange: nil) as? UIFont)
        #expect(emphasisFont.pointSize == title.pointSize)
        #expect(emphasisFont.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }

    @Test func hostFontAndColorOverrideTheRoleDefaultWhileNeighborsKeepIt() throws {
        var host = AttributedString("host")
        let hostFont = UIFont.boldSystemFont(ofSize: 21)
        host.uiKit.font = hostFont
        host.uiKit.foregroundColor = .systemTeal
        let native = render(.init(components: [.text(host), .text(AttributedString(" x"))]), role: .heading(level: 1))
        #expect(native.attribute(.font, at: 0, effectiveRange: nil) as? UIFont == hostFont)
        #expect(native.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor == .systemTeal)
        let title = UIFont.preferredFont(
            forTextStyle: .title1,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
        )
        let neighborFont = try #require(native.attribute(.font, at: 5, effectiveRange: nil) as? UIFont)
        #expect(neighborFont.pointSize == title.pointSize)
        #expect(neighborFont.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    private func render(
        _ content: FlatMarkRenderInlineContent,
        policy: FlatMarkUnsupportedContentPolicy = .literal,
        role: FlatMarkTextRole = .body
    ) -> NSAttributedString {
        FlatMarkParagraphText.attributedText(for: content, policy: policy, role: role,
                                            dynamicTypeSize: .large,
                                            layoutDirection: .leftToRight, alignment: .leading)
    }
}

/// Probe unchosen widths, then place the native bridge at a different width.
private struct ParagraphProposalProbe: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        for probe in [ProposedViewSize.unspecified, ProposedViewSize(width: .infinity, height: nil),
                      ProposedViewSize(width: 320, height: nil)] {
            let size = subviews[0].sizeThatFits(probe)
            // UIKit declines unconstrained widths; SwiftUI's fallback may preserve infinity.
            if probe.width != .infinity {
                #expect(size.width.isFinite && size.height.isFinite)
            }
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
#endif
