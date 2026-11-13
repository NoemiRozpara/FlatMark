import FlatMark
import SwiftUI

/// Presents the shared backend-free fixture without call-site overrides.
/// `--capture <preset>` selects initial settings. Launch with `scripts/run-fixture-host.sh`.
@main
struct FlatMarkDemoApp: App {
    @State private var model: FlatMarkCustomFixtureModel

    init() {
        let model = FlatMarkCustomFixtureModel()
        let arguments = CommandLine.arguments
        let captureIndex = arguments.firstIndex(of: "--capture")
        let capture = captureIndex.flatMap { index in
            arguments.indices.contains(index + 1) ? FlatMarkRecipeCapture(rawValue: arguments[index + 1]) : nil
        } ?? .light
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
