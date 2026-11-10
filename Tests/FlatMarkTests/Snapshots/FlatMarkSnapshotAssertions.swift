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
    case inlineFlow = "InlineFlow"
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
/// was produced in and the paths of the actual, reference, and diff images; a missing reference also
/// reports the full path of the reference it expected.
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
    let snapshotting = imageSnapshotting(environment: environment)
    let reference = FlatMarkSnapshotReference(
        suite: suite,
        name: name,
        environment: environment,
        testName: testName,
        testFile: "\(filePath)",
        pathExtension: snapshotting.pathExtension
    )
    let failure = verifySnapshot(
        of: image,
        as: snapshotting,
        named: reference.snapshotName,
        record: mode == .record ? .all : .never,
        snapshotDirectory: reference.directory,
        fileID: fileID,
        file: filePath,
        testName: testName,
        line: line,
        column: column
    )

    guard let failure else { return }
    Issue.record(reference.failureComment(failure, mode: mode))
}

// MARK: - FlatMarkSnapshotReference

/// One case's address in the reference tree, and the diagnostics that name it.
///
/// SnapshotTesting builds the reference path from the sanitized test name, a dot, the sanitized
/// `named:` value, and the snapshotting's path extension (`verifySnapshot` in
/// `Sources/SnapshotTesting/AssertSnapshot.swift` at the pinned 1.19.7), and keeps that rule internal.
/// This type mirrors it so a failure can report the path SnapshotTesting really reads, rather than
/// naming files a second way; `FlatMarkSnapshotReferenceTests` fails if the two derivations disagree.
struct FlatMarkSnapshotReference {
    let suite: FlatMarkSnapshotSuite
    /// The case name the test chooses, before the environment fragment.
    let name: String
    let environment: FlatMarkSnapshotEnvironment
    let testName: String
    /// The test file the reference directory hangs off, as `#filePath` reports it.
    let testFile: String
    /// The extension SnapshotTesting appends, taken from the `Snapshotting` used for the comparison.
    let pathExtension: String?

    /// The value passed to `verifySnapshot` as `named:`: the case name plus the environment fragment.
    var snapshotName: String { "\(name)-\(environment.fileComponent)" }

    /// The directory this case's references live in.
    var directory: String { referenceDirectory(suite: suite, testFile: testFile) }

    /// The reference file SnapshotTesting reads for this case.
    var url: URL {
        var url = URL(fileURLWithPath: directory, isDirectory: true)
            .appendingPathComponent(
                "\(sanitizedPathComponent(testName)).\(sanitizedPathComponent(snapshotName))"
            )
        if let pathExtension {
            url = url.appendingPathExtension(pathExtension)
        }
        return url
    }

    /// The report for one `verifySnapshot` failure.
    ///
    /// SnapshotTesting says only that no reference was found, so verify mode adds the full path it
    /// expected. Only SnapshotTesting's own wording may claim a reference is missing: a pixel mismatch
    /// keeps its actual, reference, and diff paths instead of being reported as a missing file.
    func failureComment(_ failure: String, mode: FlatMarkSnapshotMode) -> Comment {
        var message = """
            Snapshot "\(name)" of \(suite.rawValue) [\(environment.diagnostic)]:
            \(failure)
            """
        if mode == .verify, failure.hasPrefix(Self.missingReferenceFailure) {
            message += """

                Expected reference, absent and not written in verify mode:
                \(url.path)
                """
        }
        return Comment(rawValue: message)
    }

    /// The start of SnapshotTesting 1.19.7's message when no reference exists and recording is off.
    static let missingReferenceFailure = "No reference was found on disk."
}

/// SnapshotTesting's component sanitizing, mirrored because the library keeps it internal.
private func sanitizedPathComponent(_ string: String) -> String {
    string
        .replacingOccurrences(of: "\\W+", with: "-", options: .regularExpression)
        .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
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
