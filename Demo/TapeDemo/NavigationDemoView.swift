import SwiftUI
import TapeLoggerUI

struct NavigationDemoView: View {
    @State private var opaque = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("Path type", selection: $opaque) {
                Text("Typed routes").tag(false)
                Text("NavigationPath").tag(true)
            }
            .pickerStyle(.segmented)
            .padding()
            if opaque {
                OpaqueNavigationDemo()
            } else {
                TypedNavigationDemo()
            }
        }
    }
}

private struct TypedNavigationDemo: View {
    @State private var routes: [Int] = []

    var body: some View {
        NavigationStack(path: $routes) {
            screen(0)
                .navigationDestination(for: Int.self) { screen($0) }
        }
        .tapeNavigation(path: $routes, name: "swiftui-typed") {
            "Screen \($0)"
        }
    }

    private func screen(_ number: Int) -> some View {
        List {
            Section("Stack: \(routes.description)") {
                Button("Push next screen") { routes.append(number + 1) }
                Button("Push two screens (deep link)") {
                    routes.append(contentsOf: [number + 1, number + 2])
                }
                Button("Pop") {
                    if !routes.isEmpty { routes.removeLast() }
                }
                .disabled(routes.isEmpty)
                Button("Pop to root") { routes.removeAll() }
                    .disabled(routes.isEmpty)
                Button("Replace stack") { routes = [100, 101] }
            }
            Section {
                Text("The system Back button and swipe-back update the same "
                     + "path. These logs describe SwiftUI state changes, "
                     + "not animation completion callbacks.")
            }
        }
        .navigationTitle(number == 0 ? "Typed routes" : "Screen \(number)")
    }
}

private struct OpaqueNavigationDemo: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            screen
                .navigationDestination(for: Int.self) { _ in screen }
        }
        .tapeNavigation(path: $path, name: "swiftui-opaque")
    }

    private var screen: some View {
        List {
            Section("Depth: \(path.count)") {
                Button("Push") { path.append(path.count + 1) }
                Button("Pop") {
                    if !path.isEmpty { path.removeLast() }
                }
                .disabled(path.isEmpty)
                Button("Pop to root") { path = NavigationPath() }
                Button("Replace with a different route at the same depth") {
                    if path.isEmpty {
                        path.append(100)
                    } else {
                        path.removeLast()
                        path.append(Int.random(in: 100...999))
                    }
                }
            }
            Section {
                Text("NavigationPath does not expose its elements. Logs "
                     + "contain depth changes, not destination names. "
                     + "A replacement that changes depth is indistinguishable "
                     + "from a push or pop.")
            }
        }
        .navigationTitle("Opaque path")
    }
}
