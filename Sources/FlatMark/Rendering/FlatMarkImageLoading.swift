import Foundation
import SwiftUI

// MARK: - FlatMarkImageLoader

/// A host-provided asynchronous image source for Markdown images.
///
/// FlatMark never performs network access itself. The loader is invoked only after
/// resolving the source and accepting its URL scheme with ``FlatMarkImageURLPolicy``.
/// Loaded images keep their intrinsic size when it fits. FlatMark scales larger images
/// down to the paragraph's proposed width while preserving their aspect ratio.
public struct FlatMarkImageLoader: Sendable {
    let configurationID: UUID
    let load: @Sendable (URL) async throws -> Image

    /// Creates an image loader with an identity for its current configuration.
    ///
    /// Reuse `configurationID` while reconstructing an equivalent loader. Change it when
    /// the loader's behavior changes and existing image requests should be restarted.
    public init(
        configurationID: UUID,
        load: @escaping @Sendable (URL) async throws -> Image
    ) {
        self.configurationID = configurationID
        self.load = load
    }
}

// MARK: - FlatMarkImageURLPolicy

/// Controls which resolved image URL schemes may be passed to a host image loader.
public struct FlatMarkImageURLPolicy: Sendable {
    public static let webOnly = FlatMarkImageURLPolicy(allowedSchemes: ["http", "https"])

    private let allowedSchemes: Set<String>

    public init(allowedSchemes: Set<String>) {
        self.allowedSchemes = Set(allowedSchemes.map { $0.lowercased() })
    }

    public func allows(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }

        return allowedSchemes.contains(scheme)
    }
}

// MARK: - FlatMarkURLResolver

enum FlatMarkURLResolver {
    static func resolve(_ source: String, relativeTo baseURL: URL?) -> URL? {
        guard !source.isEmpty else {
            return nil
        }
        guard let url = URL(string: source, relativeTo: baseURL)?.absoluteURL,
              url.scheme != nil
        else {
            return nil
        }

        return url
    }
}

// MARK: - FlatMarkImageRequest

enum FlatMarkImageRequest: Equatable, Sendable {
    case unresolved
    case rejected(URL)
    case allowed(URL)

    static func resolve(
        url: URL?,
        policy: FlatMarkImageURLPolicy
    ) -> Self {
        guard let url else {
            return .unresolved
        }

        return policy.allows(url) ? .allowed(url) : .rejected(url)
    }
}
