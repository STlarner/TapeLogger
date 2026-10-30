import Foundation

/// A destination for log entries.
///
/// `record` runs synchronously on the recording thread, outside the logger's
/// locks. Buffer expensive work and synchronize mutable state for concurrent
/// callers. Concurrent recordings may reach sinks in a different order from
/// store history. A sink may call back into `Tape`; the logger's reentrancy
/// guard suppresses recursive recording into the same logger.
public protocol TapeSink: Sendable {
    /// Accepts an entry synchronously on the recording thread. Buffer expensive
    /// rendering or I/O internally, and synchronize state for concurrent callers.
    /// Recursive calls into the same logger are suppressed.
    func record(_ entry: TapeEntry)
}
