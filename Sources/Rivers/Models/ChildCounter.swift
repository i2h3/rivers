import os

///
/// A thread-safe monotonic counter used to allocate sibling indices for child activities. Shared by struct copies of an `Activity`, so each parent owns exactly one counter regardless of how its handle is passed around.
///
final class ChildCounter: Sendable {
    private let lock = OSAllocatedUnfairLock<UInt32>(initialState: 0)

    ///
    /// Atomically advance the counter and return the new value. The first call returns `1`.
    ///
    func next() -> UInt32 {
        lock.withLock { state in
            state += 1

            return state
        }
    }
}
