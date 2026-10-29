import Foundation
import Testing
import os
@testable import TapeLogger

@Suite("Logger safety")
struct TapeSafetyTests {
    private final class LoggingDestructor: TapeSink {
        let tape: Tape
        let stopped: OSAllocatedUnfairLock<Bool>

        init(tape: Tape, stopped: OSAllocatedUnfairLock<Bool>) {
            self.tape = tape
            self.stopped = stopped
        }

        func record(_ entry: TapeEntry) {}

        deinit {
            tape.info("sink stopped")
            _ = tape.isEnabled
            stopped.withLock { $0 = true }
        }
    }

    @Test("Sink destructors can log and read configuration during removal")
    func sinkDestructor() {
        let tape = Tape(sinks: [])
        let stopped = OSAllocatedUnfairLock(initialState: false)
        tape.addSink(LoggingDestructor(tape: tape, stopped: stopped))
        tape.removeAllSinks()
        #expect(stopped.withLock { $0 })
        #expect(tape.sinks.isEmpty)
        #expect(tape.store.snapshot().map(\.message) == ["sink stopped"])
    }

    @Test("Released loggers return their thread-local recursion keys")
    func recursionKeyLifetime() {
        for _ in 0..<2000 {
            let tape = Tape(sinks: [])
            tape.info("temporary")
            #expect(tape.store.count == 1)
        }
        let tape = Tape(sinks: [])
        tape.info("still recording")
        #expect(tape.store.count == 1)
    }

    private struct RecursiveSink: TapeSink {
        let tape: Tape
        func record(_ entry: TapeEntry) { tape.info("recursive") }
    }

    @Test("Sinks that log cannot recurse into ingestion")
    func recursiveSink() {
        let tape = Tape(sinks: [])
        tape.addSink(RecursiveSink(tape: tape))
        defer { tape.removeAllSinks() }
        tape.info("original")
        #expect(tape.store.snapshot().map(\.message) == ["original"])
    }

    @MainActor
    private final class ActorValue {
        var count = 0
    }

    @Test("Async measurements preserve actor isolation and non-Sendable results")
    @MainActor
    func isolatedMeasurement() async throws {
        let tape = Tape(sinks: [])
        let value = ActorValue()
        let result = await tape.measure("main actor") {
            value.count += 1
            await Task.yield()
            value.count += 1
            return value
        }
        #expect(result === value)
        #expect(value.count == 2)
        #expect(tape.store.snapshot().last?.duration != nil)

        // A truly non-Sendable result also must stay on the caller's actor.
        let object = NSMutableString(string: "before")
        let sharedResult = await Tape.measure("static actor") {
            await Task.yield()
            object.append(" after")
            return object
        }
        #expect(sharedResult === object)
        #expect(object == "before after")
    }

    @Test("Duration formatting saturates at integer bounds")
    func durationBounds() {
        #expect(Duration.seconds(Int64.max).tapeMilliseconds == Int.max)
        #expect(Duration.seconds(Int64.min).tapeMilliseconds == Int.min)
        #expect(Duration.milliseconds(584).tapeMilliseconds == 584)
        #expect(Duration.microseconds(-1500).tapeMilliseconds == -1)
        #expect(Duration.zero.tapeMilliseconds == 0)
        let upper = Duration.seconds(Int64(Int.max / 1000))
            + .milliseconds(999)
        let lower = Duration.seconds(Int64(Int.min / 1000))
            - .milliseconds(999)
        #expect(upper.tapeMilliseconds == Int.max)
        #expect(lower.tapeMilliseconds == Int.min)
        for duration in [Duration.seconds(Int64.max), .seconds(Int64.min)] {
            let entry = TapeEntry(
                level: .info, message: "extreme", duration: duration
            )
            #expect(!entry.copyText.isEmpty)
            #expect(!TapeBoxRenderer().render(
                entry, context: TapeRenderContext(capabilities: .plain)
            ).isEmpty)
        }
    }

    @Test("Unified logging defaults to private and permits explicit public output")
    func logPrivacy() {
        let sink = TapeOSLogSink(subsystem: "test")
        if case .private = sink.privacy {} else {
            Issue.record("Unified logging must default to private")
        }
        let publicSink = TapeOSLogSink(subsystem: "test", privacy: .public)
        if case .public = publicSink.privacy {} else {
            Issue.record("Public output must be an explicit opt-in")
        }
    }
}
