#if os(iOS)
import SwiftUI
import Testing
import UIKit
@testable import FlatMark

@MainActor
struct FlatMarkParagraphTextTests {
    @Test func combinedIntentsPreserveUnicodeAndConsecutiveNewlines() throws {
        var text = AttributedString("👩🏽‍💻 café\n\n漢字")
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

    @Test func replacementInheritsIntentAndLinkWithoutChangingNeighbors() throws {
        let inheritedURL = try #require(URL(string: "https://example.com/inherited"))
        let neighborURL = try #require(URL(string: "https://example.com/neighbor"))
        var literal = AttributedString("<tag>")
        literal.inlinePresentationIntent = [.stronglyEmphasized, .emphasized]
        literal.link = inheritedURL
        var neighbor = AttributedString("after")
        neighbor.inlinePresentationIntent = .code
        neighbor.link = neighborURL
        let content = FlatMarkRenderInlineContent(components: [
            .text(AttributedString("before")),
            .unsupported(.init(literalText: literal)),
            .text(neighbor)
        ])
        let native = render(content, policy: .custom { _ in AttributedString("🦊\n\nR") })
        #expect(native.string == "before🦊\n\nRafter")
        let replacementRange = (native.string as NSString).range(of: "🦊\n\nR")
        for offset in replacementRange.location..<NSMaxRange(replacementRange) {
            let font = try #require(native.attribute(.font, at: offset, effectiveRange: nil) as? UIFont)
            #expect(font.fontDescriptor.symbolicTraits.contains([.traitBold, .traitItalic]))
            #expect(native.attribute(.link, at: offset, effectiveRange: nil) as? URL == inheritedURL)
        }
        #expect(native.attribute(.link, at: 0, effectiveRange: nil) == nil)
        let last = native.length - 1
        #expect(native.attribute(.link, at: last, effectiveRange: nil) as? URL == neighborURL)
        let font = try #require(native.attribute(.font, at: last, effectiveRange: nil) as? UIFont)
        #expect(font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
        #expect(!font.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    @Test func explicitEmptyIntentAndNativeHostAttributesWinPerRun() throws {
        let inheritedURL = try #require(URL(string: "https://example.com/inherited"))
        let hostURL = try #require(URL(string: "https://example.com/host"))
        var literal = AttributedString("<tag>")
        literal.inlinePresentationIntent = [.stronglyEmphasized, .emphasized, .strikethrough]
        literal.link = inheritedURL
        var plain = AttributedString("plain")
        plain.inlinePresentationIntent = []
        var host = AttributedString("host")
        let hostFont = UIFont.monospacedSystemFont(ofSize: 23, weight: .medium)
        host.uiKit.font = hostFont
        host.uiKit.foregroundColor = .systemPurple
        host.link = hostURL
        let replacement = plain + host
        let native = render(.init(components: [.unsupported(.init(literalText: literal))]),
                            policy: .custom { _ in replacement })
        let plainFont = try #require(native.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        #expect(!plainFont.fontDescriptor.symbolicTraits.contains(.traitBold))
        #expect(!plainFont.fontDescriptor.symbolicTraits.contains(.traitItalic))
        #expect(native.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) == nil)
        #expect(native.attribute(.link, at: 0, effectiveRange: nil) as? URL == inheritedURL)
        #expect(native.attribute(.font, at: 5, effectiveRange: nil) as? UIFont == hostFont)
        #expect(native.attribute(.foregroundColor, at: 5, effectiveRange: nil) as? UIColor == .systemPurple)
        #expect(native.attribute(.link, at: 5, effectiveRange: nil) as? URL == hostURL)
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

    private func render(
        _ content: FlatMarkRenderInlineContent,
        policy: FlatMarkUnsupportedContentPolicy = .literal
    ) -> NSAttributedString {
        FlatMarkParagraphText.attributedText(for: content, policy: policy,
                                            dynamicTypeSize: .large,
                                            layoutDirection: .leftToRight, alignment: .leading)
    }
}
#endif
