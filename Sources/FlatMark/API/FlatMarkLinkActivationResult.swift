/// The embedding application's synchronous decision for a resolved link activation.
public enum FlatMarkLinkActivationResult: Sendable {
    /// The application handled the destination. FlatMark must not open it.
    case handled
    /// The application rejected the destination. FlatMark must not open it.
    case rejected
    /// Delegate once to the host's inherited SwiftUI URL opener.
    case useDefaultOpening
}
