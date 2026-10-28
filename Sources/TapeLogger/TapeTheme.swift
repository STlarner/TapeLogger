import Foundation

/// A color that knows how to present itself everywhere it may end up.
///
/// Xcode's debug console strips ANSI escape codes, so `ansi` alone is not
/// enough: `emoji` is the fallback that survives Xcode, and `light`/`dark`
/// are used by SwiftUI.
public struct TapeColor: Sendable, Hashable {
    public var light: UInt32
    public var dark: UInt32
    /// xterm-256 palette index, used in `.ansi` mode.
    public var ansi: UInt8
    public var emoji: String?

    public init(light: UInt32, dark: UInt32, ansi: UInt8, emoji: String? = nil) {
        self.light = light
        self.dark = dark
        self.ansi = ansi
        self.emoji = emoji
    }
}

/// Semantic palette. Renderers never hardcode a color: they ask the theme.
public struct TapeTheme: Sendable {
    public var background: TapeColor
    public var card: TapeColor
    public var text: TapeColor
    public var secondary: TapeColor
    public var levels: [TapeLevel: TapeColor]
    /// Per-key override. Wins over the color the key carries itself, so an
    /// app can rebrand a stream without touching the call sites.
    public var keys: [String: TapeColor]

    public init(
        background: TapeColor,
        card: TapeColor,
        text: TapeColor,
        secondary: TapeColor,
        levels: [TapeLevel: TapeColor],
        keys: [String: TapeColor] = [:]
    ) {
        self.background = background
        self.card = card
        self.text = text
        self.secondary = secondary
        self.levels = levels
        self.keys = keys
    }

    /// Resolution order: theme override, then the color the key carries,
    /// then the level color. A custom log type therefore needs no theme.
    public func color(for entry: TapeEntry) -> TapeColor {
        keys[entry.key.id] ?? entry.key.color ?? color(for: entry.level)
    }

    public func color(for level: TapeLevel) -> TapeColor {
        levels[level] ?? levels[.info] ?? TapeTheme.default.levels[.info]!
    }

    /// Badge for the console: the key color may omit an emoji, in which case
    /// the level still provides one.
    public func emoji(for entry: TapeEntry) -> String? {
        color(for: entry).emoji ?? color(for: entry.level).emoji
    }
}

extension TapeTheme {
    public static let `default` = TapeTheme(
        background: TapeColor(light: 0xF2F2F7, dark: 0x1C1C1E, ansi: 235),
        card: TapeColor(light: 0xFFFFFF, dark: 0x2C2C2E, ansi: 236),
        text: TapeColor(light: 0x1C1C1E, dark: 0xFFFFFF, ansi: 255),
        secondary: TapeColor(light: 0x6C6C70, dark: 0x8E8E93, ansi: 245),
        levels: [
            .trace: TapeColor(light: 0x8E8E93, dark: 0x8E8E93, ansi: 245, emoji: "⚪️"),
            .debug: TapeColor(light: 0x8E8E93, dark: 0x98989D, ansi: 245, emoji: "🔘"),
            .info: TapeColor(light: 0x1976D2, dark: 0x42A5F5, ansi: 75, emoji: "🔵"),
            .notice: TapeColor(light: 0x1B8A3A, dark: 0x30D158, ansi: 40, emoji: "🟢"),
            .warning: TapeColor(light: 0xC25E00, dark: 0xFF9F0A, ansi: 214, emoji: "🟠"),
            .error: TapeColor(light: 0xD32F2F, dark: 0xFF453A, ansi: 203, emoji: "🔴"),
            .critical: TapeColor(light: 0xB71C1C, dark: 0xFF375F, ansi: 197, emoji: "🟣"),
            .fault: TapeColor(light: 0x8E0000, dark: 0xD70015, ansi: 88, emoji: "⛔️"),
        ],
        keys: [:]
    )
}
