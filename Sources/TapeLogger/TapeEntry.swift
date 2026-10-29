import Foundation

/// A single log record.
///
/// The entry is pure content: it never knows how it will be rendered.
/// Console text, UI cards and JSON export are all derived from this type,
/// which is why new destinations can be added without touching call sites.
public struct TapeEntry: Identifiable, Sendable {
    /// Identity used by UI lists; independent of date and sequence.
    public let id: UUID
    /// Ordering hint allocated by logger `log` calls or supplied by a producer.
    /// Allocation is monotonic per logger; concurrent calls may reach the store
    /// in a different order. Direct construction defaults to zero.
    public let sequence: UInt64
    /// Wall-clock creation time; elapsed measurements use `duration` instead.
    public let date: Date
    /// Severity used by logger, sink and UI filters.
    public let level: TapeLevel
    /// Category identity, display title and optional presentation style.
    public let key: TapeKey
    /// Human-readable summary, stored without automatic redaction.
    public let message: String
    /// Structured diagnostic context, stored without automatic redaction.
    public let metadata: [String: TapeValue]
    /// Caller location, if supplied by a logger or custom producer.
    public let source: TapeSource?
    /// Optional elapsed time associated with the event.
    public let duration: Duration?
    /// Typed detail shown by the UI and built-in text destinations.
    public let attachment: TapeAttachment?

    /// Creates content without recording it. Pass it to a logger's `record`.
    ///
    /// ```swift
    /// let entry = TapeEntry(level: .info, message: "Cache ready")
    /// let logger = Tape(sinks: [])
    /// logger.record(entry)
    /// ```
    ///
    /// - Parameters:
    ///   - id: Stable entry identity; defaults to a new UUID.
    ///   - sequence: Producer ordering hint; defaults to zero.
    ///   - date: Wall-clock creation time; defaults to now.
    ///   - level: Event severity.
    ///   - key: Category; defaults to `.log`.
    ///   - message: Human-readable summary.
    ///   - metadata: Structured context; defaults to empty.
    ///   - source: Optional caller location.
    ///   - duration: Optional elapsed time.
    ///   - attachment: Optional detailed payload.
    public init(
        id: UUID = UUID(),
        sequence: UInt64 = 0,
        date: Date = .now,
        level: TapeLevel,
        key: TapeKey = .log,
        message: String,
        metadata: [String: TapeValue] = [:],
        source: TapeSource? = nil,
        duration: Duration? = nil,
        attachment: TapeAttachment? = nil
    ) {
        self.id = id
        self.sequence = sequence
        self.date = date
        self.level = level
        self.key = key
        self.message = message
        self.metadata = metadata
        self.source = source
        self.duration = duration
        self.attachment = attachment
    }
}

// MARK: - Source

/// A captured caller location. Logger defaults capture it at the call site.
public struct TapeSource: Sendable, Hashable {
    /// File identifier, usually `#fileID`, rather than an absolute path.
    public let file: String
    /// Function name, usually `#function`.
    public let function: String
    /// One-based source line, usually `#line`.
    public let line: Int

    /// Captures the current call site or accepts an explicit producer location.
    ///
    /// - Parameters:
    ///   - file: File identifier.
    ///   - function: Function name.
    ///   - line: One-based line number.
    public init(file: String = #fileID, function: String = #function, line: Int = #line) {
        self.file = file
        self.function = function
        self.line = line
    }

    /// `Tape.swift:42`
    public var short: String {
        let name = file.split(separator: "/").last.map(String.init) ?? file
        return "\(name):\(line)"
    }
}

// MARK: - Attachment

/// Typed payload for the detail screen, so the UI can render structured
/// content instead of a blob of text.
public enum TapeAttachment: Sendable {
    /// A structured HTTP exchange, already sanitized by its producer.
    case http(TapeHTTPExchange)
    /// An error description; the original error object is not retained.
    case error(String)
    /// An explicitly supplied stack trace; no stack is captured automatically.
    case stackTrace(String)
    /// App-defined payload with a semantic identifier and plain-text content.
    case custom(id: String, payload: String)
}

/// Request and optional response details captured by a network producer.
///
/// This value does not perform I/O or redact content. Network adapters sanitize
/// their output before constructing it; custom producers must do the same.
public struct TapeHTTPExchange: Sendable {
    /// Headers and an optional bounded body preview for one side of an exchange.
    public struct Side: Sendable {
        /// Captured header values; sensitive fields should already be redacted.
        public var headers: [String: String]
        /// Optional text preview, not necessarily the complete body.
        public var body: String?
        /// Known body byte count, which may exceed the preview size.
        public var bodySize: Int?

        /// Creates one side without capturing or transforming traffic.
        ///
        /// - Parameters:
        ///   - headers: Already-sanitized header values.
        ///   - body: Optional text preview or capture explanation.
        ///   - bodySize: Optional known byte count; zero denotes an empty body.
        public init(
            headers: [String: String] = [:],
            body: String? = nil,
            bodySize: Int? = nil
        ) {
            self.headers = headers
            self.body = body
            self.bodySize = bodySize
        }
    }

    /// HTTP method, such as `GET` or `POST`.
    public var method: String
    /// URL text, with credentials and sensitive query values removed by adapters.
    public var url: String
    /// Response status when available; transport failures may have none.
    public var statusCode: Int?
    /// Request headers and optional body preview.
    public var request: Side
    /// Response details, absent before a response or after some transport errors.
    public var response: Side?

    /// Creates an exchange from captured or explicitly supplied content.
    ///
    /// - Parameters:
    ///   - method: HTTP method.
    ///   - url: Already-sanitized URL string.
    ///   - statusCode: Optional response status.
    ///   - request: Request details, empty by default.
    ///   - response: Optional response details.
    public init(
        method: String,
        url: String,
        statusCode: Int? = nil,
        request: Side = Side(),
        response: Side? = nil
    ) {
        self.method = method
        self.url = url
        self.statusCode = statusCode
        self.request = request
        self.response = response
    }

    /// Shared by text destinations so neither side of an exchange is lost.
    package var bodyText: String {
        var sections: [String] = []
        if let body = request.body {
            sections.append("Request body:\n\(body)")
        }
        if let body = response?.body {
            sections.append("Response body:\n\(body)")
        }
        return sections.joined(separator: "\n\n")
    }

    /// Includes the sanitized headers captured by adapters, not raw traffic.
    package var detailText: String {
        var text = "\(method) \(url)"
        if let statusCode { text += " → \(statusCode)" }
        for (title, side) in [
            ("Request headers", Optional(request)),
            ("Response headers", response),
        ] {
            guard let side, !side.headers.isEmpty else { continue }
            let headers = side.headers.sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            text += "\n\n\(title):\n\(headers)"
        }
        if !bodyText.isEmpty { text += "\n\n\(bodyText)" }
        return text
    }
}

extension TapeAttachment {
    /// Shared by copy/export and built-in text destinations.
    package var text: String {
        switch self {
        case .error(let description): description
        case .stackTrace(let trace): trace
        case .custom(_, let payload): payload
        case .http(let exchange): exchange.detailText
        }
    }
}

// MARK: - Copy / export

extension TapeEntry {
    /// Plain text used by copying and unified logging. Includes time, severity,
    /// category, message, metadata, duration and attachments, but not source.
    /// This does not write a file or redact content.
    public var copyText: String {
        var text = "[\(heading)] | \(TapeTimeFormatter.string(from: date))"
        if let duration {
            text += " | \(duration.tapeMilliseconds)ms"
        }
        text += "\n\(message)"
        if !metadata.isEmpty {
            let sorted = metadata.sorted { $0.key < $1.key }
            text += "\n" + sorted.map { "  \($0.key): \($0.value.description)" }.joined(separator: "\n")
        }
        if let attachment { text += "\n\n\(attachment.text)" }
        return text
    }
}

extension TapeEntry {
    /// The key title, or `nil` for the default `.log` key.
    ///
    /// The default key has nothing to say: printing "log" in front of every
    /// entry that came from `Tape.info("...")` hides the level, which is the
    /// only thing the reader actually needs. Renderers show the level instead
    /// and add the key only when it carries information.
    public var keyTitle: String? {
        key.id == TapeKey.log.id ? nil : key.title
    }

    /// Level first, then the key when it says something: `debug` or
    /// `error · http-request`.
    public var heading: String {
        guard let keyTitle else { return level.label }
        return "\(level.label) · \(keyTitle)"
    }
}
