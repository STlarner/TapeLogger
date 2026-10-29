import Foundation

/// Console presentation mode and display-column budget.
///
/// ```swift
/// let capabilities = TapeConsoleCapabilities(mode: .emoji, maxWidth: 72)
/// ```
public struct TapeConsoleCapabilities: Sendable, Hashable {
    /// Renderer-controlled styling; payload terminal controls remain escaped.
    public enum ColorMode: Sendable, Hashable {
        /// Plain text without generated color escapes or badges.
        case none
        /// Emoji badges without ANSI color escapes, suitable for Xcode.
        case emoji
        /// ANSI 256-color styling, suitable for compatible terminals.
        case ansi
    }

    /// Selected console styling mode.
    public var mode: ColorMode
    /// Width of the console box in display columns. Every box uses it, so a run
    /// of entries lines up; longer text wraps instead of widening the box.
    /// The default leaves room for the Xcode console, which is usually
    /// narrower than a maximized terminal.
    public var maxWidth: Int

    /// Creates explicit capabilities without consulting the environment.
    ///
    /// - Parameters:
    ///   - mode: Styling mode; defaults to emoji.
    ///   - maxWidth: Requested display columns; the box renderer enforces a
    ///     minimum of 24, even when the supplied value is smaller.
    public init(mode: ColorMode = .emoji, maxWidth: Int = 77) {
        self.mode = mode
        self.maxWidth = maxWidth
    }

    /// Plain output with the default 77-column width.
    public static let plain = TapeConsoleCapabilities(mode: .none)
    /// Emoji output with the default 77-column width.
    public static let emoji = TapeConsoleCapabilities(mode: .emoji)
    /// ANSI output with the default 77-column width.
    public static let ansi = TapeConsoleCapabilities(mode: .ansi)

    /// ANSI only when stdout is a real terminal that is not the Xcode
    /// console. Xcode runs the app behind a pseudo terminal, so `isatty`
    /// returns true and `TERM` is set, but the console does not interpret
    /// escape codes: emitting them prints raw `[38;5;75m` noise.
    ///
    /// When stdout *is* a terminal, its width caps `maxWidth`: a box wider
    /// than the console would wrap and lose its alignment.
    ///
    /// - Parameter environment: Variables to inspect; defaults to the process
    ///   environment. Terminal attachment and dimensions still come from stdout.
    /// - Returns: ANSI for a compatible terminal without Xcode markers, otherwise
    ///   emoji. Reported terminal widths of at least 40 cap the default width.
    public static func detect(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> TapeConsoleCapabilities {
        #if canImport(Darwin)
        let isTTY = isatty(STDOUT_FILENO) == 1
        #else
        let isTTY = false
        #endif
        var capabilities = detect(environment: environment, isTerminal: isTTY)
        if isTTY, let columns = terminalColumns(), columns >= 40 {
            capabilities.maxWidth = min(capabilities.maxWidth, columns)
        }
        return capabilities
    }

    /// Columns of the terminal attached to stdout, when it reports them.
    static func terminalColumns() -> Int? {
        #if canImport(Darwin)
        var size = winsize()
        guard ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0 else { return nil }
        return Int(size.ws_col)
        #else
        return nil
        #endif
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
    /// Palette used to resolve entry styling.
    public var theme: TapeTheme
    /// Styling mode and requested width for this render.
    public var capabilities: TapeConsoleCapabilities

    /// Combines a palette and capabilities without retaining a logger or store.
    ///
    /// - Parameters:
    ///   - theme: Presentation palette; defaults to the built-in theme.
    ///   - capabilities: Output capabilities; auto-detected by default.
    public init(theme: TapeTheme = .default, capabilities: TapeConsoleCapabilities = .detect()) {
        self.theme = theme
        self.capabilities = capabilities
    }
}

/// Turns an entry into text for a text destination.
public protocol TapeTextRenderer: Sendable {
    /// Formats an entry without mutating its content. Implementations must be
    /// safe for concurrent calls and should not log back into console output.
    ///
    /// - Parameters:
    ///   - entry: Content to present.
    ///   - context: Palette and output capabilities.
    /// - Returns: Formatted text, without writing it to a destination.
    func render(_ entry: TapeEntry, context: TapeRenderContext) -> String
}
