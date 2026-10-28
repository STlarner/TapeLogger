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

    /// `21:30:31.584`
    public static func string(from date: Date) -> String {
        fullFormatter.string(from: date)
    }

    /// `21:30:31`
    public static func shortString(from date: Date) -> String {
        shortFormatter.string(from: date)
    }
}

extension Duration {
    /// Whole milliseconds, for the `584ms` badge.
    public var tapeMilliseconds: Int {
        let (seconds, attoseconds) = components
        return Int(seconds) * 1000 + Int(attoseconds / 1_000_000_000_000_000)
    }
}
