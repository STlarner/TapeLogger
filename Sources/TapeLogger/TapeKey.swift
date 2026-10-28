import Foundation

/// A semantic category for a log entry.
///
/// A key carries the *presentation* defaults (title, level) while the
/// theme carries the color. Keeping the two apart means a key can be
/// registered by an adapter without knowing anything about styling.
///
/// ```swift
/// let payments = TapeKey("payments", title: "payments", level: .notice)
/// Tape.info("charged", key: payments)
/// ```
public struct TapeKey: Hashable, Sendable, ExpressibleByStringLiteral {
    public let id: String
    public let title: String
    public let level: TapeLevel

    public init(_ id: String, title: String? = nil, level: TapeLevel = .info) {
        self.id = id
        self.title = title ?? id
        self.level = level
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// Generic key used when the caller does not provide one.
    public static let log = TapeKey("log")

    // MARK: - Built-in keys

    public static let httpRequest = TapeKey("http.request", title: "http-request")
    public static let httpResponse = TapeKey("http.response", title: "http-response")
    public static let httpError = TapeKey("http.error", title: "http-error", level: .error)
    public static let navigation = TapeKey("navigation", title: "route", level: .debug)
    public static let storage = TapeKey("storage", level: .debug)
    public static let lifecycle = TapeKey("lifecycle", level: .debug)
}
