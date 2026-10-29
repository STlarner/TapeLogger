import Darwin
import Foundation

/// Per-thread recursion guard.
///
/// A sink that logs (for example an error sink that reports a failure)
/// would otherwise recurse forever. A thread-local flag is the cheapest
/// correct option here: `record` is synchronous and may run on any thread.
final class TapeReentrancyGuard: Sendable {
    private enum Storage: Sendable {
        case key(pthread_key_t)
        case threadDictionary(String)
    }

    private let storage: Storage

    init() {
        var key = pthread_key_t()
        let result = pthread_key_create(&key, nil)
        if result == 0 {
            storage = .key(key)
        } else {
            // Exhaustion must not crash the app or reuse somebody else's
            // key. Only this exceptional path pays for a dictionary lookup.
            storage = .threadDictionary("TapeLogger.recursion.\(UUID())")
        }
    }

    deinit {
        if case .key(let key) = storage { pthread_key_delete(key) }
    }

    /// Returns `false` when the current thread is already recording.
    func enter() -> Bool {
        switch storage {
        case .key(let key):
            guard pthread_getspecific(key) == nil else { return false }
            return pthread_setspecific(
                key, UnsafeMutableRawPointer(bitPattern: 1)
            ) == 0
        case .threadDictionary(let key):
            let dictionary = Thread.current.threadDictionary
            guard dictionary[key] == nil else { return false }
            dictionary[key] = true
            return true
        }
    }

    func exit() {
        switch storage {
        case .key(let key): pthread_setspecific(key, nil)
        case .threadDictionary(let key):
            Thread.current.threadDictionary.removeObject(forKey: key)
        }
    }
}
