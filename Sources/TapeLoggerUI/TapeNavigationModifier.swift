import SwiftUI
import TapeLogger

extension View {
    /// Observes route state, without requiring a particular router.
    /// Attach once per stack. Route descriptions should not contain secrets.
    /// Events describe path changes, not animation completion. SwiftUI may
    /// coalesce several mutations into one view update.
    ///
    /// ```swift
    /// NavigationStack(path: $routes) { HomeView() }
    ///     .tapeNavigation(path: $routes, name: "main")
    /// ```
    public func tapeNavigation<Route: Hashable>(
        path: Binding<[Route]>,
        name: String = "navigation",
        tape: Tape = .shared,
        describe: @escaping (Route) -> String = { String(describing: $0) }
    ) -> some View {
        onChange(of: path.wrappedValue) { old, new in
            guard let event = tapeNavigationEvent(from: old, to: new) else {
                return
            }
            recordNavigation(
                event, name: name, from: old.count, to: new.count,
                destination: new.last.map(describe) ?? "root", tape: tape
            )
        }
    }

    /// `NavigationPath` hides its elements: only depth and opaque replacement
    /// events can be recorded. Typed arrays provide destination names.
    public func tapeNavigation(
        path: Binding<NavigationPath>,
        name: String = "navigation",
        tape: Tape = .shared
    ) -> some View {
        onChange(of: path.wrappedValue) { old, new in
            let event = new.count > old.count ? "push"
                : new.count < old.count ? "pop" : "replace"
            recordNavigation(
                event, name: name, from: old.count, to: new.count,
                destination: nil, tape: tape
            )
        }
    }

    /// Records a scene separately from application-wide notifications.
    /// Supply a stable name to distinguish windows in multi-scene apps.
    public func tapeSceneLifecycle(
        name: String = "main", tape: Tape = .shared
    ) -> some View {
        modifier(TapeSceneLifecycleModifier(name: name, tape: tape))
    }
}

func tapeNavigationEvent<Route: Equatable>(
    from old: [Route], to new: [Route]
) -> String? {
    guard old != new else { return nil }
    if new.starts(with: old) { return "push" }
    if old.starts(with: new) { return "pop" }
    return "replace"
}

func recordNavigation(
    _ event: String, name: String, from: Int, to: Int,
    destination: String?, tape: Tape
) {
    var metadata: [String: TapeValue] = [
        "stack": .string(name), "event": .string(event),
        "fromDepth": .int(from), "toDepth": .int(to),
    ]
    if let destination {
        metadata["destination"] = .string(destination)
    }
    let suffix = destination.map { " → \($0)" } ?? " (depth \(to))"
    tape.log("\(name): \(event)\(suffix)", key: .navigation, metadata: metadata)
}

private struct TapeSceneLifecycleModifier: ViewModifier {
    @Environment(\.scenePhase) private var phase
    let name: String
    let tape: Tape

    func body(content: Content) -> some View {
        content.onChange(of: phase, initial: true) { _, phase in
            let event: String
            switch phase {
            case .active: event = "active"
            case .inactive: event = "inactive"
            case .background: event = "background"
            @unknown default: event = "unknown"
            }
            tape.log(
                "Scene \(name): \(event)", key: .lifecycle,
                metadata: [
                    "scope": "scene", "scene": .string(name),
                    "event": .string(event),
                ]
            )
        }
    }
}
