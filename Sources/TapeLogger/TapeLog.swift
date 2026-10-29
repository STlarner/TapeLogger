import Foundation

/// A custom log type: the app declares its header, its level and its style,
/// the way talker lets you subclass `TalkerLog`.
///
/// ```swift
/// struct NavigationLog: TapeLog {
///     let message: String
///
///     init(_ message: String) {
///         self.message = message
///     }
///
///     var title: String { "route" }
///     var level: TapeLevel { .debug }
///     var color: TapeColor? {
///         TapeColor(light: 0x7B1FA2, dark: 0xAF5FFF, ansi: 135, emoji: "🧭")
///     }
/// }
///
/// Tape.log(NavigationLog("Push RoomRoute"))
/// ```
///
/// Renderers and sinks only read the produced entry, so a custom type works
/// in the console, in the unified log and in the in-app UI with no extra
/// wiring.
public protocol TapeLog: Sendable {
    /// Body of the entry: the part the caller writes.
    var message: String { get }
    /// Header text, e.g. `route` or `payments`.
    var title: String { get }
    /// Identity of the stream. Defaults to ``title``; it is what
    /// `TapeTheme.keys` can override and what a UI filters on.
    var key: String { get }
    /// Severity of the entry. Defaults to `.info`.
    var level: TapeLevel { get }
    /// Badge and color. `nil` falls back to the level color.
    var color: TapeColor? { get }
    /// Extra key/value pairs, rendered on their own line.
    var metadata: [String: TapeValue] { get }
    /// Measured duration, when the entry comes from `measure`.
    var duration: Duration? { get }
    /// Expandable details shown under the message.
    var attachment: TapeAttachment? { get }
}

extension TapeLog {
    public var key: String { title }
    public var level: TapeLevel { .info }
    public var color: TapeColor? { nil }
    public var metadata: [String: TapeValue] { [:] }
    public var duration: Duration? { nil }
    public var attachment: TapeAttachment? { nil }

    /// Bridge to the internal model: a custom type is a key that carries its
    /// own message.
    var tapeKey: TapeKey {
        TapeKey(key, title: title, level: level, color: color)
    }
}
