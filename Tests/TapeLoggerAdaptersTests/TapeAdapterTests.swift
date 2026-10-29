import Foundation
import TapeLogger
import Testing
@testable import TapeLoggerAdapters

@Suite("Adapter ownership")
@MainActor
struct TapeAdapterTests {
    @Test("The owner installs once and uninstalls in reverse order")
    func ownership() throws {
        let owner = TapeAdapters()
        let first = CountingAdapter()
        let second = CountingAdapter()
        var order: [Int] = []
        first.onRemove = { order.append(1) }
        second.onRemove = { order.append(2) }
        try owner.install(first)
        try owner.install(first)
        try owner.install(second)
        #expect(first.installs == 1)
        owner.removeAll()
        owner.removeAll()
        #expect(first.removals == 1)
        #expect(second.removals == 1)
        #expect(order == [2, 1])
    }

    @Test("Failed installation is not retained")
    func failedInstallation() {
        let owner = TapeAdapters()
        let adapter = CountingAdapter()
        adapter.fails = true
        #expect(throws: URLError.self) { try owner.install(adapter) }
        owner.removeAll()
        #expect(adapter.removals == 0)
    }
}

@MainActor
private final class CountingAdapter: TapeAdapter {
    var installs = 0
    var removals = 0
    var fails = false
    var onRemove: () -> Void = {}

    func install() throws {
        if fails { throw URLError(.unknown) }
        installs += 1
    }

    func uninstall() {
        removals += 1
        onRemove()
    }
}
