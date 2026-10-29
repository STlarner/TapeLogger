import Foundation

/// Severity of a log entry.
///
/// Ordered from trace through fault. Unified logging groups trace/debug,
/// warning/error and critical/fault into shared underlying severities.
public enum TapeLevel: Int, Sendable, CaseIterable, Comparable, Codable {
    /// Most detailed tracing; maps to unified-log debug severity.
    case trace = 0
    /// Developer diagnostics; maps to unified-log debug severity.
    case debug
    /// Informational events; maps to unified-log info severity.
    case info
    /// Noteworthy normal events; maps to unified-log default severity.
    case notice
    /// Recoverable problems; maps to unified-log error severity.
    case warning
    /// Failed operations; maps to unified-log error severity.
    case error
    /// Severe failures; maps to unified-log fault severity.
    case critical
    /// Highest severity; maps to unified-log fault severity without asserting.
    case fault

    /// Compares the declared severity order from trace through fault.
    public static func < (lhs: TapeLevel, rhs: TapeLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Short name used in console output and in the UI header.
    public var label: String {
        switch self {
        case .trace: "trace"
        case .debug: "debug"
        case .info: "info"
        case .notice: "notice"
        case .warning: "warning"
        case .error: "error"
        case .critical: "critical"
        case .fault: "fault"
        }
    }
}
