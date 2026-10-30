import Foundation

/// Time formatting shared by the console renderer and the UI header.
public enum TapeTimeFormatter {
    /// `DateFormatter` is thread-safe for formatting as long as it is not
    /// mutated after creation.
    private static let fullFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    /// Formats local time as `HH:mm:ss.SSS`, such as `21:30:31.584`.
    public static func string(from date: Date) -> String {
        fullFormatter.string(from: date)
    }

    /// Formats local time as `HH:mm:ss`, such as `21:30:31`.
    public static func shortString(from date: Date) -> String {
        shortFormatter.string(from: date)
    }
}

/// Adds overflow-safe whole-millisecond formatting to Swift durations.
extension Duration {
    /// Whole milliseconds, for the `584ms` badge. Values outside `Int`'s
    /// range saturate at its bounds instead of trapping during rendering.
    public var tapeMilliseconds: Int {
        let (seconds, attoseconds) = components
        let (whole, overflow) = Int(clamping: seconds)
            .multipliedReportingOverflow(by: 1000)
        guard !overflow else { return seconds < 0 ? .min : .max }
        let fraction = Int(attoseconds / 1_000_000_000_000_000)
        let (total, additionOverflow) = whole.addingReportingOverflow(fraction)
        guard !additionOverflow else { return seconds < 0 ? .min : .max }
        return total
    }
}
