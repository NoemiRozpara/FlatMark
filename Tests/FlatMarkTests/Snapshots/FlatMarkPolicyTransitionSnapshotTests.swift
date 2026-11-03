import FlatMark
#if canImport(FlatMarkFixtures)
    import FlatMarkFixtures
#endif
import Foundation
import SwiftUI
import Testing

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

@Suite(.serialized)
@MainActor
struct FlatMarkPolicyTransitionSnapshotTests {
    private static let environment = FlatMarkSnapshotEnvironment(
        captureSize: CGSize(width: 640, height: 650), columnWidth: 400, contentInset: 80,
        pixelScale: 2, appearance: .light, localeIdentifier: "en_US",
        layoutDirection: .leftToRight, textSize: .body
    )
    private static let source = """
    Before **bold <u>middle</u> end**.

    <div>whole block</div>

    - [ ] Keep this task unchanged

    ![Striped local diagram](https://example.invalid/local.png)

    After the policies.
    """

    @Test func retainedPolicyTransitions() async throws {
        let model = ControlledModel(markdown: Self.source)
        let host = flatMakeRetainedSnapshotHost(view: ControlledDocument(model: model), environment: Self.environment)
        defer { model.delivery.release(); host.close() }

        // Request start alone deliberately captures loading, not the final raster.
        let loading = try await capture(host, delivery: model.delivery, requiresCompletion: false)
        snapshot(loading, "heldLoading", testName: #function)
        #expect(model.delivery.requests == 1)
        #expect(!model.delivery.completed)

        model.delivery.release()
        let initial = try await capture(host, delivery: model.delivery)
        snapshot(initial, "literal", testName: #function)
        model.policyKind = .custom
        snapshot(try await capture(host, delivery: model.delivery),
                 "custom", testName: #function)
        model.replacementLabel = "Changed replacement"
        snapshot(try await capture(host, delivery: model.delivery),
                 "changedCustom", testName: #function)
        model.policyKind = .omit
        snapshot(try await capture(host, delivery: model.delivery),
                 "omit", testName: #function)
        model.policyKind = .literal
        let restored = try await capture(host, delivery: model.delivery)
        snapshot(restored, "literal", mode: .verify, testName: #function)
        #expect(model.markdown == Self.source)
        #expect(model.delivery.requests == 1)
        #expect(model.delivery.completed)
    }

    @Test func imageDescriptionRestoresWithoutLoader() async throws {
        let source = "Before ![Striped <u>local</u> diagram](https://example.invalid/local.png) after."
        let model = ControlledModel(markdown: source, loadsImages: false)
        let host = flatMakeRetainedSnapshotHost(view: ControlledDocument(model: model), environment: Self.environment)
        defer { host.close() }
        snapshot(try await capture(host), "literal", testName: #function)
        model.policyKind = .omit
        snapshot(try await capture(host), "omit", testName: #function)
        model.policyKind = .literal
        snapshot(try await capture(host),
                 "literal", mode: .verify, testName: #function)
        #expect(model.markdown == source)
        #expect(model.delivery.requests == 0)
    }

    @Test func loadedImageDescriptionDoesNotReload() async throws {
        let source = "Before ![Striped <u>local</u> diagram](https://example.invalid/local.png) after."
        let model = ControlledModel(markdown: source)
        model.delivery.release()
        let host = flatMakeRetainedSnapshotHost(view: ControlledDocument(model: model), environment: Self.environment)
        defer { host.close() }
        snapshot(try await capture(host, delivery: model.delivery),
                 "loaded", testName: #function)
        for policy in [FlatMarkCustomPolicyKind.omit, .literal] {
            model.policyKind = policy
            snapshot(try await capture(host, delivery: model.delivery),
                     "loaded", mode: .verify, testName: #function)
            #expect(model.delivery.requests == 1)
            #expect(model.markdown == source)
        }
    }

    @Test func freshMountsStartNewRequests() async throws {
        let model = ControlledModel(markdown: "![Striped local diagram](https://example.invalid/local.png)")
        model.delivery.release()
        for expected in 1 ... 2 {
            var readinessError: (any Error)?
            let image = try await flatMarkSnapshotImage(
                of: ControlledDocument(model: model), environment: Self.environment,
                prepareMountedView: { root in
                    do {
                        try await ready(root, delivery: model.delivery, expectedRequests: expected)
                    } catch {
                        readinessError = error
                    }
                }
            )
            if let readinessError { throw readinessError }
            snapshot(image, "mount\(expected)", testName: #function)
            #expect(model.delivery.requests == expected)
        }
    }

    @Test(arguments: [false, true]) func bothInitializerPaths(retained: Bool) async throws {
        let source = "Before <u>middle</u> after.\n\n<div>block</div>\n\n- [ ] Task"
        let model = FlatMarkCustomFixtureModel(markdown: source)
        let host = flatMakeRetainedSnapshotHost(
            view: FlatMarkCustomDocumentFixture(model: model, usesRetainedDocument: retained), environment: Self.environment
        )
        defer { host.close() }
        let prefix = retained ? "document" : "source"
        let testName = "bothInitializerPaths"
        snapshot(try await capture(host),
                 "\(prefix)Literal", testName: testName)
        model.policyKind = .custom
        snapshot(try await capture(host),
                 "\(prefix)Custom", testName: testName)
        model.policyKind = .omit
        snapshot(try await capture(host),
                 "\(prefix)Omit", testName: testName)
        model.policyKind = .literal
        snapshot(try await capture(host),
                 "\(prefix)Literal", mode: .verify, testName: testName)
        #expect(model.markdown == source)
        #expect(model.taskUpdates == 0)
    }

    private func capture(
        _ host: FlatMarkRetainedSnapshotHost, delivery: ControlledDelivery? = nil,
        requiresCompletion: Bool = true, expectedRequests: Int = 1
    ) async throws -> FlatMarkSnapshotImage {
        var readinessError: (any Error)?
        let image = try await host.capture(prepareMountedView: { root in
            do {
                try await ready(root, delivery: delivery, requiresCompletion: requiresCompletion,
                                expectedRequests: expectedRequests)
            } catch {
                readinessError = error
            }
        })
        if let readinessError { throw readinessError }
        return image
    }

    private func snapshot(
        _ image: FlatMarkSnapshotImage, _ name: String,
        mode: FlatMarkSnapshotMode = .current, testName: String
    ) {
        assertFlatMarkSnapshot(image, suite: .policyTransitions, named: name,
                               environment: Self.environment, mode: mode, testName: testName)
    }

    // Completion is bookkeeping, not proof of drawing. Stable native geometry bounds settling;
    // reviewed snapshots, including the held-loading control, establish the visible phase.
    private func ready(
        _ root: FlatMarkSnapshotNativeView, delivery: ControlledDelivery? = nil,
        requiresCompletion: Bool = true, expectedRequests: Int = 1
    ) async throws {
        var previous: [CGRect] = []
        var stable = 0
        var history: [String] = []
        for attempt in 1 ... 100 {
            #if os(macOS)
                root.layoutSubtreeIfNeeded()
                root.displayIfNeeded()
            #else
                root.layoutIfNeeded()
            #endif
            let observed = frames(root)
            let gate = delivery.map {
                $0.requests == expectedRequests && (!requiresCompletion || $0.completed)
            } ?? true
            stable = gate && observed == previous ? stable + 1 : 0
            history.append("\(attempt): requests=\(delivery?.requests ?? 0), completed=\(delivery?.completed ?? false), stable=\(stable), frames=\(observed)")
            if stable >= 5 { return }
            previous = observed
            try await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("Policy transition did not settle: \(history); \(Self.environment.diagnostic)")
        throw ReadinessError.timedOut
    }

    private func frames(_ view: FlatMarkSnapshotNativeView) -> [CGRect] {
        [view.convert(view.bounds, to: nil)] + view.subviews.flatMap { frames($0) }
    }

    private enum ReadinessError: Error { case timedOut }
}

// The lock protects bookkeeping shared with the loader's executor.
private final class ControlledDelivery: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var completions = 0
    private var released = false
    var requests: Int { lock.withLock { count } }
    var completed: Bool { lock.withLock { count > 0 && completions == count } }
    func start() { lock.withLock { count += 1 } }
    func complete() { lock.withLock { completions += 1 } }
    func release() { lock.withLock { released = true } }
    func wait() async throws {
        while !lock.withLock({ released }) { try await Task.sleep(for: .milliseconds(20)) }
    }
}

@MainActor
@Observable
private final class ControlledModel {
    let markdown: String
    let delivery = ControlledDelivery()
    let loader: FlatMarkImageLoader?
    var policyKind = FlatMarkCustomPolicyKind.literal
    var replacementLabel = "Replacement"

    init(markdown: String, loadsImages: Bool = true) {
        self.markdown = markdown
        let delivery = delivery
        let raster = Self.raster()
        loader = loadsImages ? FlatMarkImageLoader(configurationID: UUID()) { _ in
            delivery.start()
            defer { delivery.complete() }
            try await delivery.wait()
            // Longer than the five 20ms geometry samples: start-only readiness stays premature.
            try await Task.sleep(for: .seconds(1))
            return raster
        } : nil
    }

    var policy: FlatMarkUnsupportedContentPolicy {
        switch policyKind {
        case .literal: .literal
        case .omit: .omit
        case .custom:
            .custom { [replacementLabel] _ in
                var replacement = AttributedString(replacementLabel)
                replacement.foregroundColor = .indigo
                return replacement
            }
        }
    }

    private static func raster() -> Image {
        let width = 120, height = 60
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let index = (y * width + x) * 4
                bytes[index] = x < width / 2 ? 30 : 240
                bytes[index + 1] = y < height / 2 ? 180 : 70
                bytes[index + 2] = 120
            }
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        return Image(decorative: image, scale: 1)
    }
}

@MainActor
private struct ControlledDocument: View {
    let model: ControlledModel
    var body: some View {
        FlatMarkView(markdown: model.markdown, imageLoader: model.loader, unsupportedContentPolicy: model.policy)
            .fixedSize(horizontal: false, vertical: true)
    }
}
