import Foundation
import SwiftUI

// MARK: - FlatMarkSnapshotEnvironment

/// Everything a reviewed image baseline depends on, fixed by the test instead of inherited from the
/// machine that recorded it.
///
/// The same values are spelled into the reference file name, so changing one asks for a newly reviewed
/// baseline rather than comparing fresh output against a reference recorded under other settings.
struct FlatMarkSnapshotEnvironment: Equatable, Sendable {
    /// The capture region in points, larger than the column it carries. Ink that reaches an edge is
    /// then a clipped drawing instead of a correctly fitted one.
    let captureSize: CGSize
    /// The reading column offered to the document.
    let columnWidth: CGFloat
    /// The gap between the column and the capture edge, so ink flush with an edge always means
    /// clipping rather than a column that starts at the edge.
    let contentInset: CGFloat
    /// Device pixels per point. A capture that comes back at any other scale fails.
    let pixelScale: CGFloat
    let appearance: Appearance
    let localeIdentifier: String
    let layoutDirection: LayoutDirection
    let textSize: TextSize

    /// The one environment recorded so far: a 240-point column inside a 320-point capture at 2x,
    /// light, English, left to right, at the platform's body text size.
    static let standard = FlatMarkSnapshotEnvironment(
        captureSize: CGSize(width: 320, height: 300),
        columnWidth: 240,
        contentInset: 20,
        pixelScale: 2,
        appearance: .light,
        localeIdentifier: "en_US",
        layoutDirection: .leftToRight,
        textSize: .body
    )

    /// The reference-file fragment for these settings, for example
    /// `240col-20inset-320x300-2x-light-en_US-ltr-body`.
    var fileComponent: String {
        [
            "\(Int(columnWidth))col",
            "\(Int(contentInset))inset",
            "\(Int(captureSize.width))x\(Int(captureSize.height))",
            "\(Int(pixelScale))x",
            appearance.rawValue,
            localeIdentifier,
            layoutDirection.fileComponent,
            textSize.name,
        ].joined(separator: "-")
    }

    /// The capture's own description, reported with every comparison and readiness failure.
    var diagnostic: String {
        """
        \(Int(captureSize.width))x\(Int(captureSize.height))pt@\(Int(pixelScale))x, \
        \(Int(columnWidth))pt column with \(Int(contentInset))pt inset, \(appearance.rawValue), \
        locale \(localeIdentifier), \(layoutDirection.fileComponent), \(textSize.name) text \
        (\(textSize.effectiveSizeDescription))
        """
    }

    /// The document at the environment's column inside its capture region.
    ///
    /// The outer frame is the capture size rather than the size the content would choose for itself:
    /// a container that shrinks to its own drawing clips an overflowing line into exactly the shape a
    /// test looking for overflow would read as correct.
    @MainActor
    func pinnedContent<V: View>(_ view: V) -> some View {
        applyEffectiveTextSize(
            view
                .environment(\.locale, Locale(identifier: localeIdentifier))
                .environment(\.layoutDirection, layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight)
                .environment(\.colorScheme, appearance == .dark ? .dark : .light)
                .environment(\.dynamicTypeSize, textSize.dynamicTypeSize)
        )
        .frame(width: columnWidth, alignment: .leading)
        .padding(contentInset)
        .frame(width: captureSize.width, height: captureSize.height, alignment: .topLeading)
        .background(appearance == .dark ? Color.black : Color.white)
    }

    /// Pins the environment's effective text size without pinning it where that would hide Dynamic Type.
    ///
    /// On iOS a case that sets `usesDynamicTypeOniOS` keeps the inherited semantic font and lets
    /// `dynamicTypeSize` drive the glyphs, so iOS enlarged text runs the real Dynamic Type path; a case
    /// that keeps the absolute size (the body control) reproduces the platform body rendering it was
    /// recorded against.
    ///
    /// The override is ambient. On macOS FlatMark's paragraph, heading, literal, and code-block text
    /// resolve AppKit role fonts and ignore it, which the enlarged linked-flow check in
    /// `FlatMarkImageLoadingTests` asserts; only content FlatMark draws with plain SwiftUI `Text`, such
    /// as list markers, follows it. Every enlarged scenario is therefore recorded on iOS only.
    @ViewBuilder
    private func applyEffectiveTextSize<V: View>(_ view: V) -> some View {
        #if os(macOS)
            view.font(.system(size: textSize.fontSize))
        #else
            if textSize.usesDynamicTypeOniOS {
                view
            } else {
                view.font(.system(size: textSize.fontSize))
            }
        #endif
    }
}

// MARK: - FlatMarkSnapshotEnvironment.Appearance

extension FlatMarkSnapshotEnvironment {
    /// The appearance a capture is reviewed in.
    enum Appearance: String, Sendable {
        case light
        case dark
    }
}

// MARK: - FlatMarkSnapshotEnvironment.LayoutDirection

extension FlatMarkSnapshotEnvironment {
    /// The layout direction a capture is reviewed in.
    enum LayoutDirection: String, Sendable {
        case leftToRight
        case rightToLeft

        var fileComponent: String {
            switch self {
            case .leftToRight: "ltr"
            case .rightToLeft: "rtl"
            }
        }
    }
}

// MARK: - FlatMarkSnapshotEnvironment.TextSize

extension FlatMarkSnapshotEnvironment {
    /// An effective mounted text size.
    ///
    /// On iOS `dynamicTypeSize` is the real Dynamic Type path. On macOS the font-size override does not
    /// reach FlatMark's native text, whose roles resolve AppKit fonts, so enlarged cases run on iOS
    /// only. Neither path is system Dynamic Type, VoiceOver, or readability verification, and a suite
    /// that records enlarged text still has to show the rendering changed.
    struct TextSize: Equatable, Sendable {
        let name: String
        let dynamicTypeSize: DynamicTypeSize
        let fontSize: CGFloat
        /// Whether iOS drives the glyphs from `dynamicTypeSize` instead of pinning `fontSize`.
        ///
        /// When true the capture keeps the inherited semantic font, so the case exercises the real
        /// Dynamic Type path on iOS. When false iOS pins `fontSize` absolutely, which reproduces the
        /// platform body rendering a reference was recorded against. macOS ignores this: its FlatMark
        /// text resolves AppKit role fonts, so enlarged cases are recorded on iOS only.
        let usesDynamicTypeOniOS: Bool

        /// How the effective size is actually produced, worded so a failure never calls a macOS
        /// absolute override a Dynamic Type result.
        var effectiveSizeDescription: String {
            #if os(macOS)
                "\(Int(fontSize))pt ambient override, dynamic type \(dynamicTypeSize): "
                    + "AppKit role fonts size FlatMark text"
            #else
                if usesDynamicTypeOniOS {
                    "real Dynamic Type \(dynamicTypeSize)"
                } else {
                    "\(Int(fontSize))pt font override, dynamic type \(dynamicTypeSize)"
                }
            #endif
        }
    }
}

extension FlatMarkSnapshotEnvironment.TextSize {
    /// The platform's own body text: 13pt on macOS and 17pt on iOS, at standard Dynamic Type.
    static var body: FlatMarkSnapshotEnvironment.TextSize {
        #if os(macOS)
            FlatMarkSnapshotEnvironment.TextSize(
                name: "body", dynamicTypeSize: .large, fontSize: 13, usesDynamicTypeOniOS: false
            )
        #else
            FlatMarkSnapshotEnvironment.TextSize(
                name: "body", dynamicTypeSize: .large, fontSize: 17, usesDynamicTypeOniOS: false
            )
        #endif
    }

    /// A deliberately large effective size for wrapping and overflow cases.
    static var enlarged: FlatMarkSnapshotEnvironment.TextSize {
        FlatMarkSnapshotEnvironment.TextSize(
            name: "accessibility5", dynamicTypeSize: .accessibility5, fontSize: 28, usesDynamicTypeOniOS: true
        )
    }
}
