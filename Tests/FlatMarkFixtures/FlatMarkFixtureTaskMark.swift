import SwiftUI

/// A host-owned drawing, with no action, accessibility semantics, or sensory feedback.
struct FlatMarkFixtureTaskMark: View {
    @Environment(\.isEnabled) private var isEnabled
    let isChecked: Bool

    var body: some View {
        Image(systemName: "square")
            .foregroundStyle(.secondary)
            .overlay(alignment: .bottomLeading) {
                if isChecked {
                    Image(systemName: "checkmark")
                        .fontWeight(.bold)
                        .foregroundStyle(.purple)
                        .offset(x: 3, y: -3)
                }
            }
            .font(.title3)
            .opacity(isEnabled ? 1 : 0.5)
    }
}
