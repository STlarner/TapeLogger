import Foundation
import TapeLogger
import Testing
@testable import TapeLoggerAdapters

@Suite("URLSession logging", .serialized)
@MainActor
struct TapeNetworkTests {
    @Test("Only HTTP requests in the configured host scope are accepted")
    func scope() throws {
        let settings = NetworkSettings(
            tape: Tape(sinks: []),
            options: .init(allowedHosts: ["EXAMPLE.COM"])
        )
        let allowed = try #require(URL(string: "https://example.com/a"))
        let other = try #require(URL(string: "https://other.example/a"))
        let file = try #require(URL(string: "file:///example.com/a"))
        #expect(settings.accepts(URLRequest(url: allowed)))
        #expect(!settings.accepts(URLRequest(url: other)))
        #expect(!settings.accepts(URLRequest(url: file)))
        var stream = URLRequest(url: allowed)
        stream.httpBodyStream = InputStream(data: Data())
        #expect(settings.accepts(stream))
    }

    @Test("Credentials and sensitive headers and query items are redacted")
    func redaction() throws {
        let settings = NetworkSettings(
            tape: Tape(sinks: []),
            options: .init(
                redactedHeaders: ["X-Private"],
                redactedQueryItems: ["customer"]
            )
        )
        let url = try #require(URL(string:
            "https://user:pass@example.com/a?token=secret"
                + "&customer=42&q=ok#secret"
        ))
        let safe = settings.safeURL(url)
        #expect(!safe.contains("secret"))
        #expect(!safe.contains("user"))
        #expect(!safe.contains("pass"))
        #expect(!safe.contains("42"))
        #expect(safe.contains("q=ok"))
        let headers = settings.safeHeaders([
            "AUTHORIZATION": "secret", "Cookie": "secret",
            "Set-Cookie": "secret", "X-Private": "secret", "Accept": "ok",
        ])
        #expect(headers.values.filter { $0 == "<redacted>" }.count == 4)
        #expect(headers["Accept"] == "ok")
    }

    @Test("Bodies are opt-in, bounded and do not render binary payloads")
    func bodies() {
        let tape = Tape(sinks: [])
        let data = Data("abcdef".utf8)
        let defaults = NetworkSettings(tape: tape, options: .init())
        #expect(defaults.body(data, contentType: "text/plain") == nil)
        let enabled = NetworkSettings(
            tape: tape, options: .init(logsBodies: true, bodyLimit: 3)
        )
        #expect(enabled.body(data, contentType: "text/plain")
            == "abc\n<truncated>")
        #expect(enabled.body(data, contentType: "image/png")
            == "<binary or unknown content type>")
        #expect(TapeNetworkOptions(bodyLimit: -1).bodyLimit == 0)
    }

    @Test("Complete JSON is pretty printed only when the preview fits")
    func json() {
        let settings = NetworkSettings(
            tape: Tape(sinks: []), options: .init(logsBodies: true)
        )
        let rendered = settings.body(
            Data(#"{"b":2,"a":1}"#.utf8), contentType: "application/json"
        )
        #expect(rendered?.contains("\n") == true)
        #expect(rendered?.contains(#""a" : 1"#) == true)
        let limited = NetworkSettings(
            tape: Tape(sinks: []),
            options: .init(logsBodies: true, bodyLimit: 13)
        )
        #expect(limited.body(
            Data(#"{"b":2,"a":1}"#.utf8), contentType: "application/json"
        ) == #"{"b":2,"a":1}"#)
    }

    @Test("Configuration is idempotent and only one network source is active")
    func installation() throws {
        let adapter = TapeURLSessionAdapter(tape: Tape(sinks: []))
        try adapter.install()
        defer { adapter.uninstall() }
        try adapter.install()
        let configuration = URLSessionConfiguration.ephemeral
        adapter.configure(configuration)
        adapter.configure(configuration)
        let matches = configuration.protocolClasses?.filter {
            $0 == TapeLoggingURLProtocol.self
        }
        #expect(matches?.count == 1)
        let other = TapeURLSessionAdapter()
        #expect(throws: TapeURLSessionAdapter.InstallationError.self) {
            try other.install()
        }
        other.uninstall()
        let url = try #require(URL(string: "https://example.com"))
        #expect(TapeLoggingURLProtocol.canInit(with: URLRequest(url: url)))
        adapter.uninstall()
        #expect(!TapeLoggingURLProtocol.canInit(with: URLRequest(url: url)))
    }

    @Test("Requests and responses preserve data and share a correlation ID")
    func exchange() async throws {
        let tape = Tape(sinks: [])
        let adapter = makeAdapter(tape: tape, logsBodies: true, limit: 5)
        try adapter.install()
        defer { adapter.uninstall() }
        let configuration = URLSessionConfiguration.ephemeral
        adapter.configure(configuration)
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let url = try #require(URL(string:
            "https://example.com/success?token=private"
        ))
        var request = URLRequest(url: url)
        request.setValue("Bearer private", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        #expect(data == Data("hello world".utf8))
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        let entries = tape.store.snapshot()
        #expect(entries.count == 2)
        #expect(entries.first?.key == .httpRequest)
        #expect(entries.last?.key == .httpResponse)
        #expect(entries.last?.duration != nil)
        let requestID = try #require(
            entries.first?.metadata["requestID"]?.description
        )
        #expect(!requestID.isEmpty)
        #expect(requestID == entries.last?.metadata["requestID"]?.description)
        #expect(!entries.map(\.message).joined().contains("private"))
        let last = try #require(entries.last)
        guard case .http(let exchange) = last.attachment else {
            Issue.record("Expected an HTTP exchange")
            return
        }
        #expect(exchange.request.headers["Authorization"] == "<redacted>")
        #expect(exchange.response?.body == "hello\n<truncated>")
        #expect(exchange.response?.bodySize == 11)
        #expect(exchange.response?.headers["Set-Cookie"] == "<redacted>")
    }

    @Test("HTTP failures keep their response and transport failures throw")
    func failures() async throws {
        let tape = Tape(sinks: [])
        let adapter = makeAdapter(tape: tape)
        try adapter.install()
        defer { adapter.uninstall() }
        let configuration = URLSessionConfiguration.ephemeral
        adapter.configure(configuration)
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let statusURL = try #require(URL(string: "https://example.com/status"))
        let (_, response) = try await session.data(from: statusURL)
        #expect((response as? HTTPURLResponse)?.statusCode == 503)
        #expect(tape.store.snapshot().last?.key == .httpError)
        let errorURL = try #require(URL(string: "https://example.com/error"))
        await #expect(throws: (any Error).self) {
            try await session.data(from: errorURL)
        }
        #expect(tape.store.snapshot().count == 4)
        #expect(tape.store.snapshot().last?.key == .httpError)
        #expect(tape.store.snapshot().last?.metadata["errorCode"] != nil)
    }

    @Test("POST bodies are captured and replayed without changing their bytes")
    func post() async throws {
        let tape = Tape(sinks: [])
        let adapter = makeAdapter(tape: tape, logsBodies: true)
        try adapter.install()
        defer { adapter.uninstall() }
        let configuration = URLSessionConfiguration.ephemeral
        adapter.configure(configuration)
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let url = try #require(URL(string: "https://example.com/post"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(#"{"test":true}"#.utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await session.data(for: request)
        #expect(data == request.httpBody)
        let entries = tape.store.snapshot()
        #expect(entries.count == 2)
        guard case .http(let exchange) = entries.first?.attachment else {
            Issue.record("Expected the POST request")
            return
        }
        #expect(exchange.method == "POST")
        #expect(exchange.request.body?.contains("true") == true)
        #expect(exchange.request.bodySize == request.httpBody?.count)
        guard case .http(let completed) = entries.last?.attachment else {
            Issue.record("Expected the completed exchange")
            return
        }
        #expect(completed.request.body == exchange.request.body)
        #expect(completed.response?.body == String(
            decoding: data, as: UTF8.self
        ))
    }

    @Test("Large request streams are forwarded intact without buffering them")
    func largePost() async throws {
        let tape = Tape(sinks: [])
        let adapter = makeAdapter(tape: tape, logsBodies: true, limit: 5)
        try adapter.install()
        defer { adapter.uninstall() }
        let configuration = URLSessionConfiguration.ephemeral
        adapter.configure(configuration)
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let url = try #require(URL(string: "https://example.com/post"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data("larger than the preview cap".utf8)
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await session.data(for: request)
        #expect(data == request.httpBody)
        guard case .http(let exchange) = tape.store.snapshot().last?.attachment
        else {
            Issue.record("Expected an HTTP exchange")
            return
        }
        #expect(exchange.request.body?.contains("capture limit") == true)
        #expect(exchange.response?.body == "large\n<truncated>")
    }

    @Test("Body logging off does not read or capture a request stream")
    func bodyCaptureDisabled() throws {
        let settings = NetworkSettings(
            tape: Tape(sinks: []), options: .init()
        )
        let url = try #require(URL(string: "https://example.com/post"))
        let request = NSMutableURLRequest(url: url)
        let stream = InputStream(data: Data("private".utf8))
        request.httpBodyStream = stream
        request.setValue("7", forHTTPHeaderField: "Content-Length")
        #expect(try settings.prepareBody(request) == nil)
        #expect(stream.streamStatus == .notOpen)
        #expect(request.httpBody == nil)
    }

    @Test("Finite request streams within the cap are replaced byte for byte")
    func finiteBodyStream() throws {
        let settings = NetworkSettings(
            tape: Tape(sinks: []),
            options: .init(logsBodies: true, bodyLimit: 5)
        )
        let url = try #require(URL(string: "https://example.com/post"))
        let request = NSMutableURLRequest(url: url)
        let bytes = Data("hello".utf8)
        request.httpBodyStream = InputStream(data: bytes)
        request.setValue("5", forHTTPHeaderField: "Content-Length")
        #expect(try settings.prepareBody(request) == nil)
        #expect(request.httpBody == bytes)
        #expect(request.httpBodyStream == nil)
    }

    @Test("Unknown-size and oversized request streams remain unopened")
    func unavailableBodyStream() throws {
        let settings = NetworkSettings(
            tape: Tape(sinks: []),
            options: .init(logsBodies: true, bodyLimit: 5)
        )
        let url = try #require(URL(string: "https://example.com/post"))
        let request = NSMutableURLRequest(url: url)
        let stream = InputStream(data: Data("longer than the cap".utf8))
        request.httpBodyStream = stream
        #expect(try settings.prepareBody(request)?.contains("unknown-size")
            == true)
        #expect(stream.streamStatus == .notOpen)
        request.setValue("19", forHTTPHeaderField: "Content-Length")
        #expect(try settings.prepareBody(request)?.contains("capture limit")
            == true)
        #expect(stream.streamStatus == .notOpen)
        #expect(request.httpBody == nil)
    }

    private func makeAdapter(
        tape: Tape, logsBodies: Bool = false, limit: Int = 8_192
    ) -> TapeURLSessionAdapter {
        TapeURLSessionAdapter(
            tape: tape,
            options: .init(logsBodies: logsBodies, bodyLimit: limit),
            transport: {
                let config = URLSessionConfiguration.ephemeral
                config.protocolClasses = [FixtureURLProtocol.self]
                return config
            }
        )
    }

    @Test("Unconfigured sessions and requests after removal are not logged")
    func optIn() async throws {
        let tape = Tape(sinks: [])
        let adapter = makeAdapter(tape: tape)
        try adapter.install()
        defer { adapter.uninstall() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureURLProtocol.self]
        let plain = URLSession(configuration: configuration)
        defer { plain.invalidateAndCancel() }
        let url = try #require(URL(string: "https://example.com/success"))
        _ = try await plain.data(from: url)
        #expect(tape.store.snapshot().isEmpty)
        adapter.configure(configuration)
        let observed = URLSession(configuration: configuration)
        defer { observed.invalidateAndCancel() }
        _ = try await observed.data(from: url)
        #expect(tape.store.snapshot().count == 2)
        adapter.uninstall()
        _ = try await observed.data(from: url)
        #expect(tape.store.snapshot().count == 2)
    }

    @Test("Cancellation is forwarded and records exactly one completion")
    func cancellation() async throws {
        let tape = Tape(sinks: [])
        let adapter = makeAdapter(tape: tape)
        try adapter.install()
        defer { adapter.uninstall() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        adapter.configure(configuration)
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let url = try #require(URL(string: "https://example.com/pending"))
        var entries = tape.store.stream.makeAsyncIterator()
        let pending = Task { try await session.data(from: url) }
        let request = await entries.next()
        #expect(request?.key == .httpRequest)
        adapter.uninstall()
        pending.cancel()
        await #expect(throws: (any Error).self) { try await pending.value }
        let completion = await entries.next()
        #expect(completion?.key == .httpError)
        #expect(tape.store.snapshot().count == 2)
    }

    @Test("A cancelling sink cannot reorder or suppress the completion")
    func reentrantCancellation() throws {
        let tape = Tape(sinks: [])
        let adapter = makeAdapter(tape: tape)
        try adapter.install()
        defer { adapter.uninstall() }
        let url = try #require(URL(string: "https://example.com/pending"))
        let source = TapeLoggingURLProtocol(
            request: URLRequest(url: url), cachedResponse: nil, client: nil
        )
        tape.addSink(CancellingSink(source: source))
        source.startLoading()
        #expect(tape.store.snapshot().map(\.key) == [.httpRequest, .httpError])
        tape.removeAllSinks()
    }
}

private struct CancellingSink: TapeSink {
    let source: TapeLoggingURLProtocol

    func record(_ entry: TapeEntry) {
        if entry.key == .httpRequest { source.stopLoading() }
    }
}

private final class FixtureURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        if url.path == "/pending" { return }
        if url.path == "/error" {
            client?.urlProtocol(
                self, didFailWithError: URLError(.notConnectedToInternet)
            )
            return
        }
        guard let response = HTTPURLResponse(
            url: url, statusCode: url.path == "/status" ? 503 : 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "text/plain", "Set-Cookie": "private",
            ]
        ) else { return }
        client?.urlProtocol(
            self, didReceive: response, cacheStoragePolicy: .notAllowed
        )
        if url.path == "/post" {
            var data = request.httpBody ?? Data()
            if let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 1_024)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    guard count > 0 else { break }
                    data.append(contentsOf: buffer.prefix(count))
                }
            }
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        client?.urlProtocol(self, didLoad: Data("hello ".utf8))
        client?.urlProtocol(self, didLoad: Data("world".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
