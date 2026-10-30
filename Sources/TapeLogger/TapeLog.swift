import Foundation

/// An app-defined log type with a category, severity and optional color.
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
/// Tape.log(NavigationLog("Open settings"))
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
    /// Category identity. Defaults to ``title`` and indexes `TapeTheme.keys`
    /// overrides independently of this entry's severity or display title.
    var key: String { get }
    /// Severity of the entry. Defaults to `.info`.
    var level: TapeLevel { get }
    /// Badge and color. `nil` falls back to the level color.
    var color: TapeColor? { get }
    /// Extra key/value pairs, rendered on their own line.
    var metadata: [String: TapeValue] { get }
    /// Optional elapsed time supplied by the custom log.
    var duration: Duration? { get }
    /// Expandable details shown under the message.
    var attachment: TapeAttachment? { get }
}

extension TapeLog {
    /// Defaults category identity to the custom log's display title.
    public var key: String { title }
    /// Defaults custom logs to info severity.
    public var level: TapeLevel { .info }
    /// Defaults to no category color, allowing the severity palette to resolve it.
    public var color: TapeColor? { nil }
    /// Defaults to empty structured context.
    public var metadata: [String: TapeValue] { [:] }
    /// Defaults to no measured duration.
    public var duration: Duration? { nil }
    /// Defaults to no expanded attachment.
    public var attachment: TapeAttachment? { nil }

    /// Bridge to the internal model: a custom type is a key that carries its
    /// own message.
    var tapeKey: TapeKey {
        TapeKey(key, title: title, level: level, color: color)
    }
}
