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
        #expect(lines[1].hasPrefix("│ http-request |"))
        #expect(lines[1].contains("584ms"))
        #expect(lines[2] == "│ [GET] https://example.com")
        #expect(lines[3].hasPrefix("└"))
    }

    @Test("Emoji mode prefixes the block and indents the rest")
    func emojiMode() {
        let entry = TapeEntry(level: .warning, message: "cache miss")

        let output = TapeBoxRenderer().render(
            entry,
            context: TapeRenderContext(theme: .default, capabilities: .emoji)
        )

        #expect(output.hasPrefix("🟠 ┌"))
        #expect(output.contains("\n  │ log |"))
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
}
