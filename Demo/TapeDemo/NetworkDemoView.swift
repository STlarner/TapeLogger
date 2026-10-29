import SwiftUI
import TapeLogger

struct NetworkDemoView: View {
    @Bindable var services: DemoServices
    @State private var requestTask: Task<Void, Never>?
    @State private var result = "Choose a request, then open the console."
    @State private var isRunning = false

    var body: some View {
        NavigationStack {
            List {
                Section("Capture") {
                    Toggle("Network logging", isOn: $services.networkEnabled)
                    Toggle("Include bodies (512-byte cap)",
                           isOn: $services.logsBodies)
                    Text("Headers and sensitive query values are redacted. "
                         + "Body content is not redacted: use test data only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Live HTTPS requests") {
                    Button("GET · JSON response") {
                        run("https://jsonplaceholder.typicode.com/posts/1")
                    }
                    Button("POST · JSON, auth and cookies") {
                        run("https://httpbin.org/post", post: true)
                    }
                    Button("HTTP 404 · response, not a transport error") {
                        run("https://httpbin.org/status/404")
                    }
                    Button("Redirect · two HTTP exchanges") {
                        run("https://httpbin.org/redirect/1")
                    }
                    Button("Large JSON · truncated in the log only") {
                        run("https://jsonplaceholder.typicode.com/posts")
                    }
                    Button("Binary · body omitted") {
                        run("https://httpbin.org/image/png")
                    }
                    Button("Transport failure · invalid hostname") {
                        run("https://tapelogger.invalid/test")
                    }
                    Button("Host excluded · request works, no HTTP log") {
                        run("https://example.com")
                    }
                    Button("Slow request · tap Cancel to interrupt") {
                        run("https://httpbin.org/delay/10")
                    }
                }
                .disabled(isRunning)

                if isRunning {
                    Section {
                        HStack {
                            ProgressView()
                            Button("Cancel", role: .destructive) {
                                requestTask?.cancel()
                            }
                        }
                    }
                }
                Section("Result") {
                    Text(result)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
                Section {
                    Text("These are real requests to public test services. "
                         + "Availability, latency and redirects depend on "
                         + "the service and your connection.")
                        .font(.footnote)
                }
            }
            .navigationTitle("URLSession")
        }
        .onChange(of: services.logsBodies) { services.updateNetwork() }
        .onChange(of: services.networkEnabled) { services.updateNetwork() }
    }

    private func run(_ address: String, post: Bool = false) {
        guard let url = URL(string: address) else { return }
        isRunning = true
        result = "Request in progress…"
        requestTask = Task {
            defer { isRunning = false }
            var request = URLRequest(url: url)
            if post {
                var parts = URLComponents(
                    url: url, resolvingAgainstBaseURL: false
                )
                parts?.queryItems = [
                    URLQueryItem(name: "token", value: "demo-secret"),
                    URLQueryItem(name: "page", value: "1"),
                ]
                request.url = parts?.url
                request.httpMethod = "POST"
                request.setValue("application/json",
                                 forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer demo-secret",
                                 forHTTPHeaderField: "Authorization")
                request.setValue("session=demo-secret",
                                 forHTTPHeaderField: "Cookie")
                request.httpBody = Data(
                    #"{"message":"Hello from TapeDemo","items":[1,2,3]}"#.utf8
                )
            }
            do {
                let (data, response) = try await services.session.data(
                    for: request
                )
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                result = "HTTP \(status) · \(data.count) bytes\n\n"
                    + String(decoding: data.prefix(1_000), as: UTF8.self)
            } catch {
                result = "\(error)"
            }
        }
    }
}
