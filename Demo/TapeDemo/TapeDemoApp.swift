import SwiftUI
import TapeLogger
import TapeLoggerUI

@main
@MainActor
struct TapeDemoApp: App {
    @State private var services: DemoServices
    private let consoleSmoke = ProcessInfo.processInfo.arguments
        .contains("--console-smoke")

    init() {
        // Console in debug builds, unified log in release builds, and only
        // one of them when they would both write to Xcode's console.
        Tape.installRecommendedSinks(subsystem: "com.example.TapeDemo")
        _services = State(initialValue: DemoServices())
        Tape.info("TapeDemo launched")
        if consoleSmoke {
            for index in 1...150 {
                Tape.debug("Console history entry \(index)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if consoleSmoke {
                TapeConsoleView()
                    .task { Tape.info("Newest console entry") }
            } else {
                ContentView(services: services)
                    .tapeSceneLifecycle(name: "demo")
            }
        }
    }
}
