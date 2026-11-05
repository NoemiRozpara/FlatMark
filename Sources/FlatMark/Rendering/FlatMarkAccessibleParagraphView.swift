#if os(iOS)
import UIKit

/// Native drawing and selection with ordered semantic accessibility boundaries.
final class FlatMarkAccessibleParagraphView: UIView {
    let textView = UITextView()
    var activateLink: ((URL) -> Void)?
    var compose: ((CGFloat) -> NSAttributedString)? {
        didSet { measuredWidth = nil }
    }
    fileprivate var revision = 0
    private var measuredWidth: CGFloat?

    override init(frame: CGRect) {
        super.init(frame: frame)
        textView.accessibilityElementsHidden = true
        addSubview(textView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = bounds
        if bounds.width > 0, measuredWidth != bounds.width { refresh(width: bounds.width) }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize { textView.sizeThatFits(size) }

    func refresh(width: CGFloat) {
        let width = width > 0 ? width : CGFloat.greatestFiniteMagnitude
        guard measuredWidth != width, let compose else { return }
        measuredWidth = width
        let text = compose(width)
        textView.attributedText = text
        revision += 1
        let currentRevision = revision
        let hasImages = containsImageMetadata(text)
        textView.accessibilityElementsHidden = hasImages
        if !hasImages {
            accessibilityElements = nil
            return
        }
        var elements: [FlatMarkParagraphAccessibleRun] = []
        var offset = 0
        while offset < text.length {
            var imageRange = NSRange()
            // Ignore attachment and styling boundaries within the same semantic run.
            let fullRange = NSRange(location: 0, length: text.length)
            let image = text.attribute(FlatMarkImagePresentation.identityKey, at: offset,
                                       longestEffectiveRange: &imageRange, in: fullRange)
            var linkRange = NSRange()
            let url = text.attribute(.link, at: offset, longestEffectiveRange: &linkRange, in: fullRange) as? URL
            let end = min(NSMaxRange(imageRange), NSMaxRange(linkRange))
            let range = NSRange(location: offset, length: end - offset)
            let label = image == nil ? (text.string as NSString).substring(with: range)
                : text.attribute(FlatMarkImagePresentation.labelKey, at: offset, effectiveRange: nil) as? String ?? "Image"
            if !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                elements.append(FlatMarkParagraphAccessibleRun(view: self, range: range, label: label,
                                                               url: url, revision: currentRevision))
            }
            offset = end
        }
        isAccessibilityElement = false
        accessibilityElements = elements
    }

    private func containsImageMetadata(_ text: NSAttributedString) -> Bool {
        var found = false
        text.enumerateAttribute(FlatMarkImagePresentation.identityKey, in: NSRange(location: 0, length: text.length)) { value, _, stop in
            if value != nil { found = true; stop.pointee = true }
        }
        return found
    }

    fileprivate func activate(_ url: URL, revision: Int) -> Bool {
        guard revision == self.revision, let activateLink else { return false }
        activateLink(url)
        return true
    }
}

private final class FlatMarkParagraphAccessibleRun: UIAccessibilityElement {
    weak var view: FlatMarkAccessibleParagraphView?
    let range: NSRange
    let url: URL?
    let revision: Int

    init(view: FlatMarkAccessibleParagraphView, range: NSRange, label: String, url: URL?, revision: Int) {
        self.view = view
        self.range = range
        self.url = url
        self.revision = revision
        super.init(accessibilityContainer: view)
        accessibilityLabel = label
        accessibilityTraits = url == nil ? .staticText : .link
    }

    override var accessibilityFrame: CGRect {
        get {
            guard let view, view.revision == revision else { return .zero }
            let text = view.textView
            guard let start = text.position(from: text.beginningOfDocument, offset: range.location),
                  let end = text.position(from: start, offset: range.length),
                  let selection = text.textRange(from: start, to: end) else { return .zero }
            var rect = text.selectionRects(for: selection).reduce(CGRect.null) { $0.union($1.rect) }
            if rect.isNull || rect.isEmpty { rect = text.firstRect(for: selection) }
            return rect.isNull ? .zero : UIAccessibility.convertToScreenCoordinates(rect, in: text)
        }
        set {}
    }

    override func accessibilityActivate() -> Bool {
        guard let url else { return false }
        return view?.activate(url, revision: revision) ?? false
    }
}
#endif
