import Foundation
import Testing

// MARK: - LoaderSpy

/// Records loader callbacks and waits for them with Swift Testing confirmations.
/// Missing callbacks fail their confirmation when the wait reaches its deadline.
///
/// Each callback remains available until one expectation of its kind consumes it, even if it
/// arrives before arming. ``unconsumedLoadCount`` and ``unconsumedCancellationCount`` expose this.
///
/// Only the owning wait can release an expectation. A deadline clears an unmet expectation so
/// another can be armed; arming over an active expectation reports misuse.
actor LoaderSpy {
    /// Diagnostic for arming over an active expectation. The focused test matches this text.
    static let droppedExpectationComment =
        "Armed a second image loader expectation while an earlier one was still waiting to be confirmed."

    private enum Callback {
        case load
        case cancellation
    }

    private struct Expectation {
        let callback: Callback
        let confirmation: Confirmation
        let generation: Int
    }

    private struct Waiter {
        let generation: Int
        let continuation: CheckedContinuation<Bool, Never>
    }

    private(set) var loadedURLs: [URL] = []
    private(set) var cancellationCount = 0

    /// Recorded callbacks of each kind still waiting for an expectation of that kind to consume them.
    private var unconsumedLoads = 0
    private var unconsumedCancellations = 0

    private var expectation: Expectation?
    private var generation = 0
    private var waiters: [Waiter] = []

    func record(_ url: URL) {
        loadedURLs.append(url)
        unconsumedLoads += 1
        confirmArmedExpectation()
    }

    func recordCancellation() {
        cancellationCount += 1
        unconsumedCancellations += 1
        confirmArmedExpectation()
    }

    /// Arms the expectation that the loader is invoked once. An invocation recorded earlier is
    /// consumed here, so a test may arm after the state change that triggers it.
    func expectLoad(confirmedBy confirmation: Confirmation) {
        arm(callback: .load, confirmation: confirmation)
    }

    /// Arms the expectation that one cancelled image request is observed, whenever it was cancelled.
    func expectCancellation(confirmedBy confirmation: Confirmation) {
        arm(callback: .cancellation, confirmation: confirmation)
    }

    /// Suspends until the armed expectation is met, or until `deadline` passes so a callback that
    /// never arrives is reported as the missing confirmation it is instead of hanging the suite.
    /// Only the wait armed for this expectation releases it, so a deadline left over from an earlier
    /// wait on the same spy cannot end a later one early.
    func awaitExpectation(deadline: Duration) async {
        guard let armed = expectation else {
            return
        }

        let armedGeneration = armed.generation
        let releasedByDeadline = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            waiters.append(Waiter(generation: armedGeneration, continuation: continuation))
            Task {
                try? await Task.sleep(for: deadline)
                releaseWaiters(armedFor: armedGeneration, releasedByDeadline: true)
            }
        }

        // Clear only this wait's unmet expectation. Keep recorded callbacks for count assertions.
        if releasedByDeadline, expectation?.generation == armedGeneration {
            expectation = nil
        }
    }

    // MARK: Diagnostics for the focused checks of this harness

    /// Whether an expectation is armed and still waiting for its callback.
    var isAwaitingExpectation: Bool {
        expectation != nil
    }

    /// How many waits are currently suspended. A wait its deadline released leaves this list, so the
    /// count distinguishes a genuinely suspended wait from one that ended early.
    var suspendedWaiterCount: Int {
        waiters.count
    }

    /// Loader invocations recorded and not yet consumed by an expectation.
    var unconsumedLoadCount: Int {
        unconsumedLoads
    }

    /// Cancellations recorded and not yet consumed by an expectation.
    var unconsumedCancellationCount: Int {
        unconsumedCancellations
    }

    // MARK: Waiting

    private func arm(callback: Callback, confirmation: Confirmation) {
        if expectation != nil {
            Issue.record(Comment(rawValue: Self.droppedExpectationComment))
        }

        generation += 1
        expectation = Expectation(callback: callback, confirmation: confirmation, generation: generation)
        confirmArmedExpectation()
    }

    /// Consumes one matching callback for the armed expectation. Other callbacks remain available.
    private func confirmArmedExpectation() {
        guard let expectation else {
            return
        }

        switch expectation.callback {
        case .load:
            guard unconsumedLoads > 0 else {
                return
            }
            unconsumedLoads -= 1
        case .cancellation:
            guard unconsumedCancellations > 0 else {
                return
            }
            unconsumedCancellations -= 1
        }

        self.expectation = nil
        expectation.confirmation.confirm()
        releaseWaiters(armedFor: expectation.generation, releasedByDeadline: false)
    }

    /// Resumes the waits armed for one expectation and only those, so a deadline from an earlier
    /// expectation cannot release a wait that is armed for a later one.
    private func releaseWaiters(armedFor armedGeneration: Int, releasedByDeadline: Bool) {
        let releasing = waiters.filter { $0.generation == armedGeneration }
        waiters.removeAll { $0.generation == armedGeneration }
        for waiter in releasing {
            waiter.continuation.resume(returning: releasedByDeadline)
        }
    }
}
