import Foundation
import Observation
import TapeLogger
import TapeLoggerAdapters

@MainActor
@Observable
final class DemoServices {
    let adapters = TapeAdapters()
    let lifecycle = TapeLifecycleAdapter()
    private(set) var network: TapeURLSessionAdapter
    let session: URLSession
    var logsBodies = true
    var lifecycleEnabled = true
    var networkEnabled = true

    init() {
        let network = TapeURLSessionAdapter(options: Self.options(true))
        self.network = network
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        network.configure(configuration)
        session = URLSession(configuration: configuration)
        do {
            try adapters.install(lifecycle)
            try adapters.install(network)
        } catch {
            Tape.error("Could not install demo adapters", error: error)
        }
    }

    func updateNetwork() {
        // All configured sessions use the active adapter's settings. Existing
        // requests retain their original settings until they finish.
        adapters.removeAll()
        network = TapeURLSessionAdapter(options: Self.options(logsBodies))
        do {
            if lifecycleEnabled { try adapters.install(lifecycle) }
            if networkEnabled { try adapters.install(network) }
        } catch {
            Tape.error("Could not update demo adapters", error: error)
        }
    }

    private static func options(_ logsBodies: Bool) -> TapeNetworkOptions {
        .init(
            allowedHosts: [
                "httpbin.org", "jsonplaceholder.typicode.com",
                "tapelogger.invalid",
            ],
            logsBodies: logsBodies,
            bodyLimit: 512
        )
    }
}
