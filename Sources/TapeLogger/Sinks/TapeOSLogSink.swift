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
        /// Apply Apple's private-content handling to the entire formatted entry.
        case `private`
        /// Make the entire entry public, including metadata and attachments.
        case `public`
    }

    private let logger: Logger
    private let minimumLevel: TapeLevel
    /// Privacy applied to the full formatted entry; private by default.
    public let privacy: Privacy

    /// Creates a unified-log destination. OSLog controls persistence, truncation
    /// and whether private content can be viewed; history is retained separately.
    ///
    /// - Parameters:
    ///   - subsystem: Reverse-DNS subsystem identifying the app or component.
    ///   - category: Category within that subsystem; defaults to `Tape`.
    ///   - minimumLevel: Lowest forwarded severity; defaults to `.debug`.
    ///   - privacy: Full-entry privacy; choose public only for non-sensitive data.
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

    /// Forwards an accepted entry's copy text, including metadata and attachments,
    /// to the corresponding unified-log severity under this sink's privacy policy.
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
