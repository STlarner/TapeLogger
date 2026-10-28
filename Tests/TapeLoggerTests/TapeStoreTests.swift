import Foundation
import Testing
@testable import TapeLogger

@Suite("TapeStore")
struct TapeStoreTests {
    @Test("Keeps only the most recent entries")
    func capacity() {
        let store = TapeStore(capacity: 10)

        for index in 0..<100 {
            store.append(TapeEntry(level: .debug, message: "log \(index)"))
        }

        let snapshot = store.snapshot()
        #expect(snapshot.count <= 10)
        #expect(snapshot.last?.message == "log 99")
    }

    @Test("Snapshot preserves order")
    func ordering() {
        let store = TapeStore()

        for index in 0..<5 {
            store.append(TapeEntry(level: .info, message: "log \(index)"))
        }

        #expect(store.snapshot().map(\.message) == ["log 0", "log 1", "log 2", "log 3", "log 4"])
    }

    @Test("Stream receives appended entries")
    func stream() async {
        let store = TapeStore()
        let stream = store.stream

        let consumer = Task {
            var received: [String] = []
            for await entry in stream {
                received.append(entry.message)
                if received.count == 2 { break }
            }
            return received
        }

        // Give the consumer a chance to subscribe before producing.
        try? await Task.sleep(for: .milliseconds(20))
        store.append(TapeEntry(level: .info, message: "first"))
        store.append(TapeEntry(level: .info, message: "second"))

        let received = await consumer.value
        #expect(received == ["first", "second"])
    }

    @Test("Theme resolves a key override before the level color")
    func themePriority() {
        let entry = TapeEntry(level: .info, key: .httpRequest, message: "GET")

        #expect(TapeTheme.default.color(for: entry) == TapeTheme.default.keys[TapeKey.httpRequest.id])
        #expect(TapeTheme.default.color(for: .warning) == TapeTheme.default.levels[.warning])
    }
}
