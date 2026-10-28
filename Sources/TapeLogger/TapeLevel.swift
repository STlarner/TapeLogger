import Foundation

/// Severity of a log entry.
///
/// Cases map 1:1 to `os.Logger.Level`, so forwarding to the unified log
/// is a plain switch with no lossy conversion.
public enum TapeLevel: Int, Sendable, CaseIterable, Comparable, Codable {
    case trace = 0
    case debug
    case info
    case notice
    case warning
    case error
    case critical
    case fault

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
