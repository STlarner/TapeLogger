import Foundation
import Observation
import TapeLogger

/// State for the console screen.
///
/// Entries arrive on an `AsyncStream` and are coalesced before touching the
/// published array: appending one observable change per log would make the
/// list unusable when the app logs in a loop.
@MainActor
@Observable
public final class TapeConsoleModel {
    public private(set) var entries: [TapeEntry] = []
    public var searchText: String = ""
    public var selectedLevels: Set<TapeLevel> = Set(TapeLevel.allCases)

    public let maxEntries: Int
    private let store: TapeStore

    private var pending: [TapeEntry] = []
    private var flushTask: Task<Void, Never>?

    public init(store: TapeStore = Tape.shared.store, maxEntries: Int = 1000) {
        self.store = store
        self.maxEntries = maxEntries
        self.entries = Array(store.snapshot().suffix(maxEntries))
    }

    /// Consumes the store stream until the surrounding task is cancelled.
    /// Call it from `.task { }` so it stops when the screen disappears.
    public func consume() async {
        for await entry in store.stream {
            ingest(entry)
        }
    }

    public func clear() {
        pending.removeAll(keepingCapacity: true)
        entries.removeAll()
        store.clear()
    }

    public var visibleEntries: [TapeEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return entries.filter { entry in
            guard selectedLevels.contains(entry.level) else { return false }
            guard !query.isEmpty else { return true }

            if entry.message.lowercased().contains(query) { return true }
            if entry.key.title.lowercased().contains(query) { return true }
            if entry.source?.function.lowercased().contains(query) == true { return true }
            return entry.metadata.contains { key, value in
                key.lowercased().contains(query) || value.description.lowercased().contains(query)
            }
        }
    }

    // MARK: - Coalescing

    private func ingest(_ entry: TapeEntry) {
        pending.append(entry)

        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            guard let self else { return }
            self.flush()
            self.flushTask = nil
        }
    }

    private func flush() {
        guard !pending.isEmpty else { return }

        entries.append(contentsOf: pending)
        pending.removeAll(keepingCapacity: true)

        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
}
