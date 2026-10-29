import Foundation
import Testing

@testable import TapeLogger

@Suite("TapeLog")
struct TapeLogTests {
    /// The shape an app writes: header, level and style live on the type.
    struct NavigationLog: TapeLog {
        let message: String

        init(_ message: String) {
            self.message = message
        }

        var title: String { "route" }
        var level: TapeLevel { .debug }
        var color: TapeColor? {
            TapeColor(light: 0x7B1FA2, dark: 0xAF5FFF, ansi: 135, emoji: "🧭")
        }
    }

    /// Only the header differs: level and style come from the defaults.
    struct JobLog: TapeLog {
        let message: String

        init(_ message: String) {
            self.message = message
        }
        var title: String { "job" }
    }

    @Test("A custom type sets level, key and message")
    func mapsToEntry() {
        let tape = Tape(sinks: [], store: TapeStore())

        tape.log(NavigationLog("Push RoomRoute"))
        let entry = tape.store.snapshot().first

        #expect(entry?.message == "Push RoomRoute")
        #expect(entry?.level == .debug)
        #expect(entry?.key.id == "route")
        #expect(entry?.key.title == "route")
        #expect(entry?.heading == "debug · route")
        #expect(entry?.source?.file.isEmpty == false)
    }

    @Test("Level and color fall back to the defaults")
    func defaults() {
        let tape = Tape(sinks: [], store: TapeStore())

        tape.log(JobLog("export finished"))
        let entry = tape.store.snapshot().first

        #expect(entry?.level == .info)
        #expect(entry?.key.color == nil)
        #expect(entry?.heading == "info · job")
        #expect(entry?.copyText.contains("[info · job]") == true)
    }

    @Test("The console prints the badge declared by the type")
    func consoleBadge() throws {
        let tape = Tape(sinks: [], store: TapeStore())
        tape.log(NavigationLog("Push RoomRoute"))
        let entry = try #require(tape.store.snapshot().first)

        let output = TapeBoxRenderer().render(
            entry,
            context: TapeRenderContext(theme: .default, capabilities: .emoji)
        )

        #expect(output.contains("│ 🧭 debug · route |"))
        #expect(output.contains("│ Push RoomRoute"))
    }

    @Test("A theme override wins over the color of the type")
    func themeOverride() throws {
        let tape = Tape(sinks: [], store: TapeStore())
        tape.log(NavigationLog("Push RoomRoute"))
        let entry = try #require(tape.store.snapshot().first)

        var theme = TapeTheme.default
        theme.keys["route"] = TapeColor(
            light: 0x1B8A3A,
            dark: 0x30D158,
            ansi: 40,
            emoji: "🏦"
        )

        let output = TapeBoxRenderer().render(
            entry,
            context: TapeRenderContext(theme: theme, capabilities: .emoji)
        )

        #expect(output.contains("│ 🏦 debug · route |"))
    }

    @Test("Minimum level still filters a custom type")
    func respectsMinimumLevel() {
        let tape = Tape(sinks: [], store: TapeStore())
        tape.minimumLevel = .info

        tape.log(NavigationLog("Push RoomRoute"))

        #expect(tape.store.snapshot().isEmpty)
    }
}
