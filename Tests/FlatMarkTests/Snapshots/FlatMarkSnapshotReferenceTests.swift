import Foundation
import SnapshotTesting
import Testing

// MARK: - FlatMarkSnapshotReferenceTests

/// Guards the missing-reference diagnostic against the path rule SnapshotTesting keeps internal.
///
/// `FlatMarkSnapshotReference.url` mirrors that rule, so these cases let `verifySnapshot` itself
/// decide whether the path the diagnostic reports is the path it reads. A plain text snapshotter in a
/// throwaway directory is enough: nothing is mounted or captured, and no reviewed baseline is read or
/// written.
struct FlatMarkSnapshotReferenceTests {
    /// The file SnapshotTesting loads is the file the diagnostic reports.
    @Test func verifySnapshotReadsFromTheReportedPath() throws {
        let workspace = SnapshotWorkspace()
        defer { workspace.cleanup() }
        try workspace.placeReference(capturedText)

        #expect(workspace.verify() == nil)
    }

    /// A removed reference fails verify mode, names its full expected path, and stays absent.
    @Test func verifyModeReportsTheMissingReferencePathWithoutWritingIt() throws {
        let workspace = SnapshotWorkspace()
        defer { workspace.cleanup() }

        let failure = try #require(workspace.verify())
        #expect(failure.hasPrefix(FlatMarkSnapshotReference.missingReferenceFailure))
        #expect(!workspace.referenceExists)

        let comment = workspace.reference.failureComment(failure, mode: .verify).rawValue
        #expect(comment.contains(workspace.reference.url.path))
        #expect(comment.contains(FlatMarkSnapshotEnvironment.standard.diagnostic))
    }

    /// A differing capture keeps its comparison diagnostics instead of being called a missing file.
    @Test func aMismatchIsNotReportedAsAMissingReference() throws {
        let workspace = SnapshotWorkspace()
        defer { workspace.cleanup() }
        try workspace.placeReference("an older capture")

        let failure = try #require(workspace.verify())
        #expect(!failure.hasPrefix(FlatMarkSnapshotReference.missingReferenceFailure))
        let comment = workspace.reference.failureComment(failure, mode: .verify).rawValue
        #expect(!comment.contains("Expected reference"))
    }

    /// A verify run against a namespace that was never recorded leaves no directory behind.
    @Test func verifyModeLeavesNoReferenceDirectoryItCreated() throws {
        let workspace = SnapshotWorkspace()
        defer { workspace.cleanup() }
        #expect(!workspace.namespaceExists)

        let failure = try #require(workspace.verify())
        #expect(failure.hasPrefix(FlatMarkSnapshotReference.missingReferenceFailure))
        #expect(!workspace.namespaceExists)
    }

    /// Recording still creates the namespace and writes the reference, so the cleanup stays out of it.
    @Test func recordModeStillCreatesTheReferenceDirectory() throws {
        let workspace = SnapshotWorkspace()
        defer { workspace.cleanup() }

        let failure = try #require(workspace.verify(mode: .record))
        #expect(!failure.hasPrefix(FlatMarkSnapshotReference.missingReferenceFailure))
        #expect(workspace.namespaceExists)
        #expect(workspace.referenceExists)
        #expect(try String(contentsOf: workspace.reference.url, encoding: .utf8) == capturedText)
    }

    /// A recording run keeps a namespace it created even when it wrote no reference, so a recording run
    /// that returned early does not lose the directory recording is meant to make.
    @Test func recordModeKeepsANamespaceThatStaysEmpty() throws {
        let workspace = SnapshotWorkspace()
        defer { workspace.cleanup() }

        #expect(workspace.recordRunThatWroteNothing() == nil)
        #expect(workspace.namespaceExists)
    }
}

// MARK: - SnapshotWorkspace

/// One case in a throwaway reference tree, addressed exactly as `assertFlatMarkSnapshot` addresses a
/// real one.
///
/// `referenceDirectory` walks three levels up from the test file, so the synthetic file sits four
/// levels below the disposable root. `verifySnapshot` takes that directory verbatim, as the assertion
/// helper does, so its own `file:` argument plays no part in the path under test.
private struct SnapshotWorkspace {
    let reference: FlatMarkSnapshotReference
    private let root: URL

    init() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlatMarkSnapshotReference-\(UUID().uuidString)", isDirectory: true)
        self.root = root
        self.reference = FlatMarkSnapshotReference(
            suite: .emptyStructures,
            name: "document",
            environment: .standard,
            testName: "document(scenario:)",
            testFile: root.appendingPathComponent("a/b/c/d/Case.swift").path,
            pathExtension: Snapshotting<String, String>.lines.pathExtension
        )
        // The tree must stay disposable: a derivation that ignored `testFile` would point at the
        // reviewed references instead.
        precondition(
            reference.url.path.hasPrefix(root.path),
            "Workspace reference escaped its temporary root: \(reference.url.path)"
        )
    }

    var referenceExists: Bool { FileManager.default.fileExists(atPath: reference.url.path) }

    /// Whether any directory of this case's suite namespace exists.
    var namespaceExists: Bool {
        reference.directoriesWithinNamespace.contains {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }

    /// Writes a reference at the path the diagnostic reports, as a recording run would have.
    func placeReference(_ text: String) throws {
        try FileManager.default.createDirectory(
            at: reference.url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try text.write(to: reference.url, atomically: true, encoding: .utf8)
    }

    /// Verifies the fixed capture against whatever reference is on disk, through the same cleanup
    /// `assertFlatMarkSnapshot` applies.
    func verify(mode: FlatMarkSnapshotMode = .verify) -> String? {
        reference.verifyingWithoutLeftoverDirectories(mode: mode) {
            verifySnapshot(
                of: capturedText,
                as: .lines,
                named: reference.snapshotName,
                record: mode == .record ? .all : .never,
                snapshotDirectory: reference.directory,
                fileID: #fileID,
                file: #filePath,
                testName: reference.testName
            )
        }
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }

    /// Runs the cleanup as a recording run that created the namespace and then returned without writing
    /// a reference would.
    func recordRunThatWroteNothing() -> String? {
        reference.verifyingWithoutLeftoverDirectories(mode: .record) {
            try? FileManager.default.createDirectory(
                at: URL(fileURLWithPath: reference.directory, isDirectory: true),
                withIntermediateDirectories: true
            )
            return nil
        }
    }
}

/// The capture every workspace case compares against its reference.
private let capturedText = "a captured document"
