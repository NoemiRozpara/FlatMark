import Foundation
import Testing

// MARK: - LoaderSpyTests

/// Checks that ``LoaderSpy`` retains callbacks regardless of arrival order and reports missing
/// callbacks without hanging. These are harness checks, not renderer observations.
struct LoaderSpyTests {
    private static let imageURL = URL(string: "https://example.com/image.png")!

    /// One kind of callback the host loader reports, spelled so every ordering check runs for both.
    enum SpyEvent: CaseIterable, Sendable {
        case load
        case cancellation

        var displayName: String {
            switch self {
            case .load: "loader invocation"
            case .cancellation: "image request cancellation"
            }
        }

        var other: SpyEvent {
            self == .load ? .cancellation : .load
        }

        func record(on spy: LoaderSpy) async {
            switch self {
            case .load: await spy.record(LoaderSpyTests.imageURL)
            case .cancellation: await spy.recordCancellation()
            }
        }

        func expect(on spy: LoaderSpy, confirmedBy confirmation: Confirmation) async {
            switch self {
            case .load: await spy.expectLoad(confirmedBy: confirmation)
            case .cancellation: await spy.expectCancellation(confirmedBy: confirmation)
            }
        }

        /// Callbacks of this kind recorded so far, whether or not an expectation consumed them.
        func recordedCount(on spy: LoaderSpy) async -> Int {
            switch self {
            case .load: await spy.loadedURLs.count
            case .cancellation: await spy.cancellationCount
            }
        }

        /// Callbacks of this kind recorded and not yet consumed by an expectation.
        func unconsumedCount(on spy: LoaderSpy) async -> Int {
            switch self {
            case .load: await spy.unconsumedLoadCount
            case .cancellation: await spy.unconsumedCancellationCount
            }
        }
    }

    // MARK: Ordering

    @Test(arguments: SpyEvent.allCases)
    func `retains a callback recorded before its expectation is armed`(event: SpyEvent) async {
        let spy = LoaderSpy()

        await event.record(on: spy)
        #expect(await event.unconsumedCount(on: spy) == 1)

        await confirmation(
            "the \(event.displayName) that arrived first still confirms the later expectation",
            expectedCount: 1
        ) { confirmed in
            await event.expect(on: spy, confirmedBy: confirmed)

            // Arming consumes the retained callback, so waiting must return immediately.
            #expect(await spy.isAwaitingExpectation == false)
            #expect(await event.unconsumedCount(on: spy) == 0)
            await spy.awaitExpectation(deadline: .seconds(2))
        }

        #expect(await event.recordedCount(on: spy) == 1)
    }

    @Test(arguments: SpyEvent.allCases)
    func `waits for a callback recorded after its expectation is armed`(event: SpyEvent) async {
        let spy = LoaderSpy()

        await confirmation(
            "the \(event.displayName) confirms the armed expectation",
            expectedCount: 1
        ) { confirmed in
            await event.expect(on: spy, confirmedBy: confirmed)
            #expect(await spy.isAwaitingExpectation)
            #expect(await event.unconsumedCount(on: spy) == 0)

            await event.record(on: spy)
            #expect(await spy.isAwaitingExpectation == false)
            await spy.awaitExpectation(deadline: .seconds(2))
            #expect(await spy.suspendedWaiterCount == 0)
        }

        #expect(await event.recordedCount(on: spy) == 1)
    }

    // MARK: One callback, one expectation

    @Test(arguments: SpyEvent.allCases)
    func `serves each of two expectations with one callback`(event: SpyEvent) async {
        let spy = LoaderSpy()
        await event.record(on: spy)
        await event.record(on: spy)

        await confirmation("the first expectation is confirmed", expectedCount: 1) { first in
            await event.expect(on: spy, confirmedBy: first)
            await spy.awaitExpectation(deadline: .seconds(2))
        }
        await confirmation(
            "the second expectation is confirmed by the second callback",
            expectedCount: 1
        ) { second in
            await event.expect(on: spy, confirmedBy: second)
            await spy.awaitExpectation(deadline: .seconds(2))
        }

        #expect(await event.recordedCount(on: spy) == 2)
        #expect(await event.unconsumedCount(on: spy) == 0)
    }

    @Test(arguments: SpyEvent.allCases)
    func `does not satisfy a second expectation with one callback`(event: SpyEvent) async {
        let spy = LoaderSpy()

        await confirmation(
            "the callback confirms the expectation armed for it",
            expectedCount: 1
        ) { confirmed in
            await event.expect(on: spy, confirmedBy: confirmed)
            await event.record(on: spy)
            await spy.awaitExpectation(deadline: .seconds(2))
        }

        await confirmation(
            "the same callback does not confirm a second expectation",
            expectedCount: 0
        ) { unconfirmed in
            await event.expect(on: spy, confirmedBy: unconfirmed)
            await spy.awaitExpectation(deadline: .milliseconds(100))
        }

        #expect(await event.recordedCount(on: spy) == 1)
        #expect(await event.unconsumedCount(on: spy) == 0)
    }

    @Test(arguments: SpyEvent.allCases)
    func `does not let a callback satisfy the other kind of expectation`(event: SpyEvent) async {
        let spy = LoaderSpy()
        await event.record(on: spy)

        await confirmation(
            "a \(event.other.displayName) leaves a \(event.displayName) expectation waiting",
            expectedCount: 0
        ) { mismatched in
            await event.other.expect(on: spy, confirmedBy: mismatched)

            // The mismatched callback neither confirms the expectation nor is consumed by it: it stays
            // available for the expectation that asks for its kind.
            #expect(await spy.isAwaitingExpectation)
            #expect(await event.unconsumedCount(on: spy) == 1)

            await spy.awaitExpectation(deadline: .milliseconds(100))
            #expect(await event.unconsumedCount(on: spy) == 1)
        }

        await confirmation(
            "the expectation of the recorded kind is still confirmed by it",
            expectedCount: 1
        ) { confirmed in
            await event.expect(on: spy, confirmedBy: confirmed)
            await spy.awaitExpectation(deadline: .seconds(2))
        }

        #expect(await event.recordedCount(on: spy) == 1)
        #expect(await event.other.recordedCount(on: spy) == 0)
    }

    @Test(arguments: SpyEvent.allCases)
    func `retains a callback that arrives after its wait timed out`(event: SpyEvent) async {
        let spy = LoaderSpy()

        await confirmation(
            "the expectation whose \(event.displayName) never arrives is not confirmed",
            expectedCount: 0
        ) { unconfirmed in
            await event.expect(on: spy, confirmedBy: unconfirmed)
            await spy.awaitExpectation(deadline: .milliseconds(50))
        }

        // The late callback is not credited to a wait that has ended, and is not dropped either: it is
        // still there for the expectation armed afterwards, like any callback recorded on its own.
        await event.record(on: spy)
        #expect(await event.unconsumedCount(on: spy) == 1)
        #expect(await spy.isAwaitingExpectation == false)

        await confirmation(
            "the late \(event.displayName) confirms a later expectation",
            expectedCount: 1
        ) { confirmed in
            await event.expect(on: spy, confirmedBy: confirmed)
            await spy.awaitExpectation(deadline: .seconds(2))
        }

        #expect(await event.recordedCount(on: spy) == 1)
        #expect(await event.unconsumedCount(on: spy) == 0)
    }

    // MARK: Bounded failure

    @Test(.timeLimit(.minutes(1)), arguments: SpyEvent.allCases)
    func `ends a wait at its deadline when the callback never arrives`(event: SpyEvent) async {
        let spy = LoaderSpy()
        let clock = ContinuousClock()
        let started = clock.now

        await confirmation(
            "nothing is confirmed without the \(event.displayName)",
            expectedCount: 0
        ) { unconfirmed in
            await event.expect(on: spy, confirmedBy: unconfirmed)
            await spy.awaitExpectation(deadline: .milliseconds(100))
        }

        // A missing callback must not return before its deadline. Scheduling under CI load can
        // delay resumption, so the test time limit guards against hangs instead of an elapsed cap.
        let elapsed = started.duration(to: clock.now)
        #expect(elapsed >= .milliseconds(80))
        #expect(await spy.isAwaitingExpectation == false)
        #expect(await spy.suspendedWaiterCount == 0)
        #expect(await event.recordedCount(on: spy) == 0)
        #expect(await event.unconsumedCount(on: spy) == 0)
    }

    @Test
    func `returns from a wait immediately when nothing is armed`() async {
        let spy = LoaderSpy()
        let clock = ContinuousClock()
        let started = clock.now

        await spy.awaitExpectation(deadline: .seconds(10))

        #expect(started.duration(to: clock.now) < .seconds(5))
        #expect(await spy.suspendedWaiterCount == 0)
    }

    @Test
    func `a deadline left over from an earlier wait cannot release a later wait`() async throws {
        let spy = LoaderSpy()
        let staleDeadline: Duration = .milliseconds(500)

        // The first wait is released by its own callback long before its deadline is due, so that
        // deadline is still sleeping when the second wait begins.
        try await confirmation(
            "the first callback confirms the first expectation",
            expectedCount: 1
        ) { first in
            await spy.expectLoad(confirmedBy: first)
            let firstWait = Task { await spy.awaitExpectation(deadline: staleDeadline) }
            try await waitForSuspendedWaiter(on: spy)
            await spy.record(LoaderSpyTests.imageURL)
            await firstWait.value
        }
        #expect(await spy.suspendedWaiterCount == 0)

        try await confirmation(
            "the second callback confirms the second expectation",
            expectedCount: 1
        ) { second in
            await spy.expectLoad(confirmedBy: second)
            let secondWait = Task { await spy.awaitExpectation(deadline: .seconds(5)) }
            try await waitForSuspendedWaiter(on: spy)

            // Let the earlier wait's deadline pass while this one is suspended. A released waiter
            // leaves the list, so still being listed says this wait was not ended by that deadline.
            try await Task.sleep(for: staleDeadline + .milliseconds(250))
            #expect(await spy.suspendedWaiterCount == 1)
            #expect(await spy.isAwaitingExpectation)

            await spy.record(LoaderSpyTests.imageURL)
            await secondWait.value
        }

        #expect(await spy.loadedURLs.count == 2)
        #expect(await spy.suspendedWaiterCount == 0)
    }

    // MARK: Misuse

    @Test
    func `reports an expectation dropped by a later arm`() async {
        let spy = LoaderSpy()

        // Arming on top of an expectation that is still waiting must say so: its confirmation can no
        // longer arrive, so leaving it quiet would report a missing callback somewhere else entirely.
        await confirmation(
            "the outstanding expectation is never confirmed",
            expectedCount: 0
        ) { outstanding in
            await spy.expectLoad(confirmedBy: outstanding)
        }
        #expect(await spy.isAwaitingExpectation)

        await withKnownIssue(Comment(rawValue: LoaderSpy.droppedExpectationComment)) {
            // Nothing is recorded on this spy inside the block, so the diagnostic for the dropped
            // expectation is the only issue that can appear here.
            await confirmation(
                "the replacing expectation is not confirmed either",
                expectedCount: 0
            ) { replaced in
                await spy.expectLoad(confirmedBy: replaced)
            }
        }

        #expect(await spy.isAwaitingExpectation)
        #expect(await spy.loadedURLs.isEmpty)
    }

    // MARK: Helpers

    /// Bounded wait for a suspended waiter, so a deadline can be timed against a wait that has
    /// genuinely started. Gives up rather than hanging the suite.
    private func waitForSuspendedWaiter(on spy: LoaderSpy) async throws {
        var observed = await spy.suspendedWaiterCount
        for _ in 0 ..< 200 {
            if observed == 1 {
                return
            }
            try await Task.sleep(for: .milliseconds(5))
            observed = await spy.suspendedWaiterCount
        }

        try #require(
            observed == 1,
            "expected a suspended waiter on the image loader spy, observed \(observed)"
        )
    }
}
