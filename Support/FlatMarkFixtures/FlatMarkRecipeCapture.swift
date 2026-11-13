import SwiftUI

/// Stable names are also accepted by the host as `--capture <name>`.
/// Presets select display settings and HTML handling for the shared recipe.
/// `generous` is iOS only: AppKit ignores Dynamic Type, so the name is unknown on macOS and the
/// host falls back to `light`.
public enum FlatMarkRecipeCapture: String, CaseIterable, Identifiable {
    case light, dark
    #if !os(macOS)
    case generous
    #endif
    case rightToLeft, hostMarkers, readOnly, omission

    public var id: String { rawValue }

    @MainActor
    public func apply(to model: FlatMarkCustomFixtureModel) {
        model.markdown = FlatMarkCustomFixtureModel.markdown
        model.policyKind = self == .omission ? .omit : .literal
        model.loadsImages = true
        model.usesRetainedDocument = false
        model.refreshRequests = 0
        #if !os(macOS)
        model.enlargedText = self == .generous
        #endif
        model.rightToLeft = self == .rightToLeft
        model.usesHostTaskMarker = self == .hostMarkers
        model.allowsTaskEditing = self != .readOnly
        model.darkAppearance = self == .dark
        model.lastActivity = "Your recipe notes and task confirmations appear here."
        model.linkActivations = 0
        model.taskUpdates = 0
    }
}
