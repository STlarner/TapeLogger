import Foundation
import os

/// Forwards entries to the unified log, so they stay visible in Console.app,
/// Instruments and `log stream` while also appearing in the in-app console.
///
/// This is the *forward* direction only: iOS gives no public API to read
/// the unified log, so third-party `os_log` output cannot be captured.
public struct TapeOSLogSink: TapeSink {
    /// Applies to the entire formatted entry, including attachments and
    /// metadata. Public output is an explicit opt-in for non-sensitive data.
    public enum Privacy: Sendable {
        case `private`
        case `public`
    }

    private let logger: Logger
    private let minimumLevel: TapeLevel
    public let privacy: Privacy

    public init(
        subsystem: String,
        category: String = "Tape",
        minimumLevel: TapeLevel = .debug,
        privacy: Privacy = .private
    ) {
        self.logger = Logger(subsystem: subsystem, category: category)
        self.minimumLevel = minimumLevel
        self.privacy = privacy
    }

    public func record(_ entry: TapeEntry) {
        guard entry.level >= minimumLevel else { return }

        let text = entry.copyText
        let level: OSLogType = switch entry.level {
        case .trace, .debug: .debug
        case .info: .info
        case .notice: .default
        case .warning, .error: .error
        case .critical, .fault: .fault
        }
        // OSLog requires privacy annotations at the interpolation site.
        switch privacy {
        case .private:
            logger.log(level: level, "\(text, privacy: .private)")
        case .public:
            logger.log(level: level, "\(text, privacy: .public)")
        }
    }
}
