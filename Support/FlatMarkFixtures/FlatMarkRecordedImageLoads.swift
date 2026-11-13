import Foundation
import Observation

/// Records every URL the fixture's image loader receives. Shared so every backend-free fixture
/// can count loads without one fixture depending on another fixture's internals.
@MainActor
@Observable
public final class FlatMarkRecordedImageLoads {
    public private(set) var urls: [URL] = []

    public init() {}

    public func record(_ url: URL) {
        urls.append(url)
    }
}
