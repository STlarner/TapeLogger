import Foundation

/// What the console can actually render.
///
/// Xcode's debug console does not support ANSI escape codes and can even
/// truncate messages that contain them, so color must degrade gracefully:
/// `.ansi` in a terminal, `.emoji` in Xcode, `.none` when color is unwanted.
public struct TapeConsoleCapabilities: Sendable, Hashable {
    public enum ColorMode: Sendable, Hashable {
        case none
        case emoji
        case ansi
    }

    public var mode: ColorMode
    public var maxWidth: Int

    public init(mode: ColorMode = .emoji, maxWidth: Int = 110) {
        self.mode = mode
        self.maxWidth = maxWidth
    }

    public static let plain = TapeConsoleCapabilities(mode: .none)
    public static let emoji = TapeConsoleCapabilities(mode: .emoji)
    public static let ansi = TapeConsoleCapabilities(mode: .ansi)

    /// ANSI only when stdout is a real terminal: in Xcode `TERM` is unset
    /// and stdout is a pipe, so we fall back to emoji.
    public static func detect() -> TapeConsoleCapabilities {
        #if canImport(Darwin)
        let isTTY = isatty(STDOUT_FILENO) == 1
        let hasTerm = ProcessInfo.processInfo.environment["TERM"] != nil
        return TapeConsoleCapabilities(mode: isTTY && hasTerm ? .ansi : .emoji)
        #else
        return .emoji
        #endif
    }
}

/// Everything a text renderer needs. Kept as a value type so renderers stay
/// pure and testable.
public struct TapeRenderContext: Sendable {
    public var theme: TapeTheme
    public var capabilities: TapeConsoleCapabilities

    public init(theme: TapeTheme = .default, capabilities: TapeConsoleCapabilities = .detect()) {
        self.theme = theme
        self.capabilities = capabilities
    }
}

/// Turns an entry into text for a text destination.
public protocol TapeTextRenderer: Sendable {
    func render(_ entry: TapeEntry, context: TapeRenderContext) -> String
}
