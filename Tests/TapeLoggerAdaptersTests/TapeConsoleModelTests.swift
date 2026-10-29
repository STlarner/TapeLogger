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

    @Test("Clearing rejects buffered entries and updates every console")
    func clearBufferedEntries() async throws {
        let tape = Tape(sinks: [])
        let first = TapeConsoleModel(store: tape.store)
        let second = TapeConsoleModel(store: tape.store)
        let consumers = [
            Task { await first.consume() },
            Task { await second.consume() },
        ]
        defer { consumers.forEach { $0.cancel() } }
        tape.info("subscribed")
        try await waitForEntry("subscribed", in: first)
        try await waitForEntry("subscribed", in: second)

        tape.info("queued before Clear")
        first.clear()
        #expect(first.entries.isEmpty)
        try await Task.sleep(for: .milliseconds(100))
        #expect(tape.store.count == 0)
        #expect(first.entries.isEmpty)
        #expect(second.entries.isEmpty)

        tape.info("after Clear")
        try await waitForEntry("after Clear", in: first)
        try await waitForEntry("after Clear", in: second)
        #expect(first.entries.map(\.message) == ["after Clear"])
        #expect(second.entries.map(\.message) == ["after Clear"])
    }

    @Test("Reset generations survive stream overflow and direct store clearing")
    func droppedReset() async throws {
        let tape = Tape(sinks: [], store: TapeStore(streamBufferSize: 1))
        let model = TapeConsoleModel(store: tape.store)
        let consumer = Task { await model.consume() }
        defer { consumer.cancel() }
        tape.info("subscribed")
        try await waitForEntry("subscribed", in: model)

        tape.info("stale")
        tape.store.clear()
        tape.info("new generation") // Evicts the reset from the buffer.
        try await waitForEntry("new generation", in: model)
        #expect(model.entries.map(\.message) == ["new generation"])
    }

    @Test("A clear invalidates already coalesced pending entries")
    func clearPending() async throws {
        let tape = Tape(sinks: [])
        let model = TapeConsoleModel(store: tape.store)
        let consumer = Task { await model.consume() }
        defer { consumer.cancel() }
        tape.info("subscribed")
        try await waitForEntry("subscribed", in: model)
        tape.info("pending")
        try await Task.sleep(for: .milliseconds(10))
        tape.store.clear()
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.entries.isEmpty)
    }

    @Test("Search includes every attachment and displayed source file")
    func searchDetails() {
        let store = TapeStore()
        let attachments: [TapeAttachment] = [
            .error("unique error code"), .stackTrace("unique stack frame"),
            .custom(id: "detail", payload: "unique payload"),
            .http(TapeHTTPExchange(
                method: "GET", url: "https://example.com",
                request: .init(headers: ["X-Trace-ID": "unique header"]),
                response: .init(body: "unique response")
            )),
        ]
        for attachment in attachments {
            store.append(TapeEntry(
                level: .info, message: "generic",
                source: TapeSource(file: "Module/SomeFile.swift"),
                attachment: attachment
            ))
        }
        let model = TapeConsoleModel(store: store)
        for query in ["unique error", "unique stack", "unique payload",
                      "unique header", "unique response"] {
            model.searchText = query
            #expect(model.visibleEntries.count == 1)
        }
        model.searchText = "SomeFile.swift"
        #expect(model.visibleEntries.count == 4)
        model.selectedLevels = [.error]
        #expect(model.visibleEntries.isEmpty)
    }
}
