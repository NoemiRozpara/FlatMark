#if os(macOS)
    import AppKit

    enum MountedTextObservationError: Error, Equatable {
        case selectionUnavailable
        case selectionExportFailed(String)
        case wordingNotFound(expected: String, observed: String)
        case wordingMismatch(expected: String, observed: String)
    }

    /// Reads the mounted renderer's native selection backing, not its accessibility representation.
    /// SwiftUI's descendant structure is not a public contract: missing capability must fail loudly.
    @MainActor
    func selectedText(in view: NSView) throws -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        var foundSelection = false

        func collect(from view: NSView) throws {
            // Older SwiftUI SDKs use selectable text fields instead of selection requestors.
            // Activate their AppKit field editor before using the same native RTF export.
            if let field = view as? NSTextField, field.isSelectable {
                field.selectText(nil)
                guard let editor = field.currentEditor() else {
                    throw MountedTextObservationError.selectionUnavailable
                }
                defer { field.window?.makeFirstResponder(nil) }
                try collect(from: editor)
                return
            }
            let select = #selector(NSText.selectAll(_:))
            let write = #selector(NSServicesMenuRequestor.writeSelection(to:types:))
            if view.responds(to: select), view.responds(to: write) {
                // NSTextView exposes selection export without declaring this optional protocol.
                let export: (NSPasteboard) -> Bool
                if let textView = view as? NSTextView {
                    export = { board in
                        // AppKit advertises legacy pasteboard names, not the equivalent UTI.
                        return textView.writeSelection(to: board, types: textView.writablePasteboardTypes)
                    }
                } else if let requestor = view as? any NSServicesMenuRequestor {
                    export = { requestor.writeSelection?(to: $0, types: [.rtf, .string]) == true }
                } else {
                    throw MountedTextObservationError.selectionExportFailed(
                        "Selection view does not conform to NSServicesMenuRequestor: \(type(of: view))"
                    )
                }
                if let textView = view as? NSTextView {
                    textView.selectAll(nil)
                } else {
                    view.perform(select, with: nil)
                }
                // Never touch the user's general pasteboard, and release this board after each read.
                let pasteboard = NSPasteboard.withUniqueName()
                defer { pasteboard.releaseGlobally() }
                guard export(pasteboard),
                      let data = pasteboard.data(forType: .rtf),
                      let text = NSAttributedString(rtf: data, documentAttributes: nil) else {
                    // A region displaying nothing has no selection to export, and omission leaves
                    // such a region behind on purpose: an emptied list row, item, or cell keeps its
                    // slot. Report that as blank wording. A collapsed SwiftUI region reports zero
                    // width; a native text view keeps the width it was offered even when its storage
                    // is empty, so an empty string is the equivalent signal there. A region that
                    // takes space, carries wording, and still refuses to export is a broken lane.
                    let isBlankRegion = view.frame.width == 0
                        || ((view as? NSTextView).map { $0.string.isEmpty } ?? false)
                    guard isBlankRegion else {
                        throw MountedTextObservationError.selectionExportFailed(
                            "Selection view did not export decodable RTF: \(type(of: view)) frame: \(view.frame)"
                        )
                    }
                    foundSelection = true
                    return
                }
                result.append(text)
                foundSelection = true
                // Do not also read descendants of a requestor and duplicate its selection.
                return
            }
            for child in view.subviews {
                try collect(from: child)
            }
        }

        try collect(from: view)
        guard foundSelection else {
            throw MountedTextObservationError.selectionUnavailable
        }
        return result
    }
#endif
