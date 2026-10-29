import SwiftUI

/// The passive visual used for checked and unchecked task-list markers.
///
/// Appearance does not enable editing. FlatMark owns interaction, accessibility, and hit targets;
/// supply only a drawing, not a button, toggle, or gesture. The visual inherits the environment,
/// including disabled state, and is not exposed as a separate accessibility element.
public struct FlatMarkTaskMarker {
    private let render: ((Bool) -> AnyView)?

    /// Uses FlatMark's built-in square marker on every platform.
    public static var `default`: Self { Self(render: nil) }

    /// Draws all task markers, including read-only and nested tasks, using their checked state.
    public static func custom<Marker: View>(
        @ContentBuilder _ render: @escaping (Bool) -> Marker
    ) -> Self {
        Self(render: { AnyView(render($0)) })
    }

    @MainActor
    @ContentBuilder
    func view(isChecked: Bool) -> some View {
        if let render {
            render(isChecked)
        } else {
            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                .font(.body)
                .foregroundStyle(isChecked ? .green : .secondary)
        }
    }
}
