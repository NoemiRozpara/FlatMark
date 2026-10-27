import FlatMark
import FlatMarkFixtures
import SwiftUI

/// Host that presents the shared backend-free fixture without any call-site overrides,
/// so runtime observations isolate FlatMark itself from a host app's environment.
/// On iOS, `scripts/run-fixture-host.sh` builds, bundles, installs, and launches it.
@main
struct FlatMarkFixtureHost: App {
    @State private var model: FlatMarkCustomFixtureModel
    @State private var documentModel: FlatMarkDocumentFixtureModel

    init() {
        let model = FlatMarkCustomFixtureModel()
        model.policyKind = .custom
        model.showsButtons = true
        model.replacementLabel = "Go"
        model.enlargedText = true
        _model = State(initialValue: model)
        _documentModel = State(initialValue: FlatMarkDocumentFixtureModel())
    }

    var body: some Scene {
        WindowGroup {
            ScrollView {
                if CommandLine.arguments.contains("--mentions") {
                    FlatMarkMentionFixture()
                } else if CommandLine.arguments.contains("--document") {
                    FlatMarkDocumentFixture(model: documentModel)
                } else {
                    FlatMarkCustomFixture(model: model)
                }
            }
        }
    }
}
