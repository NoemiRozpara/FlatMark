#if os(macOS)
import AppKit
import SwiftUI

/// Native text for image-free inline content. Image routing remains the caller's responsibility.
struct FlatMarkParagraphText: NSViewRepresentable {
    let content: FlatMarkRenderInlineContent
    let role: FlatMarkTextRole

    init(content: FlatMarkRenderInlineContent, role: FlatMarkTextRole, context: FlatMarkRenderContext) {
        // Resolve host output with this render value, not during later native layout updates.
        self.content = FlatMarkRenderInlineContent(components: content.components.map { component in
            if case let .unsupported(value) = component {
                return .text(FlatMarkInlineView.replacementText(for: value, policy: context.unsupportedContentPolicy))
            }
            return component
        })
        self.role = role
    }

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.multilineTextAlignment) private var alignment
    @Environment(\.openURL) private var openURL

    func makeCoordinator() -> Coordinator { Coordinator(openURL: openURL) }

    func makeNSView(context: Context) -> NSTextView {
        let view = ParagraphTextView(usingTextLayoutManager: false)
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = true
        view.isHorizontallyResizable = false
        view.isVerticallyResizable = false
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        // The proposal, not a previous view frame, owns the container's dimensions.
        view.textContainer?.widthTracksTextView = false
        view.textContainer?.heightTracksTextView = false
        view.linkTextAttributes = [:]
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ view: NSTextView, context: Context) {
        context.coordinator.openURL = openURL
        view.textStorage?.setAttributedString(Self.attributedText(
            for: content, policy: .literal, role: role,
            layoutDirection: layoutDirection, alignment: alignment
        ))
        view.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextView, context: Context) -> CGSize? {
        // SwiftUI can probe several widths without committing a frame. Keep probes off the
        // displayed container so an unchosen proposal cannot change visible wrapping.
        let storage = NSTextStorage(attributedString: nsView.attributedString())
        let manager = NSLayoutManager()
        let container = NSTextContainer()
        container.lineFragmentPadding = 0
        storage.addLayoutManager(manager)
        manager.addTextContainer(container)
        // Zero asks for minimum width; only an unspecified or unbounded proposal asks for ideal width.
        let width = proposal.width.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        container.containerSize = CGSize(width: width ?? .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        manager.ensureLayout(for: container)
        let used = manager.usedRect(for: container)
        // A trailing newline has an empty line beyond the last laid-out glyph.
        let height = max(used.maxY, manager.extraLineFragmentRect.maxY)
        let glyphBounds = manager.boundingRect(forGlyphRange: manager.glyphRange(for: container), in: container)
        return withExtendedLifetime(storage) {
            CGSize(width: width ?? ceil(glyphBounds.width), height: ceil(height))
        }
    }

    static func attributedText(
        for content: FlatMarkRenderInlineContent,
        policy: FlatMarkUnsupportedContentPolicy,
        role: FlatMarkTextRole = .body,
        layoutDirection: LayoutDirection,
        alignment: TextAlignment
    ) -> NSAttributedString {
        let roleFont = Self.roleFont(for: role)
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
                let native = NSMutableAttributedString(attributedString: NSAttributedString(AttributedString(text[run.range])))
                let range = NSRange(location: 0, length: native.length)
                guard range.length > 0 else { continue }
                let intents = run.inlinePresentationIntent ?? []
                // Native host fonts are authoritative. SwiftUI fonts use semantic native typography.
                if native.attribute(.font, at: 0, effectiveRange: nil) == nil {
                    var font = roleFont
                    if intents.contains(.code) {
                        let weight: NSFont.Weight = role.includesBoldEmphasis ? .bold : .regular
                        font = .monospacedSystemFont(ofSize: roleFont.pointSize, weight: weight)
                    }
                    var traits = font.fontDescriptor.symbolicTraits
                    if intents.contains(.stronglyEmphasized) { traits.insert(.bold) }
                    if intents.contains(.emphasized) { traits.insert(.italic) }
                    let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
                    font = NSFont(descriptor: descriptor, size: font.pointSize) ?? font
                    native.addAttribute(.font, value: font, range: range)
                }
                if native.attribute(.foregroundColor, at: 0, effectiveRange: nil) == nil {
                    let color = run.swiftUI.foregroundColor.map { NSColor($0) }
                        ?? (run.link == nil ? NSColor.textColor : NSColor.linkColor)
                    native.addAttribute(.foregroundColor, value: color, range: range)
                }
                if native.attribute(.backgroundColor, at: 0, effectiveRange: nil) == nil,
                   let color = run.swiftUI.backgroundColor {
                    native.addAttribute(.backgroundColor, value: NSColor(color), range: range)
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

    /// SwiftUI does not read NSTextView's native baseline through NSViewRepresentable.
    /// Resolve the first glyph's baseline from the displayed typography and offered width.
    func firstBaseline(width: CGFloat) -> CGFloat {
        let storage = NSTextStorage(attributedString: Self.attributedText(
            for: content, policy: .literal, role: role,
            layoutDirection: .leftToRight, alignment: .leading
        ))
        guard storage.length > 0 else { return 0 }
        let manager = NSLayoutManager()
        let container = NSTextContainer(containerSize: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(manager)
        manager.addTextContainer(container)
        manager.ensureLayout(for: container)
        let glyph = manager.glyphIndexForCharacter(at: 0)
        let line = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        return withExtendedLifetime(storage) { line.minY + manager.location(forGlyphAt: glyph).y }
    }

    /// The role's semantic AppKit font, without hardcoded point sizes.
    static func roleFont(for role: FlatMarkTextRole) -> NSFont {
        let style: NSFont.TextStyle
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
        let base = NSFont.preferredFont(forTextStyle: style)
        guard role.includesBoldEmphasis else { return base }
        let traits = base.fontDescriptor.symbolicTraits.union(.bold)
        let descriptor = base.fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: descriptor, size: base.pointSize) ?? base
    }

    /// Commits the allocated width to native layout before AppKit draws cached glyphs.
    final class ParagraphTextView: NSTextView {
        override func draw(_ dirtyRect: NSRect) {
            if let container = textContainer { layoutManager?.ensureLayout(for: container) }
            super.draw(dirtyRect)
        }

        override func layout() {
            textContainer?.containerSize = CGSize(width: bounds.width, height: .greatestFiniteMagnitude)
            super.layout()
        }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            textContainer?.containerSize = CGSize(width: newSize.width, height: .greatestFiniteMagnitude)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var openURL: OpenURLAction

        init(openURL: OpenURLAction) { self.openURL = openURL }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            guard let url = link as? URL ?? (link as? String).flatMap(URL.init(string:)) else { return true }
            openURL(url)
            // SwiftUI's current opener owns default handling as well as host decisions.
            return true
        }
    }
}
#endif
