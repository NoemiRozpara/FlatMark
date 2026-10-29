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
            let select = #selector(NSText.selectAll(_:))
            let write = #selector(NSServicesMenuRequestor.writeSelection(to:types:))
            if view.responds(to: select), view.responds(to: write) {
                guard let requestor = view as? any NSServicesMenuRequestor else {
                    throw MountedTextObservationError.selectionExportFailed(
                        "Selection view does not conform to NSServicesMenuRequestor: \(type(of: view))"
                    )
                }
                view.perform(select, with: nil)
                // Never touch the user's general pasteboard, and release this board after each read.
                let pasteboard = NSPasteboard.withUniqueName()
                defer { pasteboard.releaseGlobally() }
                guard requestor.writeSelection?(to: pasteboard, types: [.rtf, .string]) == true,
                      let data = pasteboard.data(forType: .rtf),
                      let text = NSAttributedString(rtf: data, documentAttributes: nil) else {
                    // A region displaying nothing has no selection to export, and omission leaves
                    // such a region behind on purpose: an emptied list row, item, or cell keeps its
                    // slot. Report that as blank wording. A region that takes space and still
                    // refuses to export is a broken lane, and must say so.
                    guard view.frame.width == 0 else {
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
