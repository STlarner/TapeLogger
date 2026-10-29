import SwiftUI
import TapeLoggerUI

struct ContentView: View {
    var services: DemoServices
    @State private var trigger: TapeConsoleTrigger = .button

    var body: some View {
        TabView {
            LoggingDemoView(trigger: $trigger)
                .tabItem { Label("Logs", systemImage: "ladybug") }
            NetworkDemoView(services: services)
                .tabItem { Label("Network", systemImage: "network") }
            NavigationDemoView()
                .tabItem {
                    Label("SwiftUI", systemImage: "arrow.triangle.branch")
                }
            UIKitNavigationDemo()
                .ignoresSafeArea(edges: .top)
                .tabItem { Label("UIKit", systemImage: "rectangle.stack") }
            LifecycleDemoView(services: services)
                .tabItem { Label("Lifecycle", systemImage: "app.badge") }
        }
        .tapeConsole(trigger: trigger)
    }
}

#Preview {
    ContentView(services: DemoServices())
}
