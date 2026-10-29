import Foundation
import TapeLogger
import TapeLoggerUI
import Testing

@Suite("Console history")
@MainActor
struct TapeConsoleModelTests {
    @Test("Opening the console refreshes entries logged after initialization")
    func openingSnapshot() async throws {
        let tape = Tape(sinks: [])
        tape.info("old")
        let model = TapeConsoleModel(store: tape.store)
        tape.info("latest before presentation")
        let consumer = Task { await model.consume() }
        defer { consumer.cancel() }
        try await waitForEntry("latest before presentation", in: model)
        #expect(model.entries.map(\.message)
            == ["old", "latest before presentation"])
        tape.info("live")
        try await waitForEntry("live", in: model)
        #expect(model.entries.count == 3)
        consumer.cancel()
        await consumer.value
        tape.info("logged while closed")
        let reopened = Task { await model.consume() }
        defer { reopened.cancel() }
        try await waitForEntry("logged while closed", in: model)
        #expect(model.entries.count == 4)
    }

    @Test("An atomic snapshot is followed only by newer streamed entries")
    func snapshotBoundary() async throws {
        let tape = Tape(sinks: [])
        tape.info("history")
        let observation = tape.store.snapshotAndStream()
        tape.info("new")
        #expect(observation.snapshot.map(\.message) == ["history"])
        var iterator = observation.stream.makeAsyncIterator()
        let next = await iterator.next()
        #expect(next?.message == "new")
    }

    private func waitForEntry(
        _ message: String, in model: TapeConsoleModel
    ) async throws {
        let deadline = ContinuousClock.now + .seconds(2)
        while model.entries.last?.message != message,
              ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(model.entries.last?.message == message)
    }
}
