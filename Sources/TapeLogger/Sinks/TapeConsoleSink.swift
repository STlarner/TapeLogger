import Foundation

/// Writes rendered entries to stdout, which is what the Xcode console and
/// the terminal show.
public struct TapeConsoleSink: TapeSink {
    public var theme: TapeTheme
    public var renderer: any TapeTextRenderer
    public var capabilities: TapeConsoleCapabilities
    public var minimumLevel: TapeLevel

    public init(
        theme: TapeTheme = .default,
        renderer: any TapeTextRenderer = TapeBoxRenderer(),
        capabilities: TapeConsoleCapabilities = .detect(),
        minimumLevel: TapeLevel = .trace
    ) {
        self.theme = theme
        self.renderer = renderer
        self.capabilities = capabilities
        self.minimumLevel = minimumLevel
    }

    public static var `default`: TapeConsoleSink {
        TapeConsoleSink()
    }

    public func record(_ entry: TapeEntry) {
        guard entry.level >= minimumLevel else { return }
        let context = TapeRenderContext(theme: theme, capabilities: capabilities)
        print(renderer.render(entry, context: context))
    }
}
