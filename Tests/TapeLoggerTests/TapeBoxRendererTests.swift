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
        #expect(lines[1].hasPrefix("│ ⚠️ warning |"))
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

        #expect(output.contains("│ ⚠️ warning · payments |"))
    }

    @Test("The default width fits the Xcode console")
    func defaultWidth() {
        let entry = TapeEntry(level: .info, message: "ok")
        let context = TapeRenderContext(
            theme: .default,
            capabilities: TapeConsoleCapabilities(mode: .none)
        )

        let lines = TapeBoxRenderer().render(entry, context: context)
            .split(separator: "\n")

        #expect(context.capabilities.maxWidth == 77)
        #expect(lines.first?.count == 77)
        #expect(lines.last?.count == 77)
        #expect(lines.allSatisfy { $0.count <= 77 })
    }

    @Test("Every box has the same width, whatever the message")
    func fixedWidth() {
        let short = TapeEntry(level: .info, message: "ok")
        let long = TapeEntry(
            level: .info,
            message: String(repeating: "word ", count: 80)
        )
        let context = TapeRenderContext(
            theme: .default,
            capabilities: TapeConsoleCapabilities(mode: .none, maxWidth: 40)
        )

        let shortLines = TapeBoxRenderer().render(short, context: context)
            .split(separator: "\n")
        let longLines = TapeBoxRenderer().render(long, context: context)
            .split(separator: "\n")

        #expect(shortLines.first?.count == 40)
        #expect(shortLines.last?.count == 40)
        #expect(longLines.first?.count == 40)
        #expect(longLines.last?.count == 40)
        #expect(longLines.allSatisfy { $0.count <= 40 })
    }

    @Test("Long text wraps on spaces and keeps the gutter")
    func wrapsOnSpaces() {
        let message = "the quick brown fox jumps over the lazy dog again"
        let entry = TapeEntry(level: .info, message: message)
        let capabilities = TapeConsoleCapabilities(mode: .none, maxWidth: 30)

        let lines = TapeBoxRenderer()
            .render(entry, context: TapeRenderContext(capabilities: capabilities))
            .split(separator: "\n", omittingEmptySubsequences: false)

        #expect(lines.count > 3)
        #expect(lines.allSatisfy { $0.count <= 30 })
        #expect(lines.dropFirst().dropLast().allSatisfy { $0.hasPrefix("│ ") })
        #expect(
            lines.dropFirst(2).dropLast().map { $0.dropFirst(2) }
                .joined(separator: " ") == message
        )
    }

    @Test("A word wider than the box is hard-broken")
    func hardBreak() {
        let url = String(repeating: "a", count: 60)

        #expect(
            TapeBoxRenderer.wrap(url, width: 20)
                == [
                    String(repeating: "a", count: 20),
                    String(repeating: "a", count: 20),
                    String(repeating: "a", count: 20),
                ]
        )
    }

    @Test("The box never gets narrower than the minimum")
    func minimumWidth() {
        let entry = TapeEntry(level: .info, message: "ok")
        let capabilities = TapeConsoleCapabilities(mode: .none, maxWidth: 5)

        let first = TapeBoxRenderer()
            .render(entry, context: TapeRenderContext(capabilities: capabilities))
            .split(separator: "\n")
            .first

        #expect(first?.count == TapeBoxRenderer.minimumWidth)
    }

    @Test("Every content section normalizes line endings and keeps empty rows")
    func physicalLines() {
        let entry = TapeEntry(
            level: .info,
            key: TapeKey("multi\r\nline"),
            message: "one\r\ntwo\rthree\n\nfive",
            metadata: ["payload\nkey": "first\r\nsecond"],
            source: TapeSource(file: "File\nName.swift", function: "work"),
            attachment: .custom(id: "test", payload: "custom\rpayload")
        )
        let output = TapeBoxRenderer(showsSource: true).render(
            entry, context: TapeRenderContext(capabilities: .plain)
        )
        let rows = output.components(separatedBy: "\n")
        #expect(!output.contains("\r"))
        #expect(rows.dropFirst().dropLast().allSatisfy {
            $0.hasPrefix("│ ")
        })
        #expect(output.contains("│ one\n│ two\n│ three\n│ \n│ five"))
        #expect(output.contains("│ second"))
        #expect(output.contains("│ custom\n│ payload"))
    }

    @Test("Payload terminal controls are escaped in every color mode",
          arguments: [TapeConsoleCapabilities.plain, .emoji, .ansi])
    func terminalControls(capabilities: TapeConsoleCapabilities) {
        let payload = "hello\u{1B}[2J\u{1B}]0;spoof\u{7}\u{8}\t\u{9B}"
        let entry = TapeEntry(
            level: .info, message: payload,
            metadata: ["control": "\u{1B}[H"],
            attachment: .error("\u{1B}[31mROOT")
        )
        let output = TapeBoxRenderer().render(
            entry, context: TapeRenderContext(capabilities: capabilities)
        )
        let body = output.replacingOccurrences(
            of: "\u{1B}\\[[0-9;]*m", with: "", options: .regularExpression
        )
        #expect(!body.unicodeScalars.contains {
            $0.value < 32 && $0.value != 10 || (127...159).contains($0.value)
        })
        #expect(body.contains("\\u{1b}[2J"))
        #expect(body.contains("\\u{7}"))
        #expect(entry.message == payload)
    }

    @Test("Wide characters and emoji wrap by display columns",
          arguments: ["界", "😀", "👩‍💻", "🇮🇹", "❤️", "e\u{301}"])
    func displayColumns(glyph: String) {
        let entry = TapeEntry(
            level: .info, message: String(repeating: glyph, count: 100)
        )
        let output = TapeBoxRenderer().render(
            entry, context: TapeRenderContext(capabilities:
                TapeConsoleCapabilities(mode: .none, maxWidth: 40))
        )
        let rows = output.components(separatedBy: "\n")
        #expect(rows.allSatisfy { row in
            row.reduce(0) { $0 + TapeTerminalText.columns($1) } <= 40
        })
        let restored = rows.dropFirst(2).dropLast()
            .map { String($0.dropFirst(2)) }.joined()
        #expect(restored == entry.message)
    }

    @Test("Large unbroken messages wrap without losing text")
    func largeMessage() {
        let message = String(repeating: "a", count: 800_000)
        let wrapped = TapeBoxRenderer.wrap(message, width: 75)
        #expect(wrapped.joined() == message)
        #expect(wrapped.allSatisfy { $0.count <= 75 })
    }

    @Test("Every attachment is available in console and copied text")
    func attachments() {
        for attachment in [
            TapeAttachment.error("ROOT CAUSE"),
            .stackTrace("frame detail"),
            .custom(id: "custom", payload: "custom detail"),
        ] {
            let entry = TapeEntry(
                level: .error, message: "failure", attachment: attachment
            )
            let output = TapeBoxRenderer().render(
                entry, context: TapeRenderContext(capabilities: .plain)
            )
            #expect(output.contains(attachment.text))
            #expect(entry.copyText.contains(attachment.text))
        }
    }
}
