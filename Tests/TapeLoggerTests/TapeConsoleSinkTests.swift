import Foundation
import Testing
import os
@testable import TapeLogger

@Suite("Asynchronous console output")
struct TapeConsoleSinkTests {
    private struct MessageRenderer: TapeTextRenderer {
        func render(
            _ entry: TapeEntry, context: TapeRenderContext
        ) -> String { entry.message }
    }

    @Test("Blocked output does not block enqueue and overflow drops newest")
    func boundedBackpressure() async throws {
        let started = OSAllocatedUnfairLock(initialState: false)
        let release = DispatchSemaphore(value: 0)
        let written = OSAllocatedUnfairLock(initialState: [String]())
        let output = TapeConsoleOutput(capacity: 2) { text in
            if text == "first" {
                started.withLock { $0 = true }
                release.wait()
            }
            written.withLock { $0.append(text) }
        }
        defer { release.signal() }
        let context = TapeRenderContext(capabilities: .plain)
        func enqueue(_ text: String) {
            output.enqueue(
                TapeEntry(level: .info, message: text),
                renderer: MessageRenderer(), context: context
            )
        }
        enqueue("first")
        let deadline = ContinuousClock.now + .seconds(2)
        while !started.withLock({ $0 }), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        try #require(started.withLock { $0 })
        enqueue("second")
        enqueue("third")
        enqueue("dropped")
        #expect(output.droppedEntryCount == 1)
        #expect(written.withLock { $0.isEmpty })
        release.signal()
        await output.flush()
        #expect(written.withLock { $0 } == ["first", "second", "third"])

        enqueue("after drain")
        await output.flush()
        #expect(written.withLock { $0.last } == "after drain")
    }

    @Test("Concurrent producers are drained once without losing accepted work")
    func concurrentProducers() async {
        let written = OSAllocatedUnfairLock(initialState: Set<String>())
        let output = TapeConsoleOutput(capacity: 1000) { text in
            written.withLock { _ = $0.insert(text) }
        }
        DispatchQueue.concurrentPerform(iterations: 1000) { index in
            output.enqueue(
                TapeEntry(level: .info, message: "\(index)"),
                renderer: MessageRenderer(),
                context: TapeRenderContext(capabilities: .plain)
            )
        }
        async let first: Void = output.flush()
        async let second: Void = output.flush()
        _ = await (first, second)
        #expect(output.droppedEntryCount == 0)
        #expect(written.withLock { $0.count } == 1000)
    }

    private struct LoggingRenderer: TapeTextRenderer {
        let tape: Tape
        let rendered: OSAllocatedUnfairLock<Int>
        func render(
            _ entry: TapeEntry, context: TapeRenderContext
        ) -> String {
            rendered.withLock { $0 += 1 }
            tape.info("renderer diagnostic")
            return entry.message
        }
    }

    @Test("Asynchronous renderers cannot feed back into console workers")
    func rendererReentrancy() async {
        let tape = Tape(sinks: [])
        let rendered = OSAllocatedUnfairLock(initialState: 0)
        let sink = TapeConsoleSink(renderer: LoggingRenderer(
            tape: tape, rendered: rendered
        ))
        tape.addSink(sink)
        defer { tape.removeAllSinks() }
        tape.info("one output")
        await sink.flush()
        #expect(rendered.withLock { $0 } == 1)
        #expect(tape.store.count == 2)
    }
}
