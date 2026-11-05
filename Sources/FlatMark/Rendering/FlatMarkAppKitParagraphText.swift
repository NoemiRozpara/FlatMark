#if os(macOS)
import AppKit
import SwiftUI

extension NSAttributedString.Key {
    static let flatMarkImage = NSAttributedString.Key("FlatMarkImageAccessibility")
}

/// Each composed image owns one metadata value, even when destinations repeat.
final class FlatMarkImageAccessibility: NSObject {
    let label: String
    let linkLabel: String?
    let url: URL?

    init(label: String, linkLabel: String?, url: URL?) {
        self.label = label
        self.linkLabel = linkLabel
        self.url = url
    }
}

/// Selectable native inline content with component-owned image phases.
struct FlatMarkParagraphText: NSViewRepresentable {
    let content: FlatMarkRenderInlineContent
    let role: FlatMarkTextRole
    let imagePhases: [Int: FlatMarkInlineView.ImagePhase]

    init(content: FlatMarkRenderInlineContent, role: FlatMarkTextRole, context: FlatMarkRenderContext,
         imagePhases: [Int: FlatMarkInlineView.ImagePhase] = [:]) {
        // Resolve host output with this render value, not during later native layout updates.
        self.content = FlatMarkRenderInlineContent(components: content.components.map { component in
            switch component {
            case let .unsupported(value):
                return .text(FlatMarkInlineView.replacementText(for: value, policy: context.unsupportedContentPolicy))
            case let .image(image):
                return .image(FlatMarkRenderImage(url: image.url,
                    altText: context.unsupportedContentPolicy.imageLabel(for: image), link: image.link))
            case .text:
                return component
            }
        })
        self.role = role
        self.imagePhases = imagePhases
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
        let paragraph = view as! ParagraphTextView
        paragraph.compose = { width in Self.attributedText(
            for: content, policy: .literal, role: role,
            layoutDirection: layoutDirection, alignment: alignment,
            imagePhases: imagePhases, width: width
        ) }
        paragraph.invalidateComposition()
        paragraph.refresh(width: view.bounds.width)
        view.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextView, context: Context) -> CGSize? {
        // SwiftUI can probe several widths without committing a frame. Keep probes off the
        // displayed container so an unchosen proposal cannot change visible wrapping.
        let width = proposal.width.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        let storage = NSTextStorage(attributedString: Self.attributedText(
            for: content, policy: .literal, role: role,
            layoutDirection: layoutDirection, alignment: alignment,
            imagePhases: imagePhases, width: width ?? .greatestFiniteMagnitude
        ))
        let manager = NSLayoutManager()
        let container = NSTextContainer()
        container.lineFragmentPadding = 0
        storage.addLayoutManager(manager)
        manager.addTextContainer(container)
        // Zero asks for minimum width; only an unspecified or unbounded proposal asks for ideal width.
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

    nonisolated static func attributedText(
        for content: FlatMarkRenderInlineContent,
        policy: FlatMarkUnsupportedContentPolicy,
        role: FlatMarkTextRole = .body,
        layoutDirection: LayoutDirection,
        alignment: TextAlignment,
        imagePhases: [Int: FlatMarkInlineView.ImagePhase] = [:],
        width: CGFloat = .greatestFiniteMagnitude
    ) -> NSAttributedString {
        let roleFont = Self.roleFont(for: role)
        let result = NSMutableAttributedString(string: "")
        func append(_ native: NSMutableAttributedString) {
            let range = NSRange(location: 0, length: native.length)
            guard range.length > 0 else { return }
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
        for (index, component) in content.components.enumerated() {
            let text: AttributedString
            switch component {
            case let .text(value): text = value
            case let .unsupported(value):
                text = FlatMarkInlineView.replacementText(for: value, policy: policy)
            case let .image(image):
                let native = NSMutableAttributedString(attributedString:
                    FlatMarkImagePresentation(image: image, phase: imagePhases[index] ?? .placeholder, policy: policy)
                        .attributedText(width: width, font: roleFont))
                append(native)
                continue
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
                append(native)
            }
        }
        return result
    }

    /// SwiftUI does not read NSTextView's native baseline through NSViewRepresentable.
    /// Resolve the first glyph's baseline from the displayed typography and offered width.
    // Each synchronous call owns its TextKit graph; no displayed view or mutable layout is shared.
    // Apple's Text Layout Programming Guide permits this with background layout disabled:
    // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextLayout/Concepts/LayoutManager.html
    nonisolated func firstBaseline(width: CGFloat) -> CGFloat {
        let storage = NSTextStorage(attributedString: Self.attributedText(
            for: content, policy: .literal, role: role,
            layoutDirection: .leftToRight, alignment: .leading,
            imagePhases: imagePhases, width: width
        ))
        guard storage.length > 0 else { return 0 }
        let manager = NSLayoutManager()
        manager.backgroundLayoutEnabled = false
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
    nonisolated static func roleFont(for role: FlatMarkTextRole) -> NSFont {
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
        var compose: ((CGFloat) -> NSAttributedString)?
        private var composedWidth: CGFloat?
        private var needsComposition = true
        private var revision = 0
        private var retainedChildren: [Any] = []
        private var nativeChildren: [Any] = []
        private var imageLinks: [(NSRange, ImageLink)] = []
        private var childrenRevision = -1
        private var queryingChildren = false

        func refresh(width: CGFloat) {
            guard needsComposition || composedWidth != width, let compose else { return }
            needsComposition = false
            composedWidth = width
            revision += 1
            textStorage?.setAttributedString(compose(width))
        }

        func invalidateComposition() {
            needsComposition = true
        }

        override func accessibilityLabel() -> String? {
            guard let storage = textStorage else { return super.accessibilityLabel() }
            let result = NSMutableString(string: storage.string)
            var replacements: [(NSRange, String)] = []
            storage.enumerateAttribute(.flatMarkImage, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
                guard let image = value as? FlatMarkImageAccessibility else { return }
                replacements.append((range, image.linkLabel ?? image.label))
            }
            for (range, label) in replacements.reversed() { result.replaceCharacters(in: range, with: label) }
            return result as String
        }

        override func accessibilityChildren() -> [Any]? {
            // AppKit may query recursively while constructing its native children.
            guard !queryingChildren else { return retainedChildren }
            queryingChildren = true
            defer { queryingChildren = false }
            if childrenRevision != revision {
                childrenRevision = revision
                for (_, link) in imageLinks { link.press = nil }
                imageLinks = []
                nativeChildren = super.accessibilityChildren() ?? []
                guard let storage = textStorage else { return nativeChildren }
                var images: [(NSRange, FlatMarkImageAccessibility)] = []
                storage.enumerateAttribute(.flatMarkImage, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
                    if let image = value as? FlatMarkImageAccessibility, image.url != nil { images.append((range, image)) }
                }
                let currentRevision = revision
                for (range, image) in images {
                    let link = ImageLink()
                    link.setAccessibilityParent(self)
                    link.setAccessibilityRole(.link)
                    link.setAccessibilityTitle(image.linkLabel)
                    link.setAccessibilityURL(image.url)
                    link.press = { [weak self] in
                        guard let self, self.window != nil, self.revision == currentRevision,
                              let url = image.url else { return false }
                        return self.delegate?.textView?(self, clickedOnLink: url, at: range.location) ?? false
                    }
                    imageLinks.append((range, link))
                }
                // Replace only native image-link children. Keep native ordinary links and text.
                var remaining = imageLinks
                retainedChildren = []
                for child in nativeChildren {
                    if let native = child as? NSAccessibilityProtocol,
                       native.accessibilityRole() == .link,
                       native.accessibilityTitle()?.contains("\u{FFFC}") == true {
                        let url = native.accessibilityURL()
                        let attachmentCount = native.accessibilityTitle()?.filter { $0 == "\u{FFFC}" }.count ?? 0
                        let matching = Array(remaining.filter { item in
                            item.1.accessibilityURL() == url
                        }.prefix(attachmentCount))
                        retainedChildren.append(contentsOf: matching.map(\.1))
                        remaining.removeAll { item in matching.contains { $0.1 === item.1 } }
                    } else {
                        retainedChildren.append(child)
                    }
                }
                retainedChildren.append(contentsOf: remaining.map(\.1))
            }
            for (range, link) in imageLinks { link.setAccessibilityFrame(accessibilityFrame(for: range)) }
            return retainedChildren
        }

        final class ImageLink: NSAccessibilityElement {
            var press: (@MainActor @Sendable () -> Bool)?

            override func accessibilityPerformPress() -> Bool {
                guard let press else { return false }
                return MainActor.assumeIsolated { press() }
            }
        }

        override func draw(_ dirtyRect: NSRect) {
            if let container = textContainer { layoutManager?.ensureLayout(for: container) }
            super.draw(dirtyRect)
        }

        override func layout() {
            refresh(width: bounds.width)
            textContainer?.containerSize = CGSize(width: bounds.width, height: .greatestFiniteMagnitude)
            super.layout()
        }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            refresh(width: newSize.width)
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
