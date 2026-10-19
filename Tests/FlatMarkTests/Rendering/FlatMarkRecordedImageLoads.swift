import Foundation

/// Records every URL the fixture's image loader receives. Shared so every backend-free fixture
/// can count loads without one fixture depending on another fixture's internals.
@MainActor
@Observable
final class FlatMarkRecordedImageLoads {
    private(set) var urls: [URL] = []

    func record(_ url: URL) {
        urls.append(url)
    }
}
