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

    /// ANSI only when stdout is a real terminal that is not the Xcode
    /// console. Xcode runs the app behind a pseudo terminal, so `isatty`
    /// returns true and `TERM` is set, but the console does not interpret
    /// escape codes: emitting them prints raw `[38;5;75m` noise.
    public static func detect(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> TapeConsoleCapabilities {
        #if canImport(Darwin)
        let isTTY = isatty(STDOUT_FILENO) == 1
        #else
        let isTTY = false
        #endif
        return detect(environment: environment, isTerminal: isTTY)
    }

    static func detect(
        environment: [String: String],
        isTerminal: Bool
    ) -> TapeConsoleCapabilities {
        guard isTerminal else { return .emoji }
        guard let term = environment["TERM"], !term.isEmpty, term != "dumb" else {
            return .emoji
        }
        return isXcodeConsole(environment: environment) ? .emoji : .ansi
    }

    /// Xcode exports a handful of variables into the process it runs. They
    /// are the only reliable signal: the console is a pty, exactly like a
    /// terminal that does support ANSI.
    static func isXcodeConsole(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment.keys.contains { xcodeMarkers.contains($0) }
    }

    private static let xcodeMarkers = [
        "XCODE_VERSION_ACTUAL",
        "XCODE_PRODUCT_BUILD_VERSION",
        "XCODE_RUNNING_FOR_PREVIEWS",
        "__XCODE_BUILT_PRODUCTS_DIR_PATHS",
        "IDE_DISABLED_OS_ACTIVITY_DT_MODE",
        "XCTestConfigurationFilePath",
    ]
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
