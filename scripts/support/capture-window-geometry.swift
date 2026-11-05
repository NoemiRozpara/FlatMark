// Print geometry for an on-screen window owned by an app, as tab-separated fields:
//   windowID  pointWidth  pointHeight  backingScale  pixelWidth  pixelHeight
// CGWindowList bounds are points, which is what screencapture -R takes and what decides SwiftUI
// layout. Pixels are points times the backing scale of the screen the window actually sits on, so
// a caller never has to assume a device scale.
//
// Usage: capture-window-geometry <owner-name-substring>
import AppKit
import CoreGraphics

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(
        "usage: capture-window-geometry <owner-name-substring>\n".data(using: .utf8)!)
    exit(2)
}
let needle = CommandLine.arguments[1]

guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                           kCGNullWindowID) as? [[String: Any]] else { exit(1) }
for window in info {
    let owner = (window[kCGWindowOwnerName as String] as? String) ?? ""
    let layer = (window[kCGWindowLayer as String] as? Int) ?? -999
    guard owner.localizedCaseInsensitiveContains(needle), layer == 0,
          let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let windowID = window[kCGWindowNumber as String] as? Int else { continue }
    let x = (bounds["X"] as? Double) ?? 0
    let y = (bounds["Y"] as? Double) ?? 0
    let pointWidth = (bounds["Width"] as? Double) ?? 0
    let pointHeight = (bounds["Height"] as? Double) ?? 0

    // Take the scale from the screen holding the window's centre; a second display can differ
    // from the main one.
    let centre = CGPoint(x: x + pointWidth / 2, y: y + pointHeight / 2)
    var scale = 0.0
    for screen in NSScreen.screens where screen.frame.contains(centre) {
        scale = screen.backingScaleFactor
        break
    }
    if scale == 0, let main = NSScreen.main { scale = main.backingScaleFactor }
    guard scale > 0 else { continue }

    let pw = Int((pointWidth * scale).rounded())
    let ph = Int((pointHeight * scale).rounded())
    print("\(windowID)\t\(Int(pointWidth.rounded()))\t\(Int(pointHeight.rounded()))"
        + "\t\(Int(scale))\t\(pw)\t\(ph)")
    exit(0)
}
exit(1)
