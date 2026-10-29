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
    /// let adapters = TapeAdapters()
    /// let lifecycle = TapeLifecycleAdapter()
/// try adapters.install(lifecycle)
/// ```
@MainActor
public final class TapeLifecycleAdapter: TapeAdapter {
    private let tape: Tape
    private let center: NotificationCenter
    private let observations = Observations()

    /// Creates an inactive application-notification observer.
    ///
    /// - Parameters:
    ///   - tape: Logger receiving lifecycle entries; defaults to shared.
    ///   - notificationCenter: Source of UIKit app notifications.
    public init(
        tape: Tape = .shared,
        notificationCenter: NotificationCenter = .default
    ) {
        self.tape = tape
        center = notificationCenter
    }

    /// Observes foreground, background, active and inactive transitions at debug
    /// severity with `scope: app`. Repeated installation is a no-op.
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

    /// Removes all installed notification observers without clearing history.
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
