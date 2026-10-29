import SwiftUI
import TapeLogger
import TapeLoggerUI

struct ContentView: View {
    @State private var trigger: TapeConsoleTrigger = .button

    var body: some View {
        NavigationStack {
            List {
                Section("Levels") {
                    row("Trace", "Entered detail view") {
                        Tape.trace("Entered detail view")
                    }
                    row("Debug", "Cache hit for key feed") {
                        Tape.debug("Cache hit for key feed")
                    }
                    row("Info", "Session refreshed") {
                        Tape.info("Session refreshed")
                    }
                    row("Notice", "Background sync scheduled") {
                        Tape.notice("Background sync scheduled")
                    }
                    row("Warning", "Retry 2 of 3") {
                        Tape.warning("Retry 2 of 3")
                    }
                    row("Error", "Upload failed, with details") {
                        Tape.error(
                            "Upload failed",
                            error: URLError(.badServerResponse)
                        )
                    }
                    row("Critical", "Database unreachable") {
                        Tape.critical("Database unreachable")
                    }
                    row("Fault", "Invariant violated") {
                        Tape.fault("Invariant violated")
                    }
                }

                Section("Custom log type") {
                    row("payments", "custom type, own color, metadata") {
                        Tape.log(
                            PaymentLog(
                                "Charged the monthly plan",
                                amount: 12.90
                            )
                        )
                    }
                    row("payments", "same type, negative amount") {
                        Tape.log(PaymentLog("Refund issued", amount: -4.50))
                    }
                }

                Section("More to show") {
                    row("Metadata", "items=42, cached=false") {
                        Tape.info(
                            "Loaded feed",
                            metadata: ["items": 42, "cached": false]
                        )
                    }
                    row("Measured block", "duration in the header") {
                        Tape.measure("Reindex") {
                            Thread.sleep(forTimeInterval: 0.18)
                        }
                    }
                }

                Section("Console trigger") {
                    Picker("Trigger", selection: $trigger) {
                        Text("Floating button")
                            .tag(TapeConsoleTrigger.button)
                        Text("Shake")
                            .tag(TapeConsoleTrigger.shake)
                        Text("None")
                            .tag(TapeConsoleTrigger.none)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Tape")
        }
        .tapeConsole(trigger: trigger)
    }

    private func row(
        _ title: String,
        _ subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
