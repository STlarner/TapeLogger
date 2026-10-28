import Foundation

extension Tape {
    /// Installs the sinks that make sense in the current environment,
    /// replacing whatever was configured before.
    ///
    /// - Debug builds render to the console: ANSI colors in a terminal, emoji
    ///   badges in the Xcode console, which interprets no escape codes.
    /// - Release builds forward to the unified log, so entries stay readable
    ///   in Console.app, Instruments and `log stream`.
    /// - A debug build that does not run in the Xcode console gets both: the
    ///   emoji console output is invisible outside a terminal, but the unified
    ///   log keeps it.
    ///
    /// The unified log is skipped while the Xcode console is the destination:
    /// the same entry would appear twice, once as a box and once as a plain
    /// `subsystem:category` line.
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
