import TapeLogger
import Testing
@testable import TapeLoggerUI

@Suite("SwiftUI navigation observations")
struct TapeSwiftUINavigationTests {
    @Test("Typed paths distinguish pushes, pops, resets and replacements")
    func changes() {
        #expect(tapeNavigationEvent(from: [Int](), to: [1]) == "push")
        #expect(tapeNavigationEvent(from: [1], to: [1, 2, 3]) == "push")
        #expect(tapeNavigationEvent(from: [1, 2], to: [1]) == "pop")
        #expect(tapeNavigationEvent(from: [1, 2], to: []) == "pop")
        #expect(tapeNavigationEvent(from: [1, 2], to: [1, 3]) == "replace")
        #expect(tapeNavigationEvent(from: [1, 2], to: [4]) == "replace")
        #expect(tapeNavigationEvent(from: [1], to: [1]) == nil)
    }

    @Test("Navigation entries carry the stack and depth without a router")
    func metadata() {
        let tape = Tape(sinks: [])
        recordNavigation(
            "push", name: "main", from: 0, to: 2,
            destination: "settings", tape: tape
        )
        let entry = tape.store.snapshot().first
        #expect(entry?.key == .navigation)
        #expect(entry?.message == "main: push → settings")
        #expect(entry?.metadata["fromDepth"]?.description == "0")
        #expect(entry?.metadata["toDepth"]?.description == "2")
        recordNavigation(
            "replace", name: "opaque", from: 2, to: 2,
            destination: nil, tape: tape
        )
        let opaque = tape.store.snapshot().last
        #expect(opaque?.message == "opaque: replace (depth 2)")
        #expect(opaque?.metadata["destination"] == nil)
    }
}
