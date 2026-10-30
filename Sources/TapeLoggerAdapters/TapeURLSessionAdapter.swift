import Foundation
import os
import TapeLogger

/// Privacy and scope for HTTP logging. Bodies are opt-in and bounded.
public struct TapeNetworkOptions: Sendable {
    /// Exact, case-insensitive hosts; an empty set allows all HTTP(S) hosts.
    public var allowedHosts: Set<String>
    /// Enables bounded previews of supported text bodies; defaults to false.
    /// Body content is not automatically redacted.
    public var logsBodies: Bool
    /// Maximum captured bytes per body, initially 8192; init clamps negatives
    /// to zero. The actual request/response data is still forwarded in full.
    public var bodyLimit: Int
    /// Matched case-insensitively, in addition to the built-in sensitive names.
    public var redactedHeaders: Set<String>
    /// Additional case-insensitive query names to redact alongside built-ins.
    public var redactedQueryItems: Set<String>

    /// Configures capture scope before installation. Options are copied into the
    /// adapter and snapshotted for each intercepted request.
    ///
    /// - Parameters:
    ///   - allowedHosts: Exact hosts; empty permits all HTTP(S) hosts in opted-in
    ///     sessions. Subdomains are not implicitly included.
    ///   - logsBodies: Opt-in previews for appropriate test data.
    ///   - bodyLimit: Nonnegative preview byte limit; defaults to 8192.
    ///   - redactedHeaders: Extra sensitive headers. Built-in authorization,
    ///     proxy authorization, cookies, set-cookie and X-API-Key remain redacted.
    ///   - redactedQueryItems: Extra sensitive query names. Built-in credential
    ///     names remain redacted; URL user/password and fragments are removed.
    public init(
        allowedHosts: Set<String> = [],
        logsBodies: Bool = false,
        bodyLimit: Int = 8_192,
        redactedHeaders: Set<String> = [],
        redactedQueryItems: Set<String> = []
    ) {
        self.allowedHosts = allowedHosts
        self.logsBodies = logsBodies
        self.bodyLimit = max(0, bodyLimit)
        self.redactedHeaders = redactedHeaders
        self.redactedQueryItems = redactedQueryItems
    }
}

/// Adds logging to explicitly configured foreground URLSessions.
///
/// ```swift
/// let adapters = TapeAdapters()
/// let network = TapeURLSessionAdapter()
/// try adapters.install(network)
/// let configuration = URLSessionConfiguration.default
/// network.configure(configuration)
/// let session = URLSession(configuration: configuration)
/// ```
///
/// There is one active network adapter per process. Only sessions configured
/// with ``configure(_:)`` opt in; existing sessions are never modified.
/// Uninstall stops new interceptions; in-flight requests retain their settings.
///
/// The forwarding transport uses a standard URLSession configuration, not the
/// caller's delegates or transport settings. Do not use for custom trust,
/// client certificates, custom cookie/cache stores, background sessions,
/// WebSockets, or live streamed uploads. With bodies enabled, finite request
/// streams with a known size within the preview cap are buffered and replayed.
/// Larger or unknown-size streams are forwarded without being read for logging.
/// See the usage guide for capture scope and transport limitations.
@MainActor
public final class TapeURLSessionAdapter: TapeAdapter {
    /// Failure to acquire process-wide network-capture ownership.
    public enum InstallationError: Error {
        /// A different adapter instance is already installed in this process.
        case anotherNetworkAdapterIsInstalled
    }

    private let id = UUID()
    private let settings: NetworkSettings

    /// Creates an inactive network observer without modifying any sessions.
    ///
    /// - Parameters:
    ///   - tape: Logger receiving request, response and error entries.
    ///   - options: Capture and redaction policy, copied at initialization.
    public init(
        tape: Tape = .shared, options: TapeNetworkOptions = .init()
    ) {
        settings = NetworkSettings(tape: tape, options: options)
    }

    // Test transport injection stays out of the public API.
    init(
        tape: Tape, options: TapeNetworkOptions,
        transport: @escaping @Sendable () -> URLSessionConfiguration
    ) {
        settings = NetworkSettings(
            tape: tape, options: options, transport: transport
        )
    }

    /// Enables interception for explicitly configured sessions. Reinstalling this
    /// instance is a no-op; only one instance may own capture process-wide.
    /// - Throws: `InstallationError.anotherNetworkAdapterIsInstalled` when another
    ///   instance is active. Removal permits another instance to install.
    public func install() throws {
        try TapeLoggingURLProtocol.registry.withLock { state in
            guard state == nil || state?.id == id else {
                throw InstallationError.anotherNetworkAdapterIsInstalled
            }
            state = NetworkRegistration(id: id, settings: settings)
        }
    }

    /// Call before creating the URLSession. Other protocol classes are kept.
    /// Repeated calls do not duplicate this adapter's protocol class. This does
    /// not install the adapter, alter existing sessions, or opt in shared or
    /// background sessions. Only HTTP(S) requests matching host scope are logged.
    /// - Parameter configuration: Foreground configuration to opt into capture.
    public func configure(_ configuration: URLSessionConfiguration) {
        var classes = configuration.protocolClasses ?? []
        classes.removeAll { $0 == TapeLoggingURLProtocol.self }
        classes.insert(TapeLoggingURLProtocol.self, at: 0)
        configuration.protocolClasses = classes
    }

    /// Stops new interception owned by this instance. In-flight requests finish
    /// with their original settings; recorded history and configurations remain.
    public func uninstall() {
        TapeLoggingURLProtocol.registry.withLock { state in
            if state?.id == id { state = nil }
        }
    }
}

struct NetworkRegistration: Sendable {
    let id: UUID
    let settings: NetworkSettings
}

struct NetworkSettings: Sendable {
    let tape: Tape
    let options: TapeNetworkOptions
    var transport: @Sendable () -> URLSessionConfiguration = {
        .default
    }

    func accepts(_ request: URLRequest) -> Bool {
        guard let url = request.url,
              ["http", "https"].contains(url.scheme?.lowercased() ?? "")
        else { return false }
        return options.allowedHosts.isEmpty || options.allowedHosts.contains {
            $0.lowercased() == url.host?.lowercased()
        }
    }

    func safeURL(_ url: URL?) -> String {
        guard let url,
              var parts = URLComponents(
                url: url, resolvingAgainstBaseURL: false
              )
        else { return "<unknown URL>" }
        parts.user = nil
        parts.password = nil
        parts.fragment = nil
        let sensitive = Set([
            "token", "access_token", "refresh_token", "api_key", "apikey",
            "key", "password", "secret", "authorization", "code",
        ]).union(options.redactedQueryItems.map { $0.lowercased() })
        parts.queryItems = parts.queryItems?.map { item in
            sensitive.contains(item.name.lowercased())
                ? URLQueryItem(name: item.name, value: "<redacted>") : item
        }
        return parts.string ?? "<unknown URL>"
    }

    func safeHeaders(_ headers: [String: String]) -> [String: String] {
        let sensitive = Set([
            "authorization", "proxy-authorization", "cookie", "set-cookie",
            "x-api-key",
        ]).union(options.redactedHeaders.map { $0.lowercased() })
        return headers.reduce(into: [:]) { result, pair in
            result[pair.key] = sensitive.contains(pair.key.lowercased())
                ? "<redacted>" : pair.value
        }
    }

    /// CFNetwork turns ordinary POST data into a stream before URLProtocol
    /// sees it. Buffer only finite, small bodies and replace the consumed
    /// stream with those exact bytes. Never drain an unbounded upload.
    func prepareBody(_ request: NSMutableURLRequest) throws -> String? {
        guard options.logsBodies, request.httpBody == nil,
              let stream = request.httpBodyStream else { return nil }
        let limit = max(0, options.bodyLimit)
        guard let rawSize = request.value(forHTTPHeaderField: "Content-Length"),
              let size = Int(rawSize), size >= 0 else {
            return "<unknown-size request stream; body not captured>"
        }
        guard size <= limit else {
            return "<request stream exceeds \(limit)-byte capture limit>"
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: min(size, 4_096))
        while data.count < size {
            let count = stream.read(
                &buffer, maxLength: min(buffer.count, size - data.count)
            )
            guard count > 0 else {
                let error = stream.streamError
                    ?? URLError(.requestBodyStreamExhausted)
                throw error
            }
            data.append(contentsOf: buffer.prefix(count))
        }
        request.httpBodyStream = nil
        request.httpBody = data
        return nil
    }

    func body(_ data: Data?, contentType: String?) -> String? {
        guard options.logsBodies, let data, !data.isEmpty else { return nil }
        let type = contentType?.lowercased() ?? ""
        guard type.hasPrefix("text/") || type.contains("json")
                || type.contains("xml")
                || type.contains("x-www-form-urlencoded") else {
            return "<binary or unknown content type>"
        }
        let limit = max(0, options.bodyLimit)
        let prefix = data.prefix(limit)
        var text = String(decoding: prefix, as: UTF8.self)
        if data.count <= limit, type.contains("json"),
           let object = try? JSONSerialization.jsonObject(
               with: data, options: [.fragmentsAllowed]
           ),
           let pretty = try? JSONSerialization.data(
               withJSONObject: object,
               options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]
           ), pretty.count <= limit {
            text = String(decoding: pretty, as: UTF8.self)
        }
        if data.count > limit { text += "\n<truncated>" }
        return text
    }
}

// Every request snapshots the active settings. Mutable per-request state is
// protected because stopLoading can race with the serial delegate queue.
final class TapeLoggingURLProtocol: URLProtocol,
    URLSessionDataDelegate, @unchecked Sendable
{
    static let registry = OSAllocatedUnfairLock<NetworkRegistration?>(
        initialState: nil
    )
    private static let handledKey = "TapeLogger.forwarded"

    private struct Completion {
        let error: (any Error)?
        let notifyClient: Bool
    }

    private struct State {
        var stopped = false
        var requestLogged = false
        var pendingCompletion: Completion?
        var session: URLSession?
        var settings: NetworkSettings?
        var exchange: TapeHTTPExchange?
        var start = ContinuousClock.now
        var responseBody = Data()
        var responseSize = 0
        var responseType: String?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    override class func canInit(with request: URLRequest) -> Bool {
        guard URLProtocol.property(
            forKey: handledKey, in: request
        ) == nil else { return false }
        return registry.withLock { $0?.settings.accepts(request) ?? false }
    }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest { request }

    override func startLoading() {
        // Removal can race with canInit. Still forward the request, just
        // without logging; disabling an observer must not break networking.
        let settings: NetworkSettings? = Self.registry.withLock { entry in
            guard let settings = entry?.settings,
                  settings.accepts(request) else { return nil }
            return settings
        }
        let mutable = (request as NSURLRequest).mutableCopy()
        guard let forwarded = mutable as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        URLProtocol.setProperty(
            true, forKey: Self.handledKey, in: forwarded
        )
        var bodyNote: String?
        var bodyError: (any Error)?
        do {
            bodyNote = try settings?.prepareBody(forwarded)
        } catch {
            bodyError = error
            bodyNote = "<request stream could not be read>"
        }
        let configuration = settings?.transport() ?? .default
        configuration.protocolClasses = configuration.protocolClasses?.filter {
            $0 != TapeLoggingURLProtocol.self
        }
        let session = URLSession(
            configuration: configuration, delegate: self, delegateQueue: nil
        )
        let task = session.dataTask(with: forwarded as URLRequest)
        let exchange = settings.map { settings in
            TapeHTTPExchange(
                method: request.httpMethod ?? "GET",
                url: settings.safeURL(request.url),
                request: .init(
                    headers: settings.safeHeaders(
                        request.allHTTPHeaderFields ?? [:]
                    ),
                    body: settings.body(
                        forwarded.httpBody,
                        contentType: request.value(
                            forHTTPHeaderField: "Content-Type"
                        )
                    ) ?? bodyNote,
                    bodySize: forwarded.httpBody?.count
                        ?? request.value(forHTTPHeaderField: "Content-Length")
                            .flatMap(Int.init)
                        ?? (request.httpBodyStream == nil ? 0 : nil)
                )
            )
        }
        let started = state.withLock { state in
            guard !state.stopped else { return false }
            state.settings = settings
            state.exchange = exchange
            state.start = .now
            state.session = session
            return true
        }
        guard started else {
            session.invalidateAndCancel()
            return
        }
        if let settings, let exchange {
            var metadata: [String: TapeValue] = [
                "requestID": .string(requestID),
            ]
            if let bodyNote {
                metadata["requestBody"] = .string(bodyNote)
            }
            settings.tape.log(
                "\(exchange.method) \(exchange.url)", key: .httpRequest,
                metadata: metadata,
                attachment: .http(exchange)
            )
        }
        let pending = state.withLock { state in
            state.requestLogged = true
            return state.pendingCompletion
        }
        if let pending {
            finish(error: pending.error, notifyClient: pending.notifyClient)
        } else if let bodyError {
            finish(error: bodyError, notifyClient: true)
        } else {
            task.resume()
        }
    }

    private let requestID = UUID().uuidString

    override func stopLoading() {
        finish(error: URLError(.cancelled), notifyClient: false)
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (
            URLSession.ResponseDisposition
        ) -> Void
    ) {
        let active = captureResponse(response)
        if active {
            client?.urlProtocol(
                self, didReceive: response, cacheStoragePolicy: .notAllowed
            )
        }
        completionHandler(active ? .allow : .cancel)
    }

    private func captureResponse(_ response: URLResponse) -> Bool {
        state.withLock { state in
            guard !state.stopped else { return false }
            if let http = response as? HTTPURLResponse,
               let settings = state.settings {
                var headers: [String: String] = [:]
                for (key, value) in http.allHeaderFields {
                    headers[String(describing: key)] = String(describing: value)
                }
                state.exchange?.statusCode = http.statusCode
                state.exchange?.response = .init(
                    headers: settings.safeHeaders(headers)
                )
                state.responseType = http.value(
                    forHTTPHeaderField: "Content-Type"
                )
            }
            return true
        }
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        let active = state.withLock { state in
            guard !state.stopped else { return false }
            state.responseSize += data.count
            if let options = state.settings?.options, options.logsBodies {
                // One extra byte records truncation without retaining the body.
                let cap = max(0, min(options.bodyLimit, Int.max - 1)) + 1
                let remaining = max(0, cap - state.responseBody.count)
                state.responseBody.append(contentsOf: data.prefix(remaining))
            }
            return true
        }
        if active { client?.urlProtocol(self, didLoad: data) }
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        finish(error: error, notifyClient: true)
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        guard captureResponse(response) else {
            completionHandler(nil)
            return
        }
        // Let the original session apply its redirect policy and host scope.
        // Clear our marker so an allowed redirect is logged as a new request.
        let mutable = (request as NSURLRequest).mutableCopy()
        if let redirected = mutable as? NSMutableURLRequest {
            URLProtocol.removeProperty(
                forKey: Self.handledKey, in: redirected
            )
            if finish(error: nil, notifyClient: false) {
                client?.urlProtocol(
                    self, wasRedirectedTo: redirected as URLRequest,
                    redirectResponse: response
                )
            }
        } else {
            finish(error: URLError(.badURL), notifyClient: true)
        }
        completionHandler(nil)
    }

    @discardableResult
    private func finish(error: (any Error)?, notifyClient: Bool) -> Bool {
        let completed = state.withLock { state -> State? in
            guard !state.stopped else { return nil }
            // A sink may cancel synchronously while the request is being
            // recorded. Defer completion until that record leaves Tape's
            // reentrancy guard; never invoke sinks while holding this lock.
            if state.settings != nil, !state.requestLogged {
                if state.pendingCompletion == nil {
                    state.pendingCompletion = Completion(
                        error: error, notifyClient: notifyClient
                    )
                }
                return nil
            }
            state.stopped = true
            let completed = state
            state.session = nil
            state.responseBody = Data()
            return completed
        }
        guard let completed else { return false }
        defer { completed.session?.invalidateAndCancel() }
        if let settings = completed.settings,
           var exchange = completed.exchange {
            exchange.response?.body = settings.body(
                completed.responseBody, contentType: completed.responseType
            )
            exchange.response?.bodySize = completed.responseSize
            let failed = error != nil || (exchange.statusCode ?? 0) >= 400
            var metadata: [String: TapeValue] = [
                "requestID": .string(requestID),
            ]
            if let status = exchange.statusCode {
                metadata["statusCode"] = .int(status)
            }
            if let error {
                // Localized errors can contain the original, sensitive URL.
                let nsError = error as NSError
                metadata["errorDomain"] = .string(nsError.domain)
                metadata["errorCode"] = .int(nsError.code)
            }
            let status = exchange.statusCode.map(String.init)
                ?? (error == nil ? "completed" : "failed")
            settings.tape.log(
                "\(exchange.method) \(exchange.url) → \(status)",
                key: failed ? .httpError : .httpResponse,
                metadata: metadata,
                duration: ContinuousClock.now - completed.start,
                attachment: .http(exchange)
            )
        }
        if notifyClient {
            if let error {
                client?.urlProtocol(self, didFailWithError: error)
            } else {
                client?.urlProtocolDidFinishLoading(self)
            }
        }
        return true
    }
}
