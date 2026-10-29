import Foundation

/// A semantic category for a log entry: a log type anyone can define.
///
/// A key carries everything needed to present its stream — title, default
/// level, and an optional color with its own emoji — so a custom log type
/// works out of the box, with no theme edits:
///
/// ```swift
/// extension TapeKey {
///     static let payments = TapeKey(
///         "payments",
///         level: .notice,
///         color: TapeColor(light: 0x1B8A3A, dark: 0x30D158, ansi: 40, emoji: "💳")
///     )
/// }
///
/// Tape.notice("charged 12.00", key: .payments)
/// ```
///
/// A theme can still override the color per key (`TapeTheme.keys`), which is
/// how an app rebrands a stream without touching the call sites.
public struct TapeKey: Hashable, Sendable, ExpressibleByStringLiteral {
    /// Category identity, used for equality, hashing and theme overrides.
    public let id: String
    /// Display title; may differ from the stable identity.
    public let title: String
    /// Default severity when a call does not provide an explicit level.
    public let level: TapeLevel
    /// Style of this log type. `nil` means "use the level color".
    public let color: TapeColor?

    /// Defines a category without registering it globally.
    ///
    /// - Parameters:
    ///   - id: Stable category identity.
    ///   - title: Display name; defaults to `id`.
    ///   - level: Default severity; defaults to `.info`.
    ///   - color: Optional style; `nil` uses the resolved entry level's color.
    public init(
        _ id: String,
        title: String? = nil,
        level: TapeLevel = .info,
        color: TapeColor? = nil
    ) {
        self.id = id
        self.title = title ?? id
        self.level = level
        self.color = color
    }

    /// Creates an info-level category whose identity and title are the literal.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// Identity is the id: the same category built twice with different
    /// styling is still the same category.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Compares identity only, ignoring title, severity and styling.
    public static func == (lhs: TapeKey, rhs: TapeKey) -> Bool {
        lhs.id == rhs.id
    }

    /// Generic key used when the caller does not provide one.
    public static let log = TapeKey("log")

    // MARK: - Built-in keys

    /// Outgoing HTTP requests, identified by `http.request`.
    public static let httpRequest = TapeKey(
        "http.request",
        title: "http-request",
        color: httpColor(emoji: "📤")
    )
    /// Incoming HTTP responses, sharing the request color with a distinct badge.
    public static let httpResponse = TapeKey(
        "http.response",
        title: "http-response",
        color: httpColor(emoji: "📥")
    )
    /// HTTP failures, with error severity and a dedicated failure badge.
    public static let httpError = TapeKey(
        "http.error",
        title: "http-error",
        level: .error,
        color: TapeColor(light: 0xD32F2F, dark: 0xFF453A, ansi: 203, emoji: "💥")
    )
    /// Navigation changes, displayed as `route` at debug severity by default.
    public static let navigation = TapeKey(
        "navigation",
        title: "route",
        level: .debug,
        color: TapeColor(light: 0x7B1FA2, dark: 0xAF5FFF, ansi: 135, emoji: "🧭")
    )
    /// Storage and cache events, at debug severity by default.
    public static let storage = TapeKey(
        "storage",
        level: .debug,
        color: TapeColor(light: 0x00695C, dark: 0x64D2FF, ansi: 80, emoji: "💾")
    )
    /// Application and scene lifecycle events, at debug severity by default.
    public static let lifecycle = TapeKey("lifecycle", level: .debug)

    private static func httpColor(emoji: String) -> TapeColor {
        TapeColor(
            light: 0xC218B5, dark: 0xF602C1, ansi: 200, emoji: emoji
        )
    }
}
