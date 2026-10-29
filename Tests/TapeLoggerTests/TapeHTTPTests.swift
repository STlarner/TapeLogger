import Testing
@testable import TapeLogger

@Suite("HTTP presentation")
struct TapeHTTPTests {
    @Test("Requests and responses share a color but keep their own badges")
    func colors() throws {
        let request = TapeEntry(level: .info, key: .httpRequest, message: "GET")
        let response = TapeEntry(
            level: .info, key: .httpResponse, message: "200"
        )
        let theme = TapeTheme.default
        let sent = theme.color(for: request)
        let received = theme.color(for: response)
        #expect(sent.light == received.light)
        #expect(sent.dark == received.dark)
        #expect(sent.ansi == received.ansi)
        #expect(theme.emoji(for: request) == "📤")
        #expect(theme.emoji(for: response) == "📥")
        let error = try #require(TapeKey.httpError.color)
        #expect(error.light != sent.light)
    }

    @Test("Copied HTTP entries include both labeled bodies")
    func copyBodies() {
        let entry = exchangeEntry()
        #expect(entry.copyText.contains("Request body:\n{\"sent\":true}"))
        #expect(entry.copyText.contains("Response body:\n{\"received\":true}"))
    }

    @Test("Console boxes render request and response body previews")
    func renderedBodies() {
        let output = TapeBoxRenderer().render(
            exchangeEntry(),
            context: TapeRenderContext(
                theme: .default,
                capabilities: TapeConsoleCapabilities(mode: .none)
            )
        )
        #expect(output.contains("Request body:"))
        #expect(output.contains("{\"sent\":true}"))
        #expect(output.contains("Response body:"))
        #expect(output.contains("{\"received\":true}"))
    }

    private func exchangeEntry() -> TapeEntry {
        TapeEntry(
            level: .info, key: .httpResponse, message: "POST /example → 200",
            attachment: .http(TapeHTTPExchange(
                method: "POST", url: "https://example.com", statusCode: 200,
                request: .init(body: #"{"sent":true}"#),
                response: .init(body: #"{"received":true}"#)
            ))
        )
    }
}
