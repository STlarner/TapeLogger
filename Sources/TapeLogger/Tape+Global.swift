public extension Tape {
    /// `Tape.shared` behind unqualified calls, so a call site reads
    /// `Tape.info("...")` instead of `Tape.shared.info("...")`.
    ///
    /// Every forwarder keeps the caller's source location: the defaults are
    /// evaluated where the call is written, not inside this file.

    static func record(_ entry: TapeEntry) {
        shared.record(entry)
    }

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

    static func log(
        _ customLog: some TapeLog,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        shared.log(customLog, file: file, function: function, line: line)
    }

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
