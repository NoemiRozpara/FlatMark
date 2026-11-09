import Foundation
import SnapshotTesting
import Testing

#if os(macOS)
    import AppKit
#elseif os(iOS)
    import UIKit
#endif

// MARK: - FlatMarkSnapshotSuite

/// The baseline namespace one suite owns: `Tests/References/Snapshots/<suite>/<platform>/`.
///
/// A suite name is used by exactly one file, so recording that suite can never overwrite another
/// suite's references.
enum FlatMarkSnapshotSuite: String {
    case omissionSpacing = "OmissionSpacing"
    case tables = "Tables"
    case imagePhases = "ImagePhases"
    case policyTransitions = "PolicyTransitions"
    case emptyStructures = "EmptyStructures"
    case recipe = "Recipe"
}

// MARK: - FlatMarkSnapshotMode

/// Whether this run records baselines or only verifies against them.
enum FlatMarkSnapshotMode: Equatable {
    case record
    case verify

    /// Explicit recording is opt-in: `FLATMARK_SNAPSHOT_RECORD=all`.
    ///
    /// Every other setting verifies, and verify mode never writes a reference, so a normal or CI run
    /// cannot quietly bless new output. An unrecognized value is reported instead of being treated as
    /// a recording request.
    static var current: FlatMarkSnapshotMode {
        switch ProcessInfo.processInfo.environment["FLATMARK_SNAPSHOT_RECORD"]?.lowercased() {
        case nil, "", "never":
            return .verify
        case "all":
            return .record
        case let unexpected?:
            Issue.record("""
                Unknown FLATMARK_SNAPSHOT_RECORD value '\(unexpected)'. \
                Use 'all' to record, or leave it unset to verify without recording.
                """)
            return .verify
        }
    }
}

// MARK: - assertFlatMarkSnapshot

/// Compares one mounted capture against its reference, or writes it in explicit record mode.
///
/// Verify mode asks SnapshotTesting for `.never`, so a missing reference fails instead of recording
/// and only an explicit recording run can change a baseline. Comparison demands an exact pixel match:
/// no tolerance is applied without a reviewed reason. A failure reports the environment the capture
/// was produced in and the paths of the actual, reference, and diff images.
func assertFlatMarkSnapshot(
    _ image: FlatMarkSnapshotImage,
    suite: FlatMarkSnapshotSuite,
    named name: String,
    environment: FlatMarkSnapshotEnvironment,
    mode: FlatMarkSnapshotMode = .current,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    let failure = verifySnapshot(
        of: image,
        as: imageSnapshotting(environment: environment),
        named: "\(name)-\(environment.fileComponent)",
        record: mode == .record ? .all : .never,
        snapshotDirectory: referenceDirectory(suite: suite, testFile: "\(filePath)"),
        fileID: fileID,
        file: filePath,
        testName: testName,
        line: line,
        column: column
    )

    guard let failure else { return }
    Issue.record(Comment(rawValue: """
        Snapshot "\(name)" of \(suite.rawValue) [\((environment.diagnostic))]:
        \(failure)
        """))
}

/// Pixel equality at the environment's declared scale, with SnapshotTesting's reference, actual, and
/// diff images reported on failure.
private func imageSnapshotting(
    environment: FlatMarkSnapshotEnvironment
) -> Snapshotting<FlatMarkSnapshotImage, FlatMarkSnapshotImage> {
    #if os(macOS)
        Snapshotting.image(precision: 1, perceptualPrecision: 1)
    #else
        Snapshotting.image(precision: 1, perceptualPrecision: 1, scale: environment.pixelScale)
    #endif
}

/// `Tests/References/Snapshots/<suite>/<platform>`, beside the reviewed Recipe Lab captures.
///
/// Snapshot suites live in `Tests/FlatMarkTests/Snapshots/`, three levels below `Tests`.
private func referenceDirectory(suite: FlatMarkSnapshotSuite, testFile: String) -> String {
    URL(fileURLWithPath: testFile, isDirectory: false)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("References", isDirectory: true)
        .appendingPathComponent("Snapshots", isDirectory: true)
        .appendingPathComponent(suite.rawValue, isDirectory: true)
        .appendingPathComponent(platformName, isDirectory: true)
        .path
}

private var platformName: String {
    #if os(macOS)
        "macOS"
    #else
        "iOS"
    #endif
}
