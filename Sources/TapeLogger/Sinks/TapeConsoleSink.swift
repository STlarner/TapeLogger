import Foundation
import os

/// Writes rendered entries to stdout, which is what the Xcode console and
/// the terminal show.
///
/// Rendering and I/O run on a serial worker, never on the logging thread.
/// When the bounded queue fills, new console entries are dropped; the store
/// still retains them. Retain the sink and `await sink.flush()` when a tool
/// needs to wait for output before exiting (not from a renderer).
public struct TapeConsoleSink: TapeSink {
    /// Palette copied into each accepted output job.
    public var theme: TapeTheme
    /// Renderer run on the output worker, not the recording thread.
    public var renderer: any TapeTextRenderer
    /// Presentation mode and width copied into each output job.
    public var capabilities: TapeConsoleCapabilities
    /// Lowest severity forwarded to console output, independent of store history.
    public var minimumLevel: TapeLevel
    private let output: TapeConsoleOutput

    /// Creates a bounded asynchronous stdout destination. Copies share its worker.
    ///
    /// - Parameters:
    ///   - theme: Presentation palette.
    ///   - renderer: Text renderer; defaults to the open-right box renderer.
    ///   - capabilities: Presentation mode and width; detected by default.
    ///   - minimumLevel: Lowest forwarded severity; defaults to `.trace`.
    ///   - maximumPendingEntries: Positive queue capacity, excluding the active
    ///     write. New output is dropped when full; defaults to 256.
    public init(
        theme: TapeTheme = .default,
        renderer: any TapeTextRenderer = TapeBoxRenderer(),
        capabilities: TapeConsoleCapabilities = .detect(),
        minimumLevel: TapeLevel = .trace,
        maximumPendingEntries: Int = 256
    ) {
        self.theme = theme
        self.renderer = renderer
        self.capabilities = capabilities
        self.minimumLevel = minimumLevel
        self.output = TapeConsoleOutput(capacity: maximumPendingEntries)
    }

    /// A new sink with default theme, renderer and detected output capabilities.
    public static var `default`: TapeConsoleSink {
        TapeConsoleSink()
    }

    /// Enqueues an accepted entry without waiting for rendering or stdout.
    /// Output generated recursively by a renderer is suppressed across consoles.
    public func record(_ entry: TapeEntry) {
        guard entry.level >= minimumLevel else { return }
        let context = TapeRenderContext(theme: theme, capabilities: capabilities)
        output.enqueue(entry, renderer: renderer, context: context)
    }

    /// Number of console entries dropped because the output queue was full.
    /// Copies of a sink share their output worker and this counter.
    public var droppedEntryCount: UInt64 { output.droppedEntryCount }

    /// Waits until the worker is idle. A stalled stdout reader can keep this
    /// suspended, but never blocks recording or the calling thread.
    /// Cancellation does not end this wait. Call before tool exit, not from a
    /// renderer; process termination does not automatically drain queued jobs.
    ///
    /// ```swift
    /// let console = TapeConsoleSink()
    /// let logger = Tape(sinks: [console])
    /// logger.info("Finished")
    /// await console.flush()
    /// ```
    public func flush() async {
        await output.flush()
    }
}

/// One scheduled drain per burst, rather than one task per entry. User
/// renderers and stdout run outside the queue lock.
final class TapeConsoleOutput: Sendable {
    // A custom renderer can log too. As rendering is asynchronous, the
    // producer's recursion guard no longer covers it. Suppress console
    // delivery from rendering across all workers to prevent feedback loops.
    private static let renderingGuard = TapeReentrancyGuard()
    private struct Job: Sendable {
        let entry: TapeEntry
        let renderer: any TapeTextRenderer
        let context: TapeRenderContext
    }

    private struct State: Sendable {
        var jobs: [Job] = []
        var isDraining = false
        var dropped: UInt64 = 0
        var waiters: [CheckedContinuation<Void, Never>] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let queue = DispatchQueue(label: "TapeLogger.console")
    private let capacity: Int
    private let write: @Sendable (String) -> Void

    init(
        capacity: Int,
        write: @escaping @Sendable (String) -> Void = { print($0) }
    ) {
        precondition(capacity > 0, "maximumPendingEntries must be positive")
        self.capacity = capacity
        self.write = write
    }

    var droppedEntryCount: UInt64 { state.withLock { $0.dropped } }

    func enqueue(
        _ entry: TapeEntry,
        renderer: any TapeTextRenderer,
        context: TapeRenderContext
    ) {
        guard Self.renderingGuard.enter() else { return }
        defer { Self.renderingGuard.exit() }
        let shouldStart = state.withLock { state in
            guard state.jobs.count < capacity else {
                state.dropped &+= 1
                return false
            }
            state.jobs.append(Job(
                entry: entry, renderer: renderer, context: context
            ))
            guard !state.isDraining else { return false }
            state.isDraining = true
            return true
        }
        if shouldStart {
            queue.async { self.drain() }
        }
    }

    func flush() async {
        await withCheckedContinuation { continuation in
            let isIdle = state.withLock { state in
                guard state.isDraining else { return true }
                state.waiters.append(continuation)
                return false
            }
            if isIdle { continuation.resume() }
        }
    }

    private func drain() {
        while true {
            let (job, waiters) = state.withLock { state -> (
                Job?, [CheckedContinuation<Void, Never>]
            ) in
                if !state.jobs.isEmpty {
                    return (state.jobs.removeFirst(), [])
                }
                state.isDraining = false
                let waiters = state.waiters
                state.waiters = []
                return (nil, waiters)
            }
            guard let job else {
                for waiter in waiters { waiter.resume() }
                return
            }
            if Self.renderingGuard.enter() {
                write(job.renderer.render(job.entry, context: job.context))
                Self.renderingGuard.exit()
            }
        }
    }
}
