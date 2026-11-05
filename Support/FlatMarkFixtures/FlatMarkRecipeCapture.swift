import SwiftUI

/// Stable names are also accepted by the host as `--capture <name>`.
/// Presets select display settings and HTML handling for the shared recipe.
public enum FlatMarkRecipeCapture: String, CaseIterable, Identifiable {
    case daylight, midnight, generous, rightToLeft, hostMarkers, readOnly, omission

    public var id: String { rawValue }

    @MainActor
    public func apply(to model: FlatMarkCustomFixtureModel) {
        model.markdown = FlatMarkCustomFixtureModel.markdown
        model.policyKind = self == .omission ? .omit : .literal
        model.replacementLabel = "Baker’s tip"
        model.showsButtons = true
        model.showsEmpty = false
        model.detectMentions = true
        model.loadsImages = true
        model.usesRetainedDocument = false
        model.refreshRequests = 0
        model.enlargedText = self == .generous
        model.rightToLeft = self == .rightToLeft
        model.usesHostTaskMarker = self == .hostMarkers
        model.allowsTaskEditing = self != .readOnly
        model.darkAppearance = self == .midnight
        model.lastActivity = "Your recipe notes and task confirmations appear here."
        model.customActivations = 0
        model.linkActivations = 0
        model.taskUpdates = 0
    }
}
