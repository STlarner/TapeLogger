import Foundation

/// A destination for log entries: console, unified log, file, remote...
///
/// Contract: `record` must be cheap and must not block. I/O-heavy sinks
/// buffer internally. It is called synchronously on the logging thread so
/// ordering is preserved, and it is *always* called outside of any internal
/// lock, so a sink is free to call back into `Tape`.
public protocol TapeSink: Sendable {
    func record(_ entry: TapeEntry)
}
