public extension Tape {
    /// Records a constructed entry on `Tape.shared`, retaining its source and
    /// identity. Shared logger filters and recursion protection still apply.
    static func record(_ entry: TapeEntry) {
        shared.record(entry)
    }

    /// Creates an entry on `Tape.shared`, using the caller's source location.
    /// Severity defaults to the key's level, then `.info`; content is not
    /// automatically redacted. See the instance `log` overload for parameters.
    static func log(
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
        shared.log(
            message,
            level: level,
            key: key,
            metadata: metadata,
            duration: duration,
            attachment: attachment,
            file: file,
            function: function,
            line: line
        )
    }

    /// Records a custom log value on `Tape.shared`, retaining its category,
    /// severity, style, metadata and attachment with the caller's source.
    static func log(
        _ customLog: some TapeLog,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        shared.log(customLog, file: file, function: function, line: line)
    }

    /// Records trace-level detail on `Tape.shared` with caller source context.
    static func trace(
        _ message: String,
        key: TapeKey? = nil,
        metadata: [String: TapeValue] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        shared.trace(message, key: key, metadata: metadata,
                     file: file, function: function, line: line)
    }

    /// Records a debug event on `Tape.shared` with caller source context.
    static func debug(
        _ message: String,
        key: TapeKey? = nil,
        metadata: [String: TapeValue] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        shared.debug(message, key: key, metadata: metadata,
                     file: file, function: function, line: line)
    }

    /// Records an informational event on `Tape.shared`.
    static func info(
        _ message: String,
        key: TapeKey? = nil,
        metadata: [String: TapeValue] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        shared.info(message, key: key, metadata: metadata,
                    file: file, function: function, line: line)
    }

    /// Records a noteworthy, non-error event on `Tape.shared`.
    static func notice(
        _ message: String,
        key: TapeKey? = nil,
        metadata: [String: TapeValue] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        shared.notice(message, key: key, metadata: metadata,
                      file: file, function: function, line: line)
    }

    /// Records a warning on `Tape.shared` without changing control flow.
    static func warning(
        _ message: String,
        key: TapeKey? = nil,
        metadata: [String: TapeValue] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        shared.warning(message, key: key, metadata: metadata,
                       file: file, function: function, line: line)
    }

    /// Records an error's description and attachment on `Tape.shared`.
    static func error(
        _ error: any Error,
        key: TapeKey? = nil,
        metadata: [String: TapeValue] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        shared.error(error, key: key, metadata: metadata,
                     file: file, function: function, line: line)
    }

    /// Records an error-severity message on `Tape.shared` without an attachment.
    static func error(
        _ message: String,
        key: TapeKey? = nil,
        metadata: [String: TapeValue] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        shared.error(message, key: key, metadata: metadata,
                     file: file, function: function, line: line)
    }

    /// Records a short summary and separate error attachment on `Tape.shared`.
    static func error(
        _ message: String,
        error: any Error,
        key: TapeKey? = nil,
        metadata: [String: TapeValue] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        shared.error(message, error: error, key: key, metadata: metadata,
                     file: file, function: function, line: line)
    }

    /// Records a critical event on `Tape.shared` without terminating the app.
    static func critical(
        _ message: String,
        key: TapeKey? = nil,
        metadata: [String: TapeValue] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        shared.critical(message, key: key, metadata: metadata,
                        file: file, function: function, line: line)
    }

    /// Records a fault on `Tape.shared` without asserting or terminating.
    static func fault(
        _ message: String,
        key: TapeKey? = nil,
        metadata: [String: TapeValue] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        shared.fault(message, key: key, metadata: metadata,
                     file: file, function: function, line: line)
    }

    /// Measures synchronous work using `Tape.shared`. Records debug-level
    /// elapsed time on return or throw; forwards the body's result or error.
    @discardableResult
    static func measure<T>(
        _ label: String,
        key: TapeKey? = nil,
        metadata: [String: TapeValue] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line,
        _ body: () throws -> T
    ) rethrows -> T {
        try shared.measure(label, key: key, metadata: metadata,
                           file: file, function: function, line: line, body)
    }

    /// Measures asynchronous work using `Tape.shared`, preserving caller actor
    /// isolation. Records elapsed time including suspension on return or throw.
    @discardableResult
    static func measure<T>(
        _ label: String,
        key: TapeKey? = nil,
        metadata: [String: TapeValue] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line,
        isolation: isolated (any Actor)? = #isolation,
        _ body: () async throws -> T
    ) async rethrows -> T {
        try await shared.measure(label, key: key, metadata: metadata,
                                 file: file, function: function, line: line,
                                 isolation: isolation,
                                 body)
    }
}
