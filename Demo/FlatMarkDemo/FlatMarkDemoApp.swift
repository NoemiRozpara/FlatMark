import FlatMark
import SwiftUI

/// Host that presents the shared backend-free fixture without any call-site overrides, so runtime
/// observations isolate FlatMark itself from a host app's environment. The fixture is one page
/// holding every document the runtime checks need; `--capture <preset>` selects its initial settings.
/// Open Demo/FlatMarkDemo.xcodeproj or use `scripts/run-fixture-host.sh` to launch it.
@main
struct FlatMarkDemoApp: App {
    @State private var model: FlatMarkCustomFixtureModel

    init() {
        let model = FlatMarkCustomFixtureModel()
        let arguments = CommandLine.arguments
        let captureIndex = arguments.firstIndex(of: "--capture")
        let capture = captureIndex.flatMap { index in
            arguments.indices.contains(index + 1) ? FlatMarkRecipeCapture(rawValue: arguments[index + 1]) : nil
        } ?? .daylight
        capture.apply(to: model)
        _model = State(initialValue: model)
    }

    var body: some Scene {
        WindowGroup {
            ScrollView {
                FlatMarkCustomFixture(model: model)
            }
            #if os(macOS)
            // A ScrollView proposes an unbounded ideal width, so AppKit recomputes the window width
            // from it and discards any width set from outside the app. A fixed bound is what makes
            // the width settable. Keep `maximumWindowWidth` at or above the widest width
            // scripts/capture-recipe-lab.sh sweeps, or the sweep silently cannot reach it.
            .frame(minWidth: Self.minimumWindowWidth,
                   idealWidth: Self.preferredWindowWidth,
                   maxWidth: Self.maximumWindowWidth)
            #endif
        }
        #if os(macOS)
        // Default resizability ties the window to the content's ideal size, so no width set from
        // outside is applied. Let the window grow past the content ideal up to the frame's fixed
        // maximum so the harness can drive width externally.
        .windowResizability(.contentMinSize)
        #endif
    }

    /// macOS window bounds that make the window width settable; see the note in `body`. Between
    /// `minimumWindowWidth` and `maximumWindowWidth` the content fills the window, so window width
    /// drives the recipe layout. Outside that range the content stops following the window.
    private static let minimumWindowWidth: CGFloat = 320
    private static let preferredWindowWidth: CGFloat = 900
    private static let maximumWindowWidth: CGFloat = 1280
}
