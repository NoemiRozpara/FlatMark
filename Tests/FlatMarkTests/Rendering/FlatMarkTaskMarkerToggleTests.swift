@testable import FlatMark
import Testing

// MARK: - FlatMarkTaskMarkerToggleTests

struct FlatMarkTaskMarkerToggleTests {
    @Test
    func `toggling nested task preserves all authored markdown except one marker state`() throws {
        let markdown = """
        # Plan ✅

        - [ ] Parent with ą Unicode
          - [x] Nested task
            continues on a second line with 你好.
        - [ ] Sibling

        Keep  **this formatting** exactly.
        """
        let address = try #require(taskAddresses(in: markdown).dropFirst().first)
        #expect(address.path == [1, 0, 1, 0])

        let updatedMarkdown = try #require(
            FlatMarkTaskMarkerToggle.toggledMarkdown(in: markdown, sourceRange: address.sourceRange)
        )

        #expect(updatedMarkdown == markdown.replacingFirst("  - [x] Nested task", with: "  - [ ] Nested task"))
    }

    @Test
    func `task toggle accepts checked unchecked and uppercase markers and rejects invalid source positions`() {
        let unchecked = "- [ ] Pending"
        let checked = "- [x] Done"
        let uppercase = "- [X] Also done"

        #expect(toggledMarkdown(in: unchecked) == "- [x] Pending")
        #expect(toggledMarkdown(in: checked) == "- [ ] Done")
        #expect(toggledMarkdown(in: uppercase) == "- [ ] Also done")

        let invalidAddress = FlatMarkSourceRange(
            lowerBound: .init(line: 99, column: 1),
            upperBound: .init(line: 99, column: 2)
        )
        #expect(
            FlatMarkTaskMarkerToggle.toggledMarkdown(in: unchecked, sourceRange: invalidAddress) == nil
        )
    }
}

// MARK: - FlatMarkTaskMarkerToggleNewlineMatrixTests

struct FlatMarkTaskMarkerToggleNewlineMatrixTests {
    @Test(
        "equivalent LF, CRLF, and CR documents toggle the same logical tasks byte for byte",
        arguments: NewlineVariants.all
    )
    func equivalentNewlineVariantsToggleSameLogicalTasks(variant: NewlineVariants.Variant) throws {
        let input = TaskToggleFixture.joined(with: variant.joiner)
        let inputBytes = Array(input.utf8)
        let addresses = taskAddresses(in: input)
        #expect(addresses.count == TaskToggleFixture.tasks.count)

        for (address, task) in zip(addresses, TaskToggleFixture.tasks) {
            let toggled = try #require(
                FlatMarkTaskMarkerToggle.toggledMarkdown(in: input, sourceRange: address.sourceRange),
                "toggling \(task.markerPattern) in \(variant.name)"
            )
            let toggledBytes = Array(toggled.utf8)
            let markerIndex = try #require(
                firstByteIndex(of: task.markerPattern, in: inputBytes),
                "marker \(task.markerPattern) in \(variant.name)"
            )
            let stateOffset = markerIndex + task.stateByteOffsetFromMarkerStart

            // Exact mutation: same length, exactly one differing byte, at the marker state byte.
            #expect(toggledBytes.count == inputBytes.count)
            let differingOffsets = inputBytes.indices.filter { inputBytes[$0] != toggledBytes[$0] }
            #expect(differingOffsets == [stateOffset])

            // Independently constructed expectation: the input with exactly that byte replaced.
            var expected = inputBytes
            expected[stateOffset] = task.toggledStateByte
            #expect(toggledBytes == expected)

            // A second toggle returns the snapshot byte for byte, covering both replacement directions.
            let reverted = try #require(
                FlatMarkTaskMarkerToggle.toggledMarkdown(in: toggled, sourceRange: address.sourceRange)
            )
            #expect(Array(reverted.utf8) == inputBytes)
        }
    }
}

// MARK: - FlatMarkTaskMarkerToggleBoundaryTests

struct FlatMarkTaskMarkerToggleBoundaryTests {
    @Test
    func `mixed line endings and missing final newline address the correct lines`() throws {
        let input = "# Setup 🧪 café\r\n"
            + "- [ ] Alpha café\n"
            + "  - [x] Nested 😀 tail\r"
            + "- [ ] Omega na\u{0308}ve 你好\n"
            + "- [ ] Tail after ☕ done"
        let inputBytes = Array(input.utf8)

        for (address, task) in zip(taskAddresses(in: input), TaskToggleFixture.tasks) {
            let toggled = try #require(
                FlatMarkTaskMarkerToggle.toggledMarkdown(in: input, sourceRange: address.sourceRange)
            )
            let toggledBytes = Array(toggled.utf8)
            let stateOffset = try #require(stateByteOffset(of: task, in: inputBytes))

            #expect(toggledBytes.count == inputBytes.count)
            #expect(inputBytes.indices.filter { inputBytes[$0] != toggledBytes[$0] } == [stateOffset])

            var expected = inputBytes
            expected[stateOffset] = task.toggledStateByte
            #expect(toggledBytes == expected)
        }
    }

    @Test(
        "documents with a final line ending toggle correctly for every terminator",
        arguments: NewlineVariants.all
    )
    func finalLineEndingVariants(variant: NewlineVariants.Variant) throws {
        let input = TaskToggleFixture.joined(with: variant.joiner) + variant.joiner
        let inputBytes = Array(input.utf8)

        // The final task sits on the last line before the trailing terminator.
        let lastAddress = try #require(taskAddresses(in: input).last)
        let lastTask = try #require(TaskToggleFixture.tasks.last)
        let toggled = try #require(
            FlatMarkTaskMarkerToggle.toggledMarkdown(in: input, sourceRange: lastAddress.sourceRange),
            "final task with trailing \(variant.name)"
        )
        let toggledBytes = Array(toggled.utf8)
        let stateOffset = try #require(stateByteOffset(of: lastTask, in: inputBytes))

        #expect(toggledBytes.count == inputBytes.count)
        #expect(inputBytes.indices.filter { inputBytes[$0] != toggledBytes[$0] } == [stateOffset])
    }

    @Test
    func `uppercase checked marker toggles in a mixed-ending document without touching neighbors`() throws {
        let input = "- [ ] One café\r\n- [X] Uppercase na\u{0308}ve 😀\r- [ ] Three 你好"
        let inputBytes = Array(input.utf8)
        let addresses = taskAddresses(in: input)
        #expect(addresses.count == 3)

        let toggled = try #require(
            FlatMarkTaskMarkerToggle.toggledMarkdown(in: input, sourceRange: addresses[1].sourceRange)
        )
        let toggledBytes = Array(toggled.utf8)
        let stateOffset = try #require(stateByteOffset(of: "Uppercase", in: inputBytes))

        #expect(toggledBytes.count == inputBytes.count)
        #expect(inputBytes.indices.filter { inputBytes[$0] != toggledBytes[$0] } == [stateOffset])
        #expect(toggledBytes[stateOffset] == UInt8(ascii: " "))
    }

    @Test
    func `neighboring tasks and marker-like text remain byte-identical during a toggle`() throws {
        let input = "- [ ] Target 🧪 inline [x] marker\n"
            + "- [ ] Neighbor café\n"
            + "- [ ] Sibling 😀 tail"
        let inputBytes = Array(input.utf8)

        // addresses[0] is the Target task; inline "[x]" and both neighbors must stay untouched.
        let toggled = try #require(
            FlatMarkTaskMarkerToggle.toggledMarkdown(in: input, sourceRange: taskAddresses(in: input)[0].sourceRange)
        )
        let toggledBytes = Array(toggled.utf8)
        let stateOffset = try #require(firstByteIndex(of: "- [ ] Target", in: inputBytes)) + 3

        #expect(inputBytes.indices.filter { inputBytes[$0] != toggledBytes[$0] } == [stateOffset])
        #expect(toggledBytes[stateOffset] == UInt8(ascii: "x"))
    }

    @Test
    func `invalid source coordinates fail with nil`() {
        let markdown = "# Setup 🧪 café\r\n- [ ] Alpha café\r\n- [ ] Omega na\u{0308}ve 你好"
        let cases: [(line: Int, column: Int)] = [
            (line: 0, column: 1),
            (line: -3, column: 2),
            (line: 1, column: 0),
            (line: 1, column: -2),
            (line: 99, column: 1),
            // Line 4 does not exist: the document has three lines...
            (line: 4, column: 1),
            // ...and line 3 has 25 content bytes, so column 27 is beyond its content.
            (line: 3, column: 27),
            (line: 1, column: 10000),
        ]

        for bad in cases {
            let address = FlatMarkSourceRange(
                lowerBound: .init(line: bad.line, column: bad.column),
                upperBound: .init(line: bad.line, column: bad.column + 1)
            )
            #expect(
                FlatMarkTaskMarkerToggle.toggledMarkdown(in: markdown, sourceRange: address) == nil,
                "case \(bad)"
            )
        }
    }

    @Test
    func `line mapping follows GFM rules for terminators and content ends`() {
        let cr = "Intro 🧪 café\r- [ ] Alpha café\r\r- [x] Tail 😀"
        let crBytes = Array(cr.utf8)
        // Independent expectations for the same logical lines as LF-only would mislocate:
        // line 2 starts right after the first standalone CR, and the blank line 3 exists.
        #expect(FlatMarkSourceRange.utf8Offset(for: .init(line: 2, column: 1), in: cr)
            == firstByteIndex(of: "- [ ] Alpha", in: crBytes))
        #expect(FlatMarkSourceRange.utf8Offset(for: .init(line: 3, column: 1), in: cr) == 35)
        #expect(FlatMarkSourceRange.utf8Offset(for: .init(line: 4, column: 1), in: cr)
            == firstByteIndex(of: "- [x] Tail", in: crBytes))
        // Line 1 has 16 content bytes: columns 1...17 land in [0, 16], where 17 is the content end
        // (the terminator position), and anything further is beyond the line.
        #expect(FlatMarkSourceRange.utf8Offset(for: .init(line: 1, column: 16), in: cr) == 15)
        #expect(FlatMarkSourceRange.utf8Offset(for: .init(line: 1, column: 17), in: cr) == 16)
        #expect(FlatMarkSourceRange.utf8Offset(for: .init(line: 1, column: 18), in: cr) == nil)
        // A line past the snapshot end is nonexistent.
        #expect(FlatMarkSourceRange.utf8Offset(for: .init(line: 5, column: 1), in: cr) == nil)

        let crlf = "Intro 🧪 café\r\n- [ ] Alpha café\r\n- [ ] Omega café\r\n- [x] Tail 😀"
        let crlfBytes = Array(crlf.utf8)
        // CRLF advances lines by one, not two.
        #expect(FlatMarkSourceRange.utf8Offset(for: .init(line: 2, column: 1), in: crlf)
            == firstByteIndex(of: "- [ ] Alpha", in: crlfBytes))
        #expect(FlatMarkSourceRange.utf8Offset(for: .init(line: 3, column: 1), in: crlf)
            == firstByteIndex(of: "- [ ] Omega", in: crlfBytes))
        #expect(FlatMarkSourceRange.utf8Offset(for: .init(line: 4, column: 1), in: crlf)
            == firstByteIndex(of: "- [x] Tail", in: crlfBytes))
    }
}

// MARK: - FlatMarkTaskMarkerToggleCoordinateContractTests

struct FlatMarkTaskMarkerToggleCoordinateContractTests {
    @Test("a real parsed range endpoint after multibyte text maps to its original byte offset")
    func parsedEndpointAfterMultibyteTextMapsToByteOffset() throws {
        // One task line whose content ends with two-byte CJK after a combining sequence.
        let markdown = "- [ ] Omega na\u{0308}ve 你好"
        let bytes = Array(markdown.utf8)

        let address = try #require(taskAddresses(in: markdown).first)
        let endpoint = address.sourceRange.upperBound
        // Column semantics are UTF-8 bytes, so the parsed column must exceed the line's character count.
        #expect(endpoint.column > markdown.count)

        // Independent determination: the offset just past the final CJK bytes.
        let cjkStart = try #require(firstByteIndex(of: "你好", in: bytes))
        let cjkEnd = cjkStart + Array("你好".utf8).count
        #expect(cjkEnd == bytes.count)

        #expect(FlatMarkSourceRange.utf8Offset(for: endpoint, in: markdown) == cjkEnd)
    }

    @Test("a parsed endpoint on an earlier line after multibyte text maps past that line's content")
    func parsedEndpointOnEarlierLineMapsToByteOffset() throws {
        let markdown = "- [ ] Omega na\u{0308}ve 你好\n- [ ] Tail after ☕ done"
        let bytes = Array(markdown.utf8)

        let address = try #require(taskAddresses(in: markdown).first)
        let endpoint = address.sourceRange.upperBound
        // Independent determination: first newline, which is the content end of line 1.
        let firstNewline = try #require(bytes.firstIndex(of: 10))
        let cjkEnd = try #require(firstByteIndex(of: "你好", in: bytes)) + Array("你好".utf8).count
        #expect(cjkEnd == firstNewline)
        #expect(FlatMarkSourceRange.utf8Offset(for: endpoint, in: markdown) == firstNewline)
    }
}

// MARK: - NewlineVariants

enum NewlineVariants {
    struct Variant: Sendable, Equatable {
        let name: String
        let joiner: String
    }

    static let all = [
        Variant(name: "LF", joiner: "\n"),
        Variant(name: "CRLF", joiner: "\r\n"),
        Variant(name: "CR", joiner: "\r"),
    ]
}

// MARK: - TaskToggleFixture

enum TaskToggleFixture {
    /// One logical document; joined with LF, CRLF, or standalone CR per variant.
    static let lines: [String] = [
        "# Setup 🧪 café",
        "",
        "- [ ] Alpha café",
        "  - [x] Nested 😀 tail",
        "- [ ] Omega na\u{0308}ve 你好",
        "- [ ] Tail after ☕ done",
    ]

    struct Task {
        let markerPattern: String
        let toggledStateByte: UInt8

        /// Offset of the marker's state byte relative to the pattern's start: the byte after "[".
        var stateByteOffsetFromMarkerStart: Int {
            Array(markerPattern.utf8).firstIndex(of: UInt8(ascii: "["))! + 1
        }
    }

    /// Tasks in document order; patterns include task text so each is unique in the document.
    static let tasks: [Task] = [
        Task(markerPattern: "- [ ] Alpha café", toggledStateByte: UInt8(ascii: "x")),
        Task(markerPattern: "  - [x] Nested 😀 tail", toggledStateByte: UInt8(ascii: " ")),
        Task(markerPattern: "- [ ] Omega na\u{0308}ve 你好", toggledStateByte: UInt8(ascii: "x")),
        Task(markerPattern: "- [ ] Tail after ☕ done", toggledStateByte: UInt8(ascii: "x")),
    ]

    static func joined(with joiner: String) -> String {
        lines.joined(separator: joiner)
    }
}

private func stateByteOffset(of task: TaskToggleFixture.Task, in bytes: [UInt8]) -> Int? {
    guard let markerIndex = firstByteIndex(of: task.markerPattern, in: bytes) else {
        return nil
    }

    return markerIndex + task.stateByteOffsetFromMarkerStart
}

/// Locates the marker state byte of a task containing `text` by scanning back
/// from the task text to the opening bracket of its checkbox.
private func stateByteOffset(of text: String, in bytes: [UInt8]) -> Int? {
    guard let textIndex = firstByteIndex(of: text, in: bytes) else {
        return nil
    }

    var candidate = textIndex
    while candidate >= 0 {
        if bytes[candidate] == UInt8(ascii: "[") {
            return candidate + 1
        }
        candidate -= 1
    }
    return nil
}

private func firstByteIndex(of pattern: String, in bytes: [UInt8]) -> Int? {
    let needle = Array(pattern.utf8)
    var start = 0
    while start + needle.count <= bytes.count {
        if Array(bytes[start ..< start + needle.count]) == needle {
            return start
        }
        start += 1
    }
    return nil
}

// MARK: - TaskAddress

/// One projected task's structural path and the editing address a toggle is handed.
private struct TaskAddress: Equatable, Sendable {
    let path: [Int]
    let sourceRange: FlatMarkSourceRange
}

private func taskAddresses(in markdown: String) -> [TaskAddress] {
    FlatMarkRenderProjector.project(markdown: markdown).blocks.flatMap(taskAddresses(in:))
}

private func toggledMarkdown(in markdown: String) -> String? {
    guard let address = taskAddresses(in: markdown).first else {
        return nil
    }

    return FlatMarkTaskMarkerToggle.toggledMarkdown(in: markdown, sourceRange: address.sourceRange)
}

private func taskAddresses(in block: FlatMarkRenderBlock) -> [TaskAddress] {
    switch block.kind {
    case let .blockQuote(blocks):
        blocks.flatMap(taskAddresses(in:))
    case let .list(entries):
        entries.flatMap { entry -> [TaskAddress] in
            switch entry {
            case let .row(row):
                guard case let .task(_, sourceRange) = row.marker, let sourceRange else {
                    return []
                }

                return [TaskAddress(path: row.id.path, sourceRange: sourceRange)]
            case let .childBlock(childBlock):
                return taskAddresses(in: childBlock.block)
            }
        }
    default:
        []
    }
}

private extension String {
    func replacingFirst(_ old: String, with new: String) -> String {
        replacingOccurrences(of: old, with: new, options: [], range: range(of: old))
    }
}
