import Foundation

extension Tape {
    /// Replaces the shared logger's sinks according to the build configuration
    /// and detected console environment.
    ///
    /// - Debug builds write to stdout: ANSI in a detected compatible terminal,
    ///   emoji badges otherwise.
    /// - Release builds forward to the unified log with private message content.
    /// - Debug builds without Xcode console markers also forward to unified
    ///   logging, independently of whether stdout is being observed.
    ///
    /// The unified log is skipped while the Xcode console is the destination:
    /// this avoids duplicate entries when Xcode displays both destinations.
    ///
    /// Operates on `Tape.shared`, not on custom logger instances. The selection
    /// uses the package's build configuration. This does not clear history or
    /// change the logger's own minimum level. Replacing sinks does not flush them.
    ///
    /// - Parameters:
    ///   - subsystem: Reverse-DNS unified-log subsystem, usually the app bundle ID.
    ///   - category: Unified-log category; defaults to `app`.
    ///   - consoleMinimumLevel: Console threshold in debug configurations.
    ///   - logMinimumLevel: Unified-log threshold; defaults to `.debug`.
    public static func installRecommendedSinks(
        subsystem: String,
        category: String = "app",
        consoleMinimumLevel: TapeLevel = .trace,
        logMinimumLevel: TapeLevel = .debug
    ) {
        let tape = Tape.shared
        tape.removeAllSinks()

        let logSink = TapeOSLogSink(
            subsystem: subsystem,
            category: category,
            minimumLevel: logMinimumLevel
        )

        #if DEBUG
            let capabilities = TapeConsoleCapabilities.detect()
            tape.addSink(
                TapeConsoleSink(
                    capabilities: capabilities,
                    minimumLevel: consoleMinimumLevel
                )
            )
            if !TapeConsoleCapabilities.isXcodeConsole() {
                tape.addSink(logSink)
            }
        #else
            tape.addSink(logSink)
        #endif
    }
}
