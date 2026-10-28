import Darwin
import Foundation

/// Per-thread recursion guard.
///
/// A sink that logs (for example an error sink that reports a failure)
/// would otherwise recurse forever. A thread-local flag is the cheapest
/// correct option here: `record` is synchronous and may run on any thread.
final class TapeReentrancyGuard: @unchecked Sendable {
    private let key: pthread_key_t

    init() {
        var key = pthread_key_t()
        pthread_key_create(&key, nil)
        self.key = key
    }

    /// Returns `false` when the current thread is already recording.
    func enter() -> Bool {
        guard pthread_getspecific(key) == nil else { return false }
        pthread_setspecific(key, UnsafeMutableRawPointer(bitPattern: 1))
        return true
    }

    func exit() {
        pthread_setspecific(key, nil)
    }
}
