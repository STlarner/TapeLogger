import SwiftUI
import TapeLogger

struct LifecycleDemoView: View {
    @Environment(\.scenePhase) private var phase
    @Bindable var services: DemoServices

    var body: some View {
        NavigationStack {
            List {
                Section("Application") {
                    Toggle("Observe app lifecycle",
                           isOn: $services.lifecycleEnabled)
                    LabeledContent(
                        "Scene phase", value: String(describing: phase)
                    )
                    Text("Go to the Home Screen, return to the app, or open "
                         + "Control Center. Real notifications are recorded; "
                         + "this screen does not simulate them.")
                }
                Section("App vs scene") {
                    Text("App events come from TapeLifecycleAdapter. Scene "
                         + "events come from tapeSceneLifecycle on the app's "
                         + "root view and remain enabled independently.")
                    Text("iOS does not guarantee a termination callback. "
                         + "There is no automatic 'app closed' log.")
                }
                Section("Recent lifecycle entries") {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let entries = Tape.shared.store.snapshot()
                            .filter { $0.key == .lifecycle }.suffix(10)
                        ForEach(Array(entries)) { entry in
                            Text(entry.message)
                                .font(.footnote.monospaced())
                        }
                    }
                }
            }
            .navigationTitle("Lifecycle")
        }
        .onChange(of: services.lifecycleEnabled) { services.updateNetwork() }
    }
}
