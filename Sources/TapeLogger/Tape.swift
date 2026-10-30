import Foundation
import os

/// A thread-safe logger with bounded history and configurable destinations.
///
/// ```swift
/// Tape.info("app launched")
/// Tape.warning("cache miss", metadata: ["key": "feed"])
/// let logger = Tape(sinks: [])
/// logger.info("Stored without console output")
/// ```
///
/// Sendable on purpose: logs can be written from any thread or task.
public final class Tape: Sendable {
    /// Shared instance, initially configured with a console sink.
    public static let shared = Tape()

    /// History receiving accepted entries, independently of sink delivery.
    public let store: TapeStore

    private struct State: Sendable {
        var sinks: [any TapeSink]
        var minimumLevel: TapeLevel = .trace
        var isEnabled = true
        var nextSequence: UInt64 = 0
    }

    private let state: OSAllocatedUnfairLock<State>
    private let reentrancy = TapeReentrancyGuard()

    /// Creates an independent logger. Configuration changes are lock-protected.
    ///
    /// - Parameters:
    ///   - sinks: Destinations. `nil` installs an auto-detected console sink;
    ///     `[]` retains history without forwarding output.
    ///   - store: History to retain accepted entries in. Defaults to a new store.
    public init(sinks: [any TapeSink]? = nil, store: TapeStore = TapeStore()) {
        self.store = store
        self.state = OSAllocatedUnfairLock(
            initialState: State(sinks: sinks ?? [TapeConsoleSink.default])
        )
    }

    // MARK: - Configuration

    /// Lowest accepted severity, initially `.trace`. Filtering affects both
    /// history and sinks; individual sinks may impose a higher threshold.
    public var minimumLevel: TapeLevel {
        get { state.withLock { $0.minimumLevel } }
        set { state.withLock { $0.minimumLevel = newValue } }
    }

    /// Whether recording is enabled, initially `true`. Disabling preserves
    /// existing history but rejects new entries before sink delivery.
    public var isEnabled: Bool {
        get { state.withLock { $0.isEnabled } }
        set { state.withLock { $0.isEnabled = newValue } }
    }

    /// A snapshot of the current destinations, in delivery order.
    public var sinks: [any TapeSink] {
        state.withLock { $0.sinks }
    }

    /// Appends a retained destination. Adding the same sink twice duplicates
    /// delivery; already-recording calls use their existing sink snapshot.
    public func addSink(_ sink: any TapeSink) {
        state.withLock { $0.sinks.append(sink) }
    }

    /// Detaches every destination without clearing history or flushing output.
    /// In-flight recordings may still deliver to their copied sink list.
    public func removeAllSinks() {
        let removed = state.withLock { state in
            let removed = state.sinks
            state.sinks = []
            return removed
        }
        // A sink's destructor may log. Its last release must be unlocked too.
        withExtendedLifetime(removed) {}
    }

    // MARK: - Recording

    /// Records an already-constructed entry without changing its identity,
    /// date, sequence or source.
    ///
    /// Disabled or below-threshold entries are discarded. Accepted entries
    /// enter history before sinks run synchronously, outside the logger lock.
    /// Recursive recording by a sink on the same thread is suppressed.
    /// Concurrent producers need not arrive in sequence-number order.
    ///
    /// - Parameter entry: Content to record. Custom sinks must not block.
    public func record(_ entry: TapeEntry) {
        let config = state.withLock {
            (isEnabled: $0.isEnabled, minimumLevel: $0.minimumLevel, sinks: $0.sinks)
        }
        guard config.isEnabled, entry.level >= config.minimumLevel else { return }

        guard reentrancy.enter() else { return }
        defer { reentrancy.exit() }

        store.append(entry)
        // Sinks run outside the lock: they are allowed to call back into Tape.
        for sink in config.sinks {
            sink.record(entry)
        }
    }

    // MARK: - API

    /// Creates and records an entry with automatically captured source location.
    ///
    /// - Parameters:
    ///   - message: Human-readable event summary.
    ///   - level: Severity; defaults to the key's level, then `.info`.
    ///   - key: Category; defaults to the generic `.log` key.
    ///   - metadata: Structured context, retained without automatic redaction.
    ///   - duration: Optional elapsed time to display beside the event.
    ///   - attachment: Optional error, stack trace, HTTP exchange or payload.
    ///   - file: Caller file identifier, captured by default.
    ///   - function: Caller function name, captured by default.
    ///   - line: Caller line number, captured by default.
    public func log(
        _ message: String,
        level: TapeLevel? = nil,
        key: TapeKey? = nil,
        metadata: [String: TapeValue] = [:],
        duration: Duration? = nil,
        attachment: TapeAttachment? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        let resolvedKey = key ?? .log
        let resolvedLevel = level ?? key?.level ?? .info
        let sequence = state.withLock { state -> UInt64 in
            defer { state.nextSequence += 1 }
            return state.nextSequence
        }

        record(
            TapeEntry(
                sequence: sequence,
                level: resolvedLevel,
                key: resolvedKey,
                message: message,
                metadata: metadata,
                source: TapeSource(file: file, function: function, line: line),
                duration: duration,
                attachment: attachment
            )
        )
    }

    /// Records a custom log's category, severity, style and content.
    ///
    /// ```swift
    /// struct EventLog: TapeLog {
    ///     let message: String
    ///     var title: String { "events" }
    /// }
    /// Tape.log(EventLog(message: "Cache ready"))
    /// ```
    ///
    /// - Parameters:
    ///   - customLog: Value providing content, category, severity and style.
    ///   - file: Caller file identifier.
    ///   - function: Caller function name.
    ///   - line: Caller line number.
    public func log(
        _ customLog: some TapeLog,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            customLog.message,
            level: customLog.level,
            key: customLog.tapeKey,
            metadata: customLog.metadata,
            duration: customLog.duration,
            attachment: customLog.attachment,
            file: file,
            function: function,
            line: line
        )
    }

    /// Records a trace message. The explicit severity overrides the key's level;
    /// metadata and default source arguments behave as in `log`.
    public func trace(_ message: String, key: TapeKey? = nil, metadata: [String: TapeValue] = [:],
                      file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .trace, key: key, metadata: metadata, file: file, function: function, line: line)
    }

    /// Records diagnostic detail at debug severity, capturing the call site.
    public func debug(_ message: String, key: TapeKey? = nil, metadata: [String: TapeValue] = [:],
                      file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .debug, key: key, metadata: metadata, file: file, function: function, line: line)
    }

    /// Records an informational event, capturing source and optional context.
    public func info(_ message: String, key: TapeKey? = nil, metadata: [String: TapeValue] = [:],
                     file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .info, key: key, metadata: metadata, file: file, function: function, line: line)
    }

    /// Records a noteworthy, non-error event at notice severity.
    public func notice(_ message: String, key: TapeKey? = nil, metadata: [String: TapeValue] = [:],
                       file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .notice, key: key, metadata: metadata, file: file, function: function, line: line)
    }

    /// Records a recoverable problem or unexpected condition at warning severity.
    public func warning(_ message: String, key: TapeKey? = nil, metadata: [String: TapeValue] = [:],
                        file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .warning, key: key, metadata: metadata, file: file, function: function, line: line)
    }

    /// Records an error's description as both message and error attachment.
    /// Use the message-and-error overload to supply a separate summary.
    public func error(_ error: any Error, key: TapeKey? = nil, metadata: [String: TapeValue] = [:],
                      file: String = #fileID, function: String = #function, line: Int = #line) {
        let description = String(describing: error)
        log(description, level: .error, key: key, metadata: metadata,
            attachment: .error(description), file: file, function: function, line: line)
    }

    /// Records an error-severity message without creating an attachment.
    public func error(_ message: String, key: TapeKey? = nil, metadata: [String: TapeValue] = [:],
                      file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .error, key: key, metadata: metadata, file: file, function: function, line: line)
    }

    /// Keeps the message short and the error details as an expandable
    /// attachment, instead of flattening both into one line.
    public func error(_ message: String, error: any Error, key: TapeKey? = nil,
                      metadata: [String: TapeValue] = [:],
                      file: String = #fileID, function: String = #function, line: Int = #line) {
        let description = String(describing: error)
        log(message, level: .error, key: key, metadata: metadata,
            attachment: .error(description), file: file, function: function, line: line)
    }

    /// Records a critical failure without throwing or terminating the process.
    public func critical(_ message: String, key: TapeKey? = nil, metadata: [String: TapeValue] = [:],
                         file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .critical, key: key, metadata: metadata, file: file, function: function, line: line)
    }

    /// Records the highest severity without asserting or terminating the process.
    public func fault(_ message: String, key: TapeKey? = nil, metadata: [String: TapeValue] = [:],
                      file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .fault, key: key, metadata: metadata, file: file, function: function, line: line)
    }

    // MARK: - Measurement

    /// Executes synchronous work and records its elapsed time at debug severity.
    ///
    /// The debug entry is emitted on return or throw and obeys normal filtering.
    /// The body's return value or error is passed through unchanged.
    ///
    /// ```swift
    /// let logger = Tape(sinks: [])
    /// let sorted = logger.measure("Sort") { [3, 1, 2].sorted() }
    /// ```
    ///
    /// - Parameters:
    ///   - label: Summary for the duration entry.
    ///   - key: Optional category; severity remains debug.
    ///   - metadata: Context attached to the duration entry.
    ///   - file: Caller file identifier.
    ///   - function: Caller function name.
    ///   - line: Caller line number.
    ///   - body: Synchronous work to run once.
    /// - Returns: The body's result.
    /// - Throws: The body's error, after recording elapsed time.
    @discardableResult
    public func measure<T>(
        _ label: String,
        key: TapeKey? = nil,
        metadata: [String: TapeValue] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line,
        _ body: () throws -> T
    ) rethrows -> T {
        let clock = ContinuousClock()
        let start = clock.now
        defer {
            log(label, level: .debug, key: key, metadata: metadata,
                duration: clock.now - start, file: file, function: function, line: line)
        }
        return try body()
    }

    /// Async variant of synchronous measurement, preserving caller isolation.
    ///
    /// Preserves the calling actor's isolation and permits non-Sendable results.
    /// Time includes suspension; cancellation is handled by the body, not by
    /// the logger. An entry is recorded whether the body returns or throws.
    ///
    /// - Parameters:
    ///   - label: Summary for the duration entry.
    ///   - key: Optional category; severity remains debug.
    ///   - metadata: Context attached to the duration entry.
    ///   - file: Caller file identifier.
    ///   - function: Caller function name.
    ///   - line: Caller line number.
    ///   - isolation: Caller isolation, inferred automatically.
    ///   - body: Asynchronous work to run once.
    /// - Returns: The body's result without sending it to another actor.
    /// - Throws: The body's error, after recording elapsed time.
    @discardableResult
    public func measure<T>(
        _ label: String,
        key: TapeKey? = nil,
        metadata: [String: TapeValue] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line,
        isolation: isolated (any Actor)? = #isolation,
        _ body: () async throws -> T
    ) async rethrows -> T {
        let clock = ContinuousClock()
        let start = clock.now
        defer {
            log(label, level: .debug, key: key, metadata: metadata,
                duration: clock.now - start, file: file, function: function, line: line)
        }
        return try await body()
    }
}
