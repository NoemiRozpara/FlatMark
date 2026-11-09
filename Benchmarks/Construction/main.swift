import FlatMark
import Foundation

// Opt-in diagnostic, not a timing assertion in the ordinary test suite.
struct Fixture {
    let name: String
    let parameters: String
    let markdown: String
}

let section = """
## Preparation
Ask @alex to review **the draft** and [notes](notes/overview).

- [ ] Review ingredients
- [x] Prepare equipment

> Keep the source snapshot with its tasks.

"""
let fixtures: [Fixture] = [
    Fixture(name: "ordinary", parameters: "1 section", markdown: section),
    Fixture(name: "large-100", parameters: "100 sections", markdown: String(repeating: section, count: 100)),
    Fixture(name: "large-1000", parameters: "1000 sections", markdown: String(repeating: section, count: 1000)),
    Fixture(
        name: "nested", parameters: "32 quote levels + 32 list levels",
        markdown: String(repeating: "> ", count: 32) + "Deep quote @alex\n\n"
            + (0..<32).map { String(repeating: "  ", count: $0) + "- Level \($0)\n" }.joined()
    ),
    Fixture(
        name: "links-tables", parameters: "500 rows, 3 columns, 1500 relative links",
        markdown: "| First | Second | Third |\n| --- | --- | --- |\n"
            + (0..<500).map { "| [Item \($0)](items/\($0)) | [Notes](notes/\($0)) | [Owner @alex](people/\($0)) |\n" }.joined()
    ),
]

// Reflection occurs AFTER timing and reads the entire snapshot, including its private projection.
// Printing the aggregate makes the measured result observable without a production instrumentation API.
@inline(never)
func consume(_ document: FlatMarkDocument) -> Int {
    String(reflecting: document).utf8.count
}

func milliseconds(_ duration: Duration) -> Double {
    let parts = duration.components
    return Double(parts.seconds) * 1000 + Double(parts.attoseconds) / 1e15
}

func report(_ fixture: String, _ scenario: String, _ samples: [Double]) {
    let sorted = samples.sorted()
    let median = sorted[sorted.count / 2]
    let p95 = sorted[Int(ceil(Double(sorted.count) * 0.95)) - 1]
    print("\(fixture),\(scenario),\(samples.count),\(String(format: "%.6f", median)),\(String(format: "%.6f", p95)),\(String(format: "%.6f", sorted[0]))")
}

let clock = ContinuousClock()
let baseURL = URL(string: "https://example.com/tasks/")!
let changedURL = URL(string: "https://example.com/archive/")!
let sampleCount = 30
var checksum = 0
print("FlatMark construction benchmark: Release required; 5 warmups; 30 samples; ms; no SwiftUI rendering")
print("fixture,scenario,samples,median_ms,p95_ms,min_ms")
for fixture in fixtures {
    print("# \(fixture.name): \(fixture.parameters); UTF8=\(fixture.markdown.utf8.count)")
    let retained = FlatMarkDocument(markdown: fixture.markdown, baseURL: baseURL)
    // Build all changed inputs outside the timed region. No cache exists: each scenario constructs anew.
    let scenarios: [(String, String, URL)] = [
        ("initial", fixture.markdown, baseURL),
        ("source-change", fixture.markdown + "\nUpdated description.\n", baseURL),
        ("baseURL-change", fixture.markdown, changedURL),
    ]
    for (name, source, url) in scenarios {
        var samples: [Double] = []
        for iteration in 0..<(sampleCount + 5) {
            let start = clock.now
            let document = FlatMarkDocument(markdown: source, baseURL: url)
            let elapsed = milliseconds(start.duration(to: clock.now))
            checksum &+= consume(document)
            if iteration >= 5 { samples.append(elapsed) }
        }
        report(fixture.name, name, samples)
    }
    // Batch copying a retained value is NOT view refresh, equality comparison, or parser timing.
    // The array is preallocated; its element lifetimes end outside the measured interval.
    var reuseSamples: [Double] = []
    for iteration in 0..<(sampleCount + 5) {
        var copies: [FlatMarkDocument] = []
        copies.reserveCapacity(1000)
        let start = clock.now
        for _ in 0..<1000 { copies.append(retained) }
        let elapsed = milliseconds(start.duration(to: clock.now)) / 1000
        checksum &+= consume(copies[iteration % copies.count])
        if iteration >= 5 { reuseSamples.append(elapsed) }
    }
    report(fixture.name, "retained-copy-per-value", reuseSamples)
}
print("Consumed snapshot checksum: \(checksum)")
