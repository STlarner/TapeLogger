import Foundation

/// A single log record.
///
/// The entry is pure content: it never knows how it will be rendered.
/// Console text, UI cards and JSON export are all derived from this type,
/// which is why new destinations can be added without touching call sites.
public struct TapeEntry: Identifiable, Sendable {
    public let id: UUID
    /// Monotonic tie-breaker: `Date` alone can collide inside the same
    /// millisecond and make the timeline reorder itself.
    public let sequence: UInt64
    public let date: Date
    public let level: TapeLevel
    public let key: TapeKey
    public let message: String
    public let metadata: [String: TapeValue]
    public let source: TapeSource?
    public let duration: Duration?
    public let attachment: TapeAttachment?

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

public struct TapeSource: Sendable, Hashable {
    public let file: String
    public let function: String
    public let line: Int

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
    case http(TapeHTTPExchange)
    case error(String)
    case stackTrace(String)
    case custom(id: String, payload: String)
}

public struct TapeHTTPExchange: Sendable {
    public struct Side: Sendable {
        public var headers: [String: String]
        public var body: String?
        public var bodySize: Int?

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

    public var method: String
    public var url: String
    public var statusCode: Int?
    public var request: Side
    public var response: Side?

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
}

// MARK: - Copy / export

extension TapeEntry {
    /// Plain text representation used by the copy button and by file export.
    public var copyText: String {
        var text = "[\(level.label)] \(key.title) | \(TapeTimeFormatter.string(from: date))"
        if let duration {
            text += " | \(duration.tapeMilliseconds)ms"
        }
        text += "\n\(message)"
        if !metadata.isEmpty {
            let sorted = metadata.sorted { $0.key < $1.key }
            text += "\n" + sorted.map { "  \($0.key): \($0.value.description)" }.joined(separator: "\n")
        }
        switch attachment {
        case .error(let description):
            text += "\n\n\(description)"
        case .stackTrace(let trace):
            text += "\n\n\(trace)"
        case .http(let exchange):
            text += "\n\n\(exchange.method) \(exchange.url)"
            if let statusCode = exchange.statusCode {
                text += " → \(statusCode)"
            }
            if let body = exchange.response?.body {
                text += "\n\(body)"
            }
        case .custom(_, let payload):
            text += "\n\n\(payload)"
        case .none:
            break
        }
        return text
    }
}
