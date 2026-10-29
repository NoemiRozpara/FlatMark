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
        }
    }
}
