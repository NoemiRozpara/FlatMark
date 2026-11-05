#if os(iOS)
import UIKit

/// Inline phase output. Request ownership remains with FlatMarkInlineView.
@MainActor
struct FlatMarkImagePresentation {
    let image: FlatMarkRenderImage
    let phase: FlatMarkInlineView.ImagePhase
    let policy: FlatMarkUnsupportedContentPolicy

    func attributedText(width: CGFloat, font: UIFont) -> NSAttributedString {
        let imageLabel = policy.imageLabel(for: image)
        let result: NSMutableAttributedString
        switch phase {
        case let .loaded(image):
            let attachment = NSTextAttachment()
            attachment.image = image
            let size = image.size
            let scale = size.width > 0 ? min(1, max(1, width) / size.width) : 1
            attachment.bounds = CGRect(origin: .zero, size: CGSize(width: size.width * scale, height: size.height * scale))
            result = NSMutableAttributedString(attachment: attachment)
        case .placeholder, .loading, .failed:
            result = placeholder(label: imageLabel, font: font)
        }
        let range = NSRange(location: 0, length: result.length)
        result.addAttributes([.font: font,
                              .foregroundColor: image.link == nil ? UIColor.label : UIColor.link], range: range)
        if let link = image.link { result.addAttribute(.link, value: link, range: range) }
        return result
    }

    private func placeholder(label: String, font: UIFont) -> NSMutableAttributedString {
        let attachment = NSTextAttachment()
        if let symbol = phase.placeholderSymbolName {
            attachment.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(font: font))?
                .withTintColor(image.link == nil ? .label : .link, renderingMode: .alwaysOriginal)
        }
        let result = NSMutableAttributedString(attachment: attachment)
        result.append(NSAttributedString(string: " " + label))
        return result
    }
}
#endif
