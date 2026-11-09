#if os(iOS)
import SwiftUI
import UIKit

/// Selectable native inline content with component-owned image phases.
struct FlatMarkParagraphText: UIViewRepresentable {
    let content: FlatMarkRenderInlineContent
    let role: FlatMarkTextRole
    let context: FlatMarkRenderContext

    let imagePhases: [Int: FlatMarkInlineView.ImagePhase]

    init(content: FlatMarkRenderInlineContent, role: FlatMarkTextRole, context: FlatMarkRenderContext,
         imagePhases: [Int: FlatMarkInlineView.ImagePhase]) {
        self.content = content
        self.role = role
        self.context = context
        self.imagePhases = imagePhases
    }

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
        let inputs = CompositionInputs(content: content, role: role, policy: self.context.unsupportedContentPolicy,
                                       dynamicTypeSize: dynamicTypeSize, layoutDirection: layoutDirection,
                                       alignment: alignment, imagePhases: imagePhases)
        if context.coordinator.compositionInputs != inputs {
            context.coordinator.compositionInputs = inputs
            context.coordinator.composedWidth = nil
            context.coordinator.compose = { width in Self.attributedText(
                for: content,
                policy: self.context.unsupportedContentPolicy,
                role: role,
                dynamicTypeSize: dynamicTypeSize,
                layoutDirection: layoutDirection,
                alignment: alignment,
                imagePhases: imagePhases,
                width: width
            ) }
        }
        context.coordinator.refresh(view, width: view.bounds.width)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        context.coordinator.refresh(uiView, width: width)
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(size.height))
    }

    static func attributedText(
        for content: FlatMarkRenderInlineContent,
        policy: FlatMarkUnsupportedContentPolicy,
        role: FlatMarkTextRole = .body,
        dynamicTypeSize: DynamicTypeSize,
        layoutDirection: LayoutDirection,
        alignment: TextAlignment,
        imagePhases: [Int: FlatMarkInlineView.ImagePhase] = [:],
        width: CGFloat = .greatestFiniteMagnitude
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
        let roleFont = Self.roleFont(for: role, category: category)
        let result = NSMutableAttributedString(string: "")
        for (index, component) in content.components.enumerated() {
            let text: AttributedString
            switch component {
            case let .text(value): text = value
            case let .unsupported(value):
                text = policy.literalText(for: value)
            case let .image(image):
                let native = NSMutableAttributedString(attributedString:
                    FlatMarkImagePresentation(image: image, phase: imagePhases[index] ?? .placeholder, policy: policy)
                        .attributedText(width: width, font: roleFont))
                let paragraph = paragraphStyle(direction: layoutDirection, alignment: alignment)
                native.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: native.length))
                result.append(native)
                continue
            }
            for run in text.runs {
                let slice = AttributedString(text[run.range])
                let native = NSMutableAttributedString(attributedString: NSAttributedString(slice))
                let range = NSRange(location: 0, length: native.length)
                guard range.length > 0 else { continue }
                let intents = run.inlinePresentationIntent ?? []
                // Native host fonts are authoritative. SwiftUI fonts use semantic native typography.
                if native.attribute(.font, at: 0, effectiveRange: nil) == nil {
                    var font = roleFont
                    if intents.contains(.code) {
                        let weight: UIFont.Weight = role.includesBoldEmphasis ? .bold : .regular
                        font = .monospacedSystemFont(ofSize: roleFont.pointSize, weight: weight)
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
                let paragraph = paragraphStyle(
                    direction: layoutDirection,
                    alignment: alignment,
                    preserving: native.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
                )
                native.addAttribute(.paragraphStyle, value: paragraph, range: range)
                result.append(native)
            }
        }
        return result
    }

    private static func paragraphStyle(
        direction: LayoutDirection,
        alignment: TextAlignment,
        preserving existing: NSParagraphStyle? = nil
    ) -> NSMutableParagraphStyle {
        let paragraph = existing?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        paragraph.baseWritingDirection = direction == .rightToLeft ? .rightToLeft : .leftToRight
        switch alignment {
        case .center: paragraph.alignment = .center
        case .leading: paragraph.alignment = direction == .rightToLeft ? .right : .left
        case .trailing: paragraph.alignment = direction == .rightToLeft ? .left : .right
        }
        return paragraph
    }

    /// The role's semantic font at the given Dynamic Type size, without hardcoded point sizes.
    static func roleFont(for role: FlatMarkTextRole, category: UIContentSizeCategory) -> UIFont {
        let style: UIFont.TextStyle
        switch role {
        case .body, .tableHeader:
            style = .body
        case let .heading(level):
            switch level {
            case 1: style = .title1
            case 2: style = .title2
            case 3: style = .title3
            default: style = .headline
            }
        }
        let base = UIFont.preferredFont(
            forTextStyle: style,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: category)
        )
        guard role.includesBoldEmphasis else { return base }
        let traits = base.fontDescriptor.symbolicTraits.union(.traitBold)
        let descriptor = base.fontDescriptor.withSymbolicTraits(traits) ?? base.fontDescriptor
        return UIFont(descriptor: descriptor, size: base.pointSize)
    }

    struct CompositionInputs: Equatable {
        let content: FlatMarkRenderInlineContent
        let role: FlatMarkTextRole
        let policy: FlatMarkUnsupportedContentPolicy
        let dynamicTypeSize: DynamicTypeSize
        let layoutDirection: LayoutDirection
        let alignment: TextAlignment
        let imagePhases: [Int: FlatMarkInlineView.ImagePhase]
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var compositionInputs: CompositionInputs?
        var compose: ((CGFloat) -> NSAttributedString)?
        var composedWidth: CGFloat?
        var openURL: OpenURLAction

        func refresh(_ view: UITextView, width: CGFloat) {
            let width = width > 0 ? width : CGFloat.greatestFiniteMagnitude
            guard composedWidth != width, let compose else { return }
            view.attributedText = compose(width)
            composedWidth = width
        }

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
