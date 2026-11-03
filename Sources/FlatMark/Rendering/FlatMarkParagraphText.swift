#if os(iOS)
import SwiftUI
import UIKit

/// Native text for image-free paragraphs. Image routing remains the caller's responsibility.
struct FlatMarkParagraphText: UIViewRepresentable {
    let content: FlatMarkRenderInlineContent
    let context: FlatMarkRenderContext

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.multilineTextAlignment) private var alignment
    @Environment(\.openURL) private var openURL

    func makeCoordinator() -> Coordinator {
        Coordinator(openURL: openURL)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        // Native storage owns link colors, including explicit host overrides.
        view.linkTextAttributes = [:]
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.openURL = openURL
        view.attributedText = Self.attributedText(
            for: content,
            policy: self.context.unsupportedContentPolicy,
            dynamicTypeSize: dynamicTypeSize,
            layoutDirection: layoutDirection,
            alignment: alignment
        )
        view.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(size.height))
    }

    static func attributedText(
        for content: FlatMarkRenderInlineContent,
        policy: FlatMarkUnsupportedContentPolicy,
        dynamicTypeSize: DynamicTypeSize,
        layoutDirection: LayoutDirection,
        alignment: TextAlignment
    ) -> NSAttributedString {
        let category: UIContentSizeCategory
        switch dynamicTypeSize {
        case .xSmall: category = .extraSmall
        case .small: category = .small
        case .medium: category = .medium
        case .large: category = .large
        case .xLarge: category = .extraLarge
        case .xxLarge: category = .extraExtraLarge
        case .xxxLarge: category = .extraExtraExtraLarge
        case .accessibility1: category = .accessibilityMedium
        case .accessibility2: category = .accessibilityLarge
        case .accessibility3: category = .accessibilityExtraLarge
        case .accessibility4: category = .accessibilityExtraExtraLarge
        case .accessibility5: category = .accessibilityExtraExtraExtraLarge
        @unknown default: category = .large
        }
        let body = UIFont.preferredFont(
            forTextStyle: .body,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: category)
        )
        let result = NSMutableAttributedString(string: "")
        for component in content.components {
            let text: AttributedString
            switch component {
            case let .text(value): text = value
            case let .unsupported(value):
                text = FlatMarkInlineView.replacementText(for: value, policy: policy)
            case .image:
                preconditionFailure("Image-containing content must use the existing image renderer")
            }
            for run in text.runs {
                let slice = AttributedString(text[run.range])
                let native = NSMutableAttributedString(attributedString: NSAttributedString(slice))
                let range = NSRange(location: 0, length: native.length)
                guard range.length > 0 else { continue }
                let intents = run.inlinePresentationIntent ?? []
                // Native host fonts are authoritative. SwiftUI fonts use semantic native typography.
                if native.attribute(.font, at: 0, effectiveRange: nil) == nil {
                    var font = body
                    if intents.contains(.code) {
                        font = .monospacedSystemFont(ofSize: body.pointSize, weight: .regular)
                    }
                    var traits = font.fontDescriptor.symbolicTraits
                    if intents.contains(.stronglyEmphasized) { traits.insert(.traitBold) }
                    if intents.contains(.emphasized) { traits.insert(.traitItalic) }
                    if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                        font = UIFont(descriptor: descriptor, size: font.pointSize)
                    }
                    native.addAttribute(.font, value: font, range: range)
                }
                if native.attribute(.foregroundColor, at: 0, effectiveRange: nil) == nil {
                    if let color = run.swiftUI.foregroundColor {
                        native.addAttribute(.foregroundColor, value: UIColor(color), range: range)
                    } else {
                        native.addAttribute(
                            .foregroundColor, value: run.link == nil ? UIColor.label : UIColor.link, range: range
                        )
                    }
                }
                if native.attribute(.backgroundColor, at: 0, effectiveRange: nil) == nil,
                   let color = run.swiftUI.backgroundColor {
                    native.addAttribute(.backgroundColor, value: UIColor(color), range: range)
                }
                if intents.contains(.strikethrough),
                   native.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) == nil {
                    native.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                }
                let paragraph = (native.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                    as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                    ?? NSMutableParagraphStyle()
                paragraph.baseWritingDirection = layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
                switch alignment {
                case .center: paragraph.alignment = .center
                case .leading: paragraph.alignment = layoutDirection == .rightToLeft ? .right : .left
                case .trailing: paragraph.alignment = layoutDirection == .rightToLeft ? .left : .right
                }
                native.addAttribute(.paragraphStyle, value: paragraph, range: range)
                result.append(native)
            }
        }
        return result
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var openURL: OpenURLAction

        init(openURL: OpenURLAction) {
            self.openURL = openURL
        }

        func textView(
            _ textView: UITextView,
            primaryActionFor textItem: UITextItem,
            defaultAction: UIAction
        ) -> UIAction? {
            guard case let .link(url) = textItem.content else { return defaultAction }
            return UIAction { [weak self] _ in
                self?.openURL(url)
            }
        }
    }
}
#endif
