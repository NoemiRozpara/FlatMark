import FlatMark
import Foundation
import SwiftUI
import Testing

#if SWIFT_PACKAGE
    @testable import FlatMarkFixtures
#endif

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Static presentation uses the same document as Recipe Lab. Controlled transitions and internal
/// layout probes remain in their focused suites.
@Suite(.serialized)
@MainActor
struct FlatMarkRecipeIntegrationSnapshotTests {
    enum Scenario: String, CaseIterable {
        case primary, dark, narrow, rtlNarrow, rtlWide
        case omission, readOnly, disabled
        case noLoaderNarrow, noLoaderWide
        #if os(iOS)
        case enlarged, enlargedRTL, enlargedNoLoaderNarrow, enlargedNoLoaderWide
        #endif

        var source: (markdown: String, imageCount: Int) {
            switch self {
            case .primary, .dark:
                return (FlatMarkRecipeSample.markdown, 3)
            case .narrow, .rtlNarrow, .rtlWide:
                return ([FlatMarkRecipeSample.bakeAlong, FlatMarkRecipeSample.method].joined(separator: "\n\n"), 0)
            case .readOnly, .disabled:
                return (FlatMarkRecipeSample.bakeAlong, 0)
            case .omission:
                return ([FlatMarkRecipeSample.dimpling, FlatMarkRecipeSample.bakeAlong, FlatMarkRecipeSample.notes]
                    .joined(separator: "\n\n"), 2)
            case .noLoaderNarrow, .noLoaderWide:
                return ([FlatMarkRecipeSample.photo, FlatMarkRecipeSample.dimpling, FlatMarkRecipeSample.notes]
                    .joined(separator: "\n\n"), 3)
            #if os(iOS)
            case .enlarged, .enlargedRTL:
                return ([FlatMarkRecipeSample.bakeAlong, FlatMarkRecipeSample.method].joined(separator: "\n\n"), 0)
            case .enlargedNoLoaderNarrow, .enlargedNoLoaderWide:
                return ([FlatMarkRecipeSample.photo, FlatMarkRecipeSample.dimpling, FlatMarkRecipeSample.notes]
                    .joined(separator: "\n\n"), 3)
            #endif
            }
        }

        var enlarged: Bool { rawValue.hasPrefix("enlarged") }
        var disabled: Bool { self == .disabled }
        var noLoader: Bool { rawValue.lowercased().contains("noloader") }
        var column: CGFloat {
            if noLoader { return rawValue.hasSuffix("Narrow") ? 160 : 320 }
            if self == .narrow || self == .rtlNarrow || enlarged {
                return 240
            }
            return 560
        }
        var direction: FlatMarkSnapshotEnvironment.LayoutDirection {
            self == .rtlNarrow || self == .rtlWide || rawValue == "enlargedRTL"
                ? .rightToLeft : .leftToRight
        }
    }

    @Test(arguments: Scenario.allCases)
    func recipe(scenario: Scenario) async throws {
        let source = scenario.source
        let model = FlatMarkCustomFixtureModel(markdown: source.markdown)
        let expectedLoads = scenario.noLoader ? 0 : source.imageCount
        model.loadsImages = !scenario.noLoader
        model.policyKind = scenario == .omission ? .omit : .literal
        model.allowsTaskEditing = scenario != .readOnly
        let environment = FlatMarkSnapshotEnvironment(
            captureSize: CGSize(width: scenario.column + 80, height: scenario.enlarged ? 1800 : 1200),
            columnWidth: scenario.column, contentInset: 40, pixelScale: 2,
            appearance: scenario == .dark ? .dark : .light, localeIdentifier: "en_US",
            layoutDirection: scenario.direction, textSize: scenario.enlarged ? .enlarged : .body
        )
        let geometry = Geometry()
        let host = flatMakeRetainedSnapshotHost(
            view: ScrollView(.vertical) {
                FlatMarkCustomDocumentFixture(model: model)
                    .disabled(scenario.disabled)
                    .fixedSize(horizontal: false, vertical: true)
            }.scrollIndicators(.hidden),
            environment: environment
        )
        defer { host.close() }

        // Walk the mounted document rather than cropping fixed section coordinates. The final
        // viewport ends at the actual content bottom, even after source or text-size changes.
        var page = 0
        repeat {
            let image = try await host.capture { [page] root in
                await Self.prepare(root, page: page, model: model, expectedLoads: expectedLoads, geometry: geometry)
            }
            guard geometry.ready else { throw CaptureError.readiness }
            assertFlatMarkSnapshot(image, suite: .recipe, named: "\(scenario.rawValue)-page\(page + 1)",
                                   environment: environment, testName: #function)
            page += 1
        } while geometry.offset < max(0, geometry.content - geometry.viewport) - 1
        #expect(abs(geometry.offset - max(0, geometry.content - geometry.viewport)) < 1)
        #expect(model.imageCalls.urls.count == expectedLoads, "Scrolling must not reload images")
    }

    private enum CaptureError: Error { case readiness }

    private final class Geometry {
        var content: CGFloat = 0
        var viewport: CGFloat = 0
        var offset: CGFloat = 0
        var ready = false
    }

    private static func prepare(
        _ root: FlatMarkSnapshotNativeView, page: Int,
        model: FlatMarkCustomFixtureModel, expectedLoads: Int, geometry: Geometry
    ) async {
        geometry.ready = false
        var previous: [CGRect] = []
        var stable = 0
        for _ in 1 ... 100 {
            #if os(macOS)
                root.layoutSubtreeIfNeeded()
                root.displayIfNeeded()
                guard let scroll = descendants(root).compactMap({ $0 as? NSScrollView }).first,
                      let document = scroll.documentView else {
                    Issue.record("Recipe vertical scroll view unavailable")
                    return
                }
                geometry.content = document.bounds.height
                geometry.viewport = scroll.contentView.bounds.height
                let target = min(CGFloat(page) * geometry.viewport, max(0, geometry.content - geometry.viewport))
                scroll.contentView.scroll(to: CGPoint(x: 0, y: target))
                scroll.reflectScrolledClipView(scroll.contentView)
                geometry.offset = scroll.contentView.bounds.minY
                root.layoutSubtreeIfNeeded()
                root.displayIfNeeded()
            #else
                root.layoutIfNeeded()
                guard let scroll = descendants(root).compactMap({ $0 as? UIScrollView }).first else {
                    Issue.record("Recipe vertical scroll view unavailable")
                    return
                }
                geometry.content = scroll.contentSize.height
                geometry.viewport = scroll.bounds.height
                let target = min(CGFloat(page) * geometry.viewport, max(0, geometry.content - geometry.viewport))
                scroll.setContentOffset(CGPoint(x: 0, y: target), animated: false)
                geometry.offset = scroll.contentOffset.y
                root.layoutIfNeeded()
            #endif
            let observed = descendants(root).map { $0.convert($0.bounds, to: nil) }
            let requested = model.imageCalls.urls.count == expectedLoads
            let positioned = abs(geometry.offset - target) < 1 && geometry.viewport > 0 && geometry.content > 0
            stable = requested && positioned && observed == previous ? stable + 1 : 0
            if stable >= 5 {
                geometry.ready = true
                return
            }
            previous = observed
            try? await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("Recipe page \(page + 1) readiness timed out: loads=\(model.imageCalls.urls.count), stable=\(stable), content=\(geometry.content), viewport=\(geometry.viewport), offset=\(geometry.offset)")
    }

    private static func descendants(_ view: FlatMarkSnapshotNativeView) -> [FlatMarkSnapshotNativeView] {
        [view] + view.subviews.flatMap { descendants($0) }
    }
}
