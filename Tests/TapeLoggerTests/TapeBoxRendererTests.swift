import Foundation
import Testing
@testable import TapeLogger

@Suite("TapeBoxRenderer")
struct TapeBoxRendererTests {
    @Test("Renders the header, the message and both borders")
    func rendersBox() {
        let entry = TapeEntry(
            date: Date(timeIntervalSince1970: 0),
            level: .info,
            key: .httpRequest,
            message: "[GET] https://example.com",
            duration: .milliseconds(584)
        )

        let output = TapeBoxRenderer().render(
            entry,
            context: TapeRenderContext(theme: .default, capabilities: .plain)
        )
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)

        #expect(lines.count == 4)
        #expect(lines[0].hasPrefix("┌"))
        #expect(lines[1].hasPrefix("│ info · http-request |"))
        #expect(lines[1].contains("584ms"))
        #expect(lines[2] == "│ [GET] https://example.com")
        #expect(lines[3].hasPrefix("└"))
    }

    @Test("Emoji mode shows the badge inside the header")
    func emojiMode() {
        let entry = TapeEntry(level: .warning, message: "cache miss")

        let output = TapeBoxRenderer().render(
            entry,
            context: TapeRenderContext(theme: .default, capabilities: .emoji)
        )
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)

        #expect(lines[0].hasPrefix("┌"))
        #expect(lines[1].hasPrefix("│ 🟠 warning |"))
        #expect(!output.contains("\u{001B}"))
    }

    @Test("Every line starts in the first column", arguments: [TapeConsoleCapabilities.plain, .emoji, .ansi])
    func leftEdgeAligned(capabilities: TapeConsoleCapabilities) {
        let entry = TapeEntry(
            level: .error,
            key: .httpRequest,
            message: "GET https://example.com\nsecond line",
            metadata: ["retry": 3]
        )

        let output = TapeBoxRenderer().render(
            entry,
            context: TapeRenderContext(theme: .default, capabilities: capabilities)
        )
        let lines = output
            .replacingOccurrences(
                of: "\u{001B}\\[[0-9;]*m",
                with: "",
                options: .regularExpression
            )
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.hasPrefix("┌") || $0.hasPrefix("│") || $0.hasPrefix("└") }

        #expect(lines.count == 6)
        #expect(lines.allSatisfy { $0 })
    }

    @Test("ANSI mode wraps the block in escape codes")
    func ansiMode() {
        let entry = TapeEntry(level: .error, message: "boom")

        let output = TapeBoxRenderer().render(
            entry,
            context: TapeRenderContext(theme: .default, capabilities: .ansi)
        )

        #expect(output.hasPrefix("\u{001B}[38;5;"))
        #expect(output.hasSuffix("\u{001B}[0m"))
    }

    @Test("Multi-line messages keep the gutter")
    func multiline() {
        let entry = TapeEntry(level: .info, message: "line one\nline two")

        let output = TapeBoxRenderer().render(
            entry,
            context: TapeRenderContext(theme: .default, capabilities: .plain)
        )

        #expect(output.contains("│ line one"))
        #expect(output.contains("│ line two"))
    }

    @Test("Metadata is rendered on a single sorted line")
    func metadata() {
        let entry = TapeEntry(
            level: .warning,
            message: "cache miss",
            metadata: ["retry": 3, "key": "feed"]
        )

        let output = TapeBoxRenderer().render(
            entry,
            context: TapeRenderContext(theme: .default, capabilities: .plain)
        )

        #expect(output.contains("│ key=feed, retry=3"))
    }

    @Test("The default key is not printed")
    func defaultKeyIsSilent() {
        let entry = TapeEntry(level: .debug, message: "x")

        #expect(entry.keyTitle == nil)
        #expect(entry.heading == "debug")
    }

    @Test("A custom key brings its own color and emoji")
    func customKeyStyle() {
        let key = TapeKey(
            "payments",
            level: .notice,
            color: TapeColor(light: 0x1B8A3A, dark: 0x30D158, ansi: 40, emoji: "💳")
        )
        let entry = TapeEntry(level: .notice, key: key, message: "charged")

        let output = TapeBoxRenderer().render(
            entry,
            context: TapeRenderContext(theme: .default, capabilities: .emoji)
        )

        #expect(output.contains("│ 💳 notice · payments |"))
        #expect(TapeTheme.default.color(for: entry).emoji == "💳")
    }

    @Test("A theme override wins over the color the key carries")
    func themeOverridesKey() {
        var theme = TapeTheme.default
        theme.keys["payments"] = TapeColor(
            light: 0x000000,
            dark: 0xFFFFFF,
            ansi: 99,
            emoji: "🏦"
        )
        let key = TapeKey(
            "payments",
            level: .notice,
            color: TapeColor(light: 0x1B8A3A, dark: 0x30D158, ansi: 40, emoji: "💳")
        )
        let entry = TapeEntry(level: .notice, key: key, message: "charged")

        let output = TapeBoxRenderer().render(
            entry,
            context: TapeRenderContext(theme: theme, capabilities: .emoji)
        )

        #expect(output.contains("│ 🏦 notice · payments |"))
    }

    @Test("A key color without emoji falls back to the level badge")
    func keyWithoutEmoji() {
        let key = TapeKey(
            "payments",
            level: .warning,
            color: TapeColor(light: 0x000000, dark: 0xFFFFFF, ansi: 99)
        )
        let entry = TapeEntry(level: .warning, key: key, message: "charged")

        let output = TapeBoxRenderer().render(
            entry,
            context: TapeRenderContext(theme: .default, capabilities: .emoji)
        )

        #expect(output.contains("│ 🟠 warning · payments |"))
    }
}
