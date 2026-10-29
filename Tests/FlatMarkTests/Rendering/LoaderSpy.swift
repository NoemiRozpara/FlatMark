import Foundation
import Testing

// MARK: - LoaderSpy

/// Records what the host loader was asked to do, and lets a test suspend until the callback it is
/// about to trigger has arrived.
///
/// The waiting is event-driven and the counting is Swift Testing's: a test arms an expectation with
/// a ``Confirmation``, the matching callback confirms it, and the waiter returns the moment it
/// arrives. A confirmation that never arrives is therefore reported by Swift Testing as falling
/// short, rather than by a polling bound here.
///
/// The contract with a test is that a callback is never lost, so the order of the two sides does not
/// matter: a recorded callback is retained until an expectation of its own kind consumes it, which
/// means a test may trigger the loader and arm afterwards, or arm and let the callback arrive
/// whenever it does. Consuming is what removes a callback, so one callback satisfies exactly one
/// expectation, a callback recorded while nothing was armed still satisfies the expectation armed for
/// it later, and no callback is attributed to nothing. ``unconsumedLoadCount`` and
/// ``unconsumedCancellationCount`` make that retention observable.
///
/// An expectation belongs to the wait that armed it. Once that wait ends at its deadline, the spy
/// stops expecting the callback that did not come, so a negative check can arm, wait, and then arm
/// again, and a later arm never quietly replaces an expectation somebody is still waiting on.
actor LoaderSpy {
    /// The comment this harness records when a test arms a second expectation while an earlier one is
    /// still waiting to be consumed, whose confirmation can then never arrive. Its focused check
    /// matches on this text.
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

        // A wait that ran out its own deadline while still unmet will not be met: the confirmation is
        // reported by Swift Testing as falling short, and the callback cannot arrive to a wait that
        // has ended. So stop expecting it. The callback itself stays recorded and unconsumed, which
        // is what a count assertion in the test reads.
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

    /// Satisfies the armed expectation with one callback of its own kind, if one is waiting, and
    /// consumes only that one. A callback of another kind is left untouched, and a callback recorded
    /// while nothing was armed is still here for the expectation armed for it later.
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
