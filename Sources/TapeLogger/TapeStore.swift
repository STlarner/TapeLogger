import Foundation
import os

/// Bounded in-memory history plus a broadcast stream for observers.
///
/// The hot path is a single unfair lock: no `await`, no actor hop, no task
/// per log. Continuations are yielded *inside* the lock because `yield`
/// never blocks and ordering matters; user callbacks are never invoked
/// with the lock held.
public final class TapeStore: Sendable {
    public let capacity: Int
    public let streamBufferSize: Int

    private struct State: Sendable {
        var entries: [TapeEntry] = []
        var continuations: [UUID: AsyncStream<TapeEntry>.Continuation] = [:]
    }

    private let state: OSAllocatedUnfairLock<State>

    /// - Parameters:
    ///   - capacity: maximum retained entries. Old entries are dropped in
    ///     chunks so the hot path stays amortized O(1).
    ///   - streamBufferSize: newest-N buffer per subscriber. When a subscriber
    ///     is slower than the producer, the oldest entries are dropped.
    public init(capacity: Int = 1000, streamBufferSize: Int = 2000) {
        precondition(capacity > 0, "capacity must be greater than zero")
        precondition(streamBufferSize > 0, "streamBufferSize must be greater than zero")
        self.capacity = capacity
        self.streamBufferSize = streamBufferSize
        self.state = OSAllocatedUnfairLock(initialState: State())
    }

    public func append(_ entry: TapeEntry) {
        state.withLock { state in
            state.entries.append(entry)

            if state.entries.count > capacity {
                // Drop in chunks: trimming one element per log would move
                // the whole array on every append once full.
                let overflow = state.entries.count - capacity
                let chunk = max(overflow, capacity / 10)
                state.entries.removeFirst(min(chunk, state.entries.count))
            }

            for continuation in state.continuations.values {
                continuation.yield(entry)
            }
        }
    }

    /// A snapshot copy, safe to hand to the UI.
    public func snapshot() -> [TapeEntry] {
        state.withLock { $0.entries }
    }

    public func clear() {
        state.withLock { $0.entries.removeAll() }
    }

    public var count: Int {
        state.withLock { $0.entries.count }
    }

    /// New stream per subscriber. Cancelling the consuming task terminates
    /// the stream and unregisters the continuation.
    public var stream: AsyncStream<TapeEntry> {
        AsyncStream(bufferingPolicy: .bufferingNewest(streamBufferSize)) { continuation in
            let id = UUID()
            state.withLock { $0.continuations[id] = continuation }
            continuation.onTermination = { [state] _ in
                state.withLock { $0.continuations[id] = nil }
            }
        }
    }
}
