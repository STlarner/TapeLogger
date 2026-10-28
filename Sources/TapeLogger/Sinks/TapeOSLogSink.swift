import Foundation
import os

/// Forwards entries to the unified log, so they stay visible in Console.app,
/// Instruments and `log stream` while also appearing in the in-app console.
///
/// This is the *forward* direction only: iOS gives no public API to read
/// the unified log, so third-party `os_log` output cannot be captured.
public struct TapeOSLogSink: TapeSink {
    private let logger: Logger
    private let minimumLevel: TapeLevel

    public init(
        subsystem: String,
        category: String = "Tape",
        minimumLevel: TapeLevel = .debug
    ) {
        self.logger = Logger(subsystem: subsystem, category: category)
        self.minimumLevel = minimumLevel
    }

    public func record(_ entry: TapeEntry) {
        guard entry.level >= minimumLevel else { return }

        // `privacy:` only works on a literal interpolated into the log call,
        // so the string is composed first and then marked public here.
        let text = "\(entry.key.title) | \(entry.message)"
        switch entry.level {
        case .trace: logger.trace("\(text, privacy: .public)")
        case .debug: logger.debug("\(text, privacy: .public)")
        case .info: logger.info("\(text, privacy: .public)")
        case .notice: logger.notice("\(text, privacy: .public)")
        case .warning: logger.warning("\(text, privacy: .public)")
        case .error: logger.error("\(text, privacy: .public)")
        case .critical: logger.critical("\(text, privacy: .public)")
        case .fault: logger.fault("\(text, privacy: .public)")
        }
    }
}
