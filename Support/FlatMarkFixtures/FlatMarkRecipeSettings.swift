import FlatMark
import SwiftUI

/// Exploration controls shown before the shared recipe.
struct FlatMarkRecipeSettings: View {
    @Bindable var model: FlatMarkCustomFixtureModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Appearance") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Load bundled images", isOn: $model.loadsImages)
                    Toggle("Dark mode", isOn: $model.darkAppearance)
                    Toggle("Larger recipe text", isOn: $model.enlargedText)
                    Toggle("Right-to-left recipe layout", isOn: $model.rightToLeft)
                    Text("iOS keeps the narrow 240-point reading column; resize the macOS window to widen it.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            GroupBox("Checklist behavior") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Use custom checkmarks", isOn: $model.usesHostTaskMarker)
                    Toggle("Allow ticking tasks", isOn: $model.allowsTaskEditing)
                    Text("Turn off task editing for a read-only checklist. Recipe links stay active.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            GroupBox("HTML handling") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Compare the HTML in the recipe below.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Picker("HTML handling", selection: $model.policyKind) {
                        Text("Show HTML (default)").tag(FlatMarkUnsupportedContentPolicy.literal)
                        Text("Hide HTML").tag(FlatMarkUnsupportedContentPolicy.omit)
                    }
                    Text("Show HTML keeps the source visible. Hide HTML removes unsupported markup, keeping supported recipe text.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            GroupBox("Notebook rendering") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Use retained document", isOn: $model.usesRetainedDocument)
                    Button("Re-render without editing") { model.refreshRequests += 1 }
                    Button("Add a tasting note") {
                        model.markdown += "\n\n- [ ] Try a new topping next Sunday"
                    }
                    Text("Refresh requests: \(model.refreshRequests)")
                    Text("Switch initializer without changing the recipe. Ticking tasks or adding a note updates the retained snapshot.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            GroupBox("Capture presets & diagnostics") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Presets reset the recipe, the display settings, and the interaction counts. They are for repeating a visual check, not steps in the recipe.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Menu("Apply a capture preset", systemImage: "camera") {
                        ForEach(FlatMarkRecipeCapture.allCases) { capture in
                            Button(capture.rawValue) { capture.apply(to: model) }
                        }
                    }
                    Text("Task updates: \(model.taskUpdates) · Link activations: \(model.linkActivations)")
                    Text("Local image loads this session: \(model.imageCalls.urls.count)")
                }
                .padding(.top)
            }
        }
    }
}
