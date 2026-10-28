import Foundation
import os

/// Facade and hot path.
///
/// ```swift
/// Tape.info("app launched")
/// Tape.warning("cache miss", metadata: ["key": "feed"])
/// Tape.error(error)
/// ```
///
/// Sendable on purpose: logs can be written from any thread or task.
public final class Tape: Sendable {
    /// Shared instance with a console sink attached.
    public static let shared = Tape()

    public let store: TapeStore

    private struct State: Sendable {
        var sinks: [any TapeSink]
        var minimumLevel: TapeLevel = .trace
        var isEnabled = true
        var nextSequence: UInt64 = 0
    }

    private let state: OSAllocatedUnfairLock<State>
    private let reentrancy = TapeReentrancyGuard()

    /// - Parameter sinks: `nil` installs a console sink with auto-detected
    ///   capabilities (ANSI in a terminal, emoji in Xcode). Pass `[]` to
    ///   start silent.
    public init(sinks: [any TapeSink]? = nil, store: TapeStore = TapeStore()) {
        self.store = store
        self.state = OSAllocatedUnfairLock(
            initialState: State(sinks: sinks ?? [TapeConsoleSink.default])
        )
    }

    // MARK: - Configuration

    public var minimumLevel: TapeLevel {
        get { state.withLock { $0.minimumLevel } }
        set { state.withLock { $0.minimumLevel = newValue } }
    }

    public var isEnabled: Bool {
        get { state.withLock { $0.isEnabled } }
        set { state.withLock { $0.isEnabled = newValue } }
    }

    public var sinks: [any TapeSink] {
        state.withLock { $0.sinks }
    }

    public func addSink(_ sink: any TapeSink) {
        state.withLock { $0.sinks.append(sink) }
    }

    public func removeAllSinks() {
        state.withLock { $0.sinks.removeAll() }
    }

    // MARK: - Recording

    /// Low-level entry point: every log call ends up here.
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

    /// Records a custom log type: the type brings its own header, level,
    /// color and metadata, so the call site never names a level.
    ///
    /// ```swift
    /// Tape.log(NavigationLog("Push RoomRoute"))
    /// ```
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

    public func trace(_ message: String, key: TapeKey? = nil, metadata: [String: TapeValue] = [:],
                      file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .trace, key: key, metadata: metadata, file: file, function: function, line: line)
    }

    public func debug(_ message: String, key: TapeKey? = nil, metadata: [String: TapeValue] = [:],
                      file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .debug, key: key, metadata: metadata, file: file, function: function, line: line)
    }

    public func info(_ message: String, key: TapeKey? = nil, metadata: [String: TapeValue] = [:],
                     file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .info, key: key, metadata: metadata, file: file, function: function, line: line)
    }

    public func notice(_ message: String, key: TapeKey? = nil, metadata: [String: TapeValue] = [:],
                       file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .notice, key: key, metadata: metadata, file: file, function: function, line: line)
    }

    public func warning(_ message: String, key: TapeKey? = nil, metadata: [String: TapeValue] = [:],
                        file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .warning, key: key, metadata: metadata, file: file, function: function, line: line)
    }

    public func error(_ error: any Error, key: TapeKey? = nil, metadata: [String: TapeValue] = [:],
                      file: String = #fileID, function: String = #function, line: Int = #line) {
        let description = String(describing: error)
        log(description, level: .error, key: key, metadata: metadata,
            attachment: .error(description), file: file, function: function, line: line)
    }

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

    public func critical(_ message: String, key: TapeKey? = nil, metadata: [String: TapeValue] = [:],
                         file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .critical, key: key, metadata: metadata, file: file, function: function, line: line)
    }

    public func fault(_ message: String, key: TapeKey? = nil, metadata: [String: TapeValue] = [:],
                      file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .fault, key: key, metadata: metadata, file: file, function: function, line: line)
    }

    // MARK: - Measurement

    /// Logs once the body returns, with the measured duration.
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

    /// Async variant of ``measure(_:key:metadata:file:function:line:_:)``.
    @discardableResult
    public func measure<T>(
        _ label: String,
        key: TapeKey? = nil,
        metadata: [String: TapeValue] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line,
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
