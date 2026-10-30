import Foundation
import os

/// Bounded in-memory history plus a broadcast stream for observers.
///
/// Appends update history and yield buffered stream events under one lock to
/// preserve append order. The store does not await consumer processing or
/// create a task for each entry.
public final class TapeStore: Sendable {
    /// Maximum retained entries; must be positive.
    public let capacity: Int
    /// Maximum newest entries buffered independently for each stream subscriber.
    public let streamBufferSize: Int

    package enum Event: Sendable {
        case entry(TapeEntry, generation: UUID)
        case reset(generation: UUID)
    }

    private struct State: Sendable {
        var entries: [TapeEntry] = []
        var continuations: [UUID: AsyncStream<TapeEntry>.Continuation] = [:]
        var observers: [UUID: AsyncStream<Event>.Continuation] = [:]
        var generation = UUID()
    }

    private let state: OSAllocatedUnfairLock<State>

    /// Creates bounded history independent of any logger or UI.
    ///
    /// ```swift
    /// let store = TapeStore(capacity: 500, streamBufferSize: 1000)
    /// let logger = Tape(sinks: [], store: store)
    /// logger.info("Retained in custom history")
    /// ```
    ///
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

    /// Retains and broadcasts an entry without logger severity filtering.
    /// Overflow trims oldest entries in chunks, so retained count may fall
    /// below capacity. Calls are thread-safe and observers receive append order.
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
            for observer in state.observers.values {
                observer.yield(.entry(entry, generation: state.generation))
            }
        }
    }

    /// Returns retained entries in append order as a snapshot safe to share.
    public func snapshot() -> [TapeEntry] {
        state.withLock { $0.entries }
    }

    /// Clears retained history and resets subscribed consoles. The public
    /// entry-only stream keeps already-buffered entries and emits no reset;
    /// it remains subscribed for subsequent appends.
    public func clear() {
        state.withLock { state in
            state.entries.removeAll()
            state.generation = UUID()
            for observer in state.observers.values {
                observer.yield(.reset(generation: state.generation))
            }
        }
    }

    package var generation: UUID { state.withLock { $0.generation } }

    /// Current retained entry count, never greater than `capacity`.
    public var count: Int {
        state.withLock { $0.entries.count }
    }

    /// New stream per subscriber. Cancelling the consuming task terminates
    /// the stream and unregisters the continuation.
    /// It receives future appends only, not a history replay. Slow consumers
    /// lose their oldest buffered entries. The stream does not finish when the
    /// store is cleared; cancel its consuming task when observation is no longer
    /// needed. A separate snapshot plus subscription is not an atomic operation.
    public var stream: AsyncStream<TapeEntry> {
        AsyncStream(bufferingPolicy: .bufferingNewest(streamBufferSize)) { continuation in
            let id = UUID()
            state.withLock { $0.continuations[id] = continuation }
            continuation.onTermination = { [state] _ in
                state.withLock { $0.continuations[id] = nil }
            }
        }
    }

    /// Takes the snapshot and registers the stream under the same lock, avoiding
    /// a subscription gap. Slow consumers can still overflow the stream buffer.
    package func snapshotAndStream() -> (
        snapshot: [TapeEntry], stream: AsyncStream<TapeEntry>
    ) {
        let (stream, continuation) = AsyncStream<TapeEntry>.makeStream(
            bufferingPolicy: .bufferingNewest(streamBufferSize)
        )
        let id = UUID()
        continuation.onTermination = { [state] _ in
            state.withLock { $0.continuations[id] = nil }
        }
        let snapshot = state.withLock { state in
            state.continuations[id] = continuation
            return state.entries
        }
        return (snapshot, stream)
    }

    /// Console events carry a generation even when a reset is dropped by a
    /// newest-N buffer. The public entry-only stream keeps its existing API.
    package func snapshotAndEvents() -> (
        snapshot: [TapeEntry], generation: UUID, stream: AsyncStream<Event>
    ) {
        let (stream, continuation) = AsyncStream<Event>.makeStream(
            bufferingPolicy: .bufferingNewest(streamBufferSize)
        )
        let id = UUID()
        continuation.onTermination = { [state] _ in
            state.withLock { $0.observers[id] = nil }
        }
        let snapshot = state.withLock { state in
            state.observers[id] = continuation
            return (state.entries, state.generation)
        }
        return (snapshot.0, snapshot.1, stream)
    }
}
