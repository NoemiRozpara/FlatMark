#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import FlatMark

@MainActor
struct FlatMarkAppKitParagraphTextTests {
    @Test func combinedIntentsPreserveUnicodeAndConsecutiveNewlines() throws {
        var text = AttributedString("👩🏽‍💻 café\n\n漢字")
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

    @Test func explicitEmptyIntentAndNativeHostAttributesWinPerRun() throws {
        let inheritedURL = try #require(URL(string: "https://example.com/inherited"))
        let hostURL = try #require(URL(string: "https://example.com/host"))
        var literal = AttributedString("<tag>")
        literal.inlinePresentationIntent = [.stronglyEmphasized, .emphasized, .strikethrough]
        literal.link = inheritedURL
        var plain = AttributedString("plain")
        plain.inlinePresentationIntent = []
        let hostFont = NSFont.monospacedSystemFont(ofSize: 23, weight: .medium)
        var host = AttributedString(NSAttributedString(string: "host", attributes: [
            .font: hostFont, .foregroundColor: NSColor.systemPurple
        ]))
        host.link = hostURL
        let replacement = plain + host
        let native = render(.init(components: [.unsupported(.init(literalText: literal))]),
                            policy: .custom { _ in replacement })
        let plainFont = try #require(native.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(!plainFont.fontDescriptor.symbolicTraits.contains(.bold))
        #expect(!plainFont.fontDescriptor.symbolicTraits.contains(.italic))
        #expect(native.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) == nil)
        #expect(native.attribute(.link, at: 0, effectiveRange: nil) as? URL == inheritedURL)
        #expect(native.attribute(.font, at: 5, effectiveRange: nil) as? NSFont == hostFont)
        #expect(native.attribute(.foregroundColor, at: 5, effectiveRange: nil) as? NSColor == .systemPurple)
        #expect(native.attribute(.link, at: 5, effectiveRange: nil) as? URL == hostURL)
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

    @Test func retainedReplacementUpdatesWordingHeightDirectionAndHostAttributes() async throws {
        let document = FlatMarkDocument(markdown: "Before <tag> after.\n\nFollowing paragraph.")
        let font = NSFont.monospacedSystemFont(ofSize: 23, weight: .medium)
        func replacement(_ wording: String) -> AttributedString {
            AttributedString(NSAttributedString(string: wording, attributes: [
                .font: font, .foregroundColor: NSColor.systemPurple
            ]))
        }
        func root(_ wording: String, direction: LayoutDirection) -> some View {
            FlatMarkView(document: document, unsupportedContentPolicy: .custom { _ in replacement(wording) })
                .environment(\.layoutDirection, direction)
        }
        let hosted = await mountTestView(root("short", direction: .leftToRight), size: CGSize(width: 260, height: 800))
        defer { hosted.close() }
        func textViews(in view: NSView) -> [NSTextView] {
            if let text = view as? NSTextView { return [text] }
            return view.subviews.flatMap { textViews(in: $0) }
        }
        let original = try #require(textViews(in: hosted.view).first)
        var heights: [CGFloat] = []
        for (wording, direction) in [("short", LayoutDirection.leftToRight), ("café مرحبا 123\nsecond\nthird", .rightToLeft), ("short", .leftToRight)] {
            hosted.view.rootView = root(wording, direction: direction)
            await settleMountedRendering()
            hosted.view.layoutSubtreeIfNeeded()
            let views = textViews(in: hosted.view)
            #expect(views.count == 2)
            let first = try #require(views.first)
            #expect(first === original)
            #expect(first.string == "Before \(wording) after.")
            let storage = try #require(first.textStorage)
            let offset = (first.string as NSString).range(of: wording).location
            #expect(storage.attribute(.font, at: offset, effectiveRange: nil) as? NSFont == font)
            #expect(storage.attribute(.foregroundColor, at: offset, effectiveRange: nil) as? NSColor == .systemPurple)
            let paragraph = try #require(storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
            #expect(paragraph.baseWritingDirection == (direction == .rightToLeft ? .rightToLeft : .leftToRight))
            #expect(paragraph.alignment == (direction == .rightToLeft ? .right : .left))
            heights.append(first.bounds.height)
        }
        #expect(heights[1] > heights[0])
        #expect(heights[2] == heights[0])
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
