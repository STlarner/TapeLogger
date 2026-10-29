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
    /// Retained UI history before search and level filtering, in append order.
    public private(set) var entries: [TapeEntry] = []
    /// Case-insensitive substring query; surrounding whitespace is ignored.
    public var searchText: String = ""
    /// Included severities; initially every level.
    public var selectedLevels: Set<TapeLevel> = Set(TapeLevel.allCases)

    /// Positive maximum retained by this model, independent of store capacity.
    public let maxEntries: Int
    private let store: TapeStore

    private var pending: [TapeEntry] = []
    private var flushTask: Task<Void, Never>?
    private var consumptionID: UUID?
    private var generation: UUID?

    /// Creates a model with a history snapshot. Call `consume` to observe updates.
    ///
    /// - Parameters:
    ///   - store: History source, usually the logger's store.
    ///   - maxEntries: Positive UI retention limit; defaults to 1000.
    public init(store: TapeStore = Tape.shared.store, maxEntries: Int = 1000) {
        precondition(maxEntries > 0, "maxEntries must be positive")
        self.store = store
        self.maxEntries = maxEntries
        self.entries = Array(store.snapshot().suffix(maxEntries))
    }

    /// Consumes the store stream until the surrounding task is cancelled.
    /// Call it from `.task { }` so it stops when the screen disappears.
    /// Refreshes the initial snapshot atomically with subscription, coalesces
    /// updates for about 50 ms, and supersedes any previous consumer on this model.
    /// Slow consumers may miss streamed entries when the store buffer overflows.
    public func consume() async {
        let id = UUID()
        consumptionID = id
        flushTask?.cancel()
        flushTask = nil
        pending.removeAll(keepingCapacity: true)
        let observation = store.snapshotAndEvents()
        generation = observation.generation
        entries = Array(observation.snapshot.suffix(maxEntries))
        defer {
            if consumptionID == id {
                flushTask?.cancel()
                flushTask = nil
                flush()
                consumptionID = nil
            }
        }
        for await event in observation.stream {
            guard consumptionID == id else { break }
            let current = store.generation
            if generation != current { reset(to: current) }
            switch event {
            case .entry(let entry, let eventGeneration):
                guard eventGeneration == current else { continue }
                ingest(entry)
            case .reset:
                // The latest generation wins, not an older buffered reset.
                break
            }
        }
    }

    /// Clears the shared store and this model, invalidating pre-clear buffers.
    /// Other consuming consoles observe the reset as they process updates.
    public func clear() {
        store.clear()
        reset(to: store.generation)
    }

    /// Entries matching selected levels and search text. Search includes copy
    /// text, attachment contents, metadata, source file and function names.
    public var visibleEntries: [TapeEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return entries.filter { entry in
            guard selectedLevels.contains(entry.level) else { return false }
            guard !query.isEmpty else { return true }

            if entry.copyText.lowercased().contains(query) { return true }
            if entry.source?.file.lowercased().contains(query) == true {
                return true
            }
            if entry.source?.short.lowercased().contains(query) == true {
                return true
            }
            return entry.source?.function.lowercased().contains(query) == true
        }
    }

    // MARK: - Coalescing

    private func reset(to generation: UUID) {
        flushTask?.cancel()
        flushTask = nil
        pending.removeAll(keepingCapacity: true)
        entries.removeAll()
        self.generation = generation
    }

    private func ingest(_ entry: TapeEntry) {
        pending.append(entry)

        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(50))
            } catch {
                return
            }
            guard let self else { return }
            self.flush()
            self.flushTask = nil
        }
    }

    private func flush() {
        let current = store.generation
        guard generation == current else {
            reset(to: current)
            return
        }
        guard !pending.isEmpty else { return }

        entries.append(contentsOf: pending)
        pending.removeAll(keepingCapacity: true)

        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
}
