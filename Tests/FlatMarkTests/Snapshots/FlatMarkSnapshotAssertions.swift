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
/// Only an explicit recording run can change a baseline, and comparison demands an exact pixel match:
/// no tolerance is applied without a reviewed reason. A failure reports the environment the capture was
/// produced in, the paths of the comparison images, and, when the reference is missing, the full path it
/// expected. Failures are reported at the call site, so the test that asked for the capture is the one
/// named.
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
    let failure = reference.verifyingWithoutLeftoverDirectories(mode: mode) {
        verifySnapshot(
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
    }

    guard let failure else { return }
    Issue.record(
        reference.failureComment(failure, mode: mode),
        sourceLocation: SourceLocation(
            fileID: fileID.description,
            filePath: filePath.description,
            line: Int(line),
            column: Int(column)
        )
    )
}

// MARK: - FlatMarkSnapshotReference

/// One case's address in the reference tree: the diagnostics that name it, and the cleanup that keeps a
/// verify run from leaving a directory behind.
///
/// SnapshotTesting builds the reference path from the test name, the `named:` value, and the
/// snapshotting's path extension, and keeps that rule internal. This type mirrors it so a failure can
/// report the path SnapshotTesting really reads; `FlatMarkSnapshotReferenceTests` fails if the two
/// derivations disagree.
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

    /// The directories `verifySnapshot` may create for this case, deepest first. These are the only
    /// cleanup candidates, so a verify run never reaches outside this case's suite namespace.
    var directoriesWithinNamespace: [URL] {
        let leaf = URL(fileURLWithPath: directory, isDirectory: true)
        return [leaf, leaf.deletingLastPathComponent()]
    }

    /// Runs one `verifySnapshot` call for this case, leaving no directory the run created.
    ///
    /// SnapshotTesting creates the reference directory before it checks whether a reference exists, so a
    /// verify run against a removed namespace would otherwise leave an empty directory beside the
    /// reviewed baselines. Directories absent before the run are removed afterwards while they are still
    /// empty, deepest first; a removal that fails leaves a harmless empty directory. Record mode is left
    /// alone because creating the namespace is what recording is for.
    func verifyingWithoutLeftoverDirectories(
        mode: FlatMarkSnapshotMode,
        _ verifyRun: () -> String?
    ) -> String? {
        guard mode == .verify else { return verifyRun() }

        let fileManager = FileManager.default
        let absentBeforeRun = directoriesWithinNamespace.filter {
            !fileManager.fileExists(atPath: $0.path)
        }

        let failure = verifyRun()

        for directory in absentBeforeRun where isEmptyDirectory(directory) {
            try? fileManager.removeItem(at: directory)
        }
        return failure
    }

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

    /// The report for one `verifySnapshot` failure. A pixel mismatch keeps SnapshotTesting's own
    /// wording, with its actual, reference, and diff paths; a missing reference in verify mode adds the
    /// full path it expected.
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

    /// The opening of SnapshotTesting's message when no reference exists and recording is off, matched
    /// by prefix.
    static let missingReferenceFailure = "No reference was found on disk."
}

/// Mirrors SnapshotTesting's internal component sanitizing.
private func sanitizedPathComponent(_ string: String) -> String {
    string
        .replacingOccurrences(of: "\\W+", with: "-", options: .regularExpression)
        .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
}

/// Whether `url` is a directory with no entries. An absent or unreadable path is not empty, so the
/// caller only removes a directory it confirmed empty.
private func isEmptyDirectory(_ url: URL) -> Bool {
    guard let entries = try? FileManager.default.contentsOfDirectory(atPath: url.path) else {
        return false
    }
    return entries.isEmpty
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
