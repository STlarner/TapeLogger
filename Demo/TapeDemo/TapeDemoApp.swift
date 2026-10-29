import SwiftUI
import TapeLogger
import TapeLoggerUI

@main
struct TapeDemoApp: App {
    init() {
        // Console in debug builds, unified log in release builds, and only
        // one of them when they would both write to Xcode's console.
        Tape.installRecommendedSinks(subsystem: "com.example.TapeDemo")
        Tape.info("TapeDemo launched")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
