#if canImport(UIKit)
import Foundation
import TapeLogger
import UIKit

/// Records app transitions, not individual window/scene transitions.
///
/// No launch or termination is inferred: iOS can kill an app without sending
/// a notification. Use `tapeSceneLifecycle` for a SwiftUI scene's state.
///
/// ```swift
/// let lifecycle = TapeLifecycleAdapter()
/// try adapters.install(lifecycle)
/// ```
@MainActor
public final class TapeLifecycleAdapter: TapeAdapter {
    private let tape: Tape
    private let center: NotificationCenter
    private let observations = Observations()

    public init(
        tape: Tape = .shared,
        notificationCenter: NotificationCenter = .default
    ) {
        self.tape = tape
        center = notificationCenter
    }

    public func install() {
        guard observations.tokens.isEmpty else { return }
        let events: [(Notification.Name, String)] = [
            (UIApplication.willEnterForegroundNotification, "foreground"),
            (UIApplication.didEnterBackgroundNotification, "background"),
            (UIApplication.didBecomeActiveNotification, "active"),
            (UIApplication.willResignActiveNotification, "inactive"),
        ]
        for (name, event) in events {
            let tape = tape
            let token = center.addObserver(
                forName: name, object: nil, queue: nil
            ) { _ in
                tape.log(
                    "App \(event)", key: .lifecycle,
                    metadata: ["scope": "app", "event": .string(event)]
                )
            }
            observations.tokens.append((center, token))
        }
    }

    public func uninstall() {
        observations.removeAll()
    }
}

// NotificationCenter supports removal on any thread, including deinit.
private final class Observations: @unchecked Sendable {
    var tokens: [(NotificationCenter, any NSObjectProtocol)] = []

    func removeAll() {
        for (center, token) in tokens {
            center.removeObserver(token)
        }
        tokens.removeAll()
    }

    deinit { removeAll() }
}
#endif
