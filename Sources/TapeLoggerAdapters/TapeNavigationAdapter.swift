#if canImport(UIKit)
import Foundation
import TapeLogger
import UIKit

/// Observes completed stack transitions, including interactive back gestures.
/// Existing delegate methods (including custom animations) are forwarded.
///
/// Install one adapter per navigation controller, retain it, and uninstall it
/// before releasing it. If the app replaces the delegate, observation stops;
/// uninstall never overwrites that replacement.
///
/// ```swift
/// let adapters = TapeAdapters()
/// let navigationController = UINavigationController()
/// try adapters.install(
///     TapeNavigationAdapter(navigationController: navigationController)
/// )
/// ```
@MainActor
public final class TapeNavigationAdapter: NSObject,
    TapeAdapter, UINavigationControllerDelegate
{
    private weak var navigationController: UINavigationController?
    private nonisolated let forwarding = NavigationDelegateReference()
    private var previousDelegate: (any UINavigationControllerDelegate)? {
        get { forwarding.delegate }
        set { forwarding.delegate = newValue }
    }
    private var stack: [UIViewController] = []
    private let tape: Tape
    private let name: String
    private let describe: (UIViewController) -> String
    private var isInstalled = false

    /// Creates an inactive observer without taking ownership of the controller.
    ///
    /// - Parameters:
    ///   - navigationController: Controller to observe weakly.
    ///   - name: Stable stack label recorded in metadata.
    ///   - tape: Logger receiving navigation entries; defaults to shared.
    ///   - describe: Destination label; defaults to its controller type name.
    ///     Avoid including secrets or personal screen content.
    public init(
        navigationController: UINavigationController,
        name: String = "navigation",
        tape: Tape = .shared,
        describe: @escaping (UIViewController) -> String = {
            String(describing: type(of: $0))
        }
    ) {
        self.navigationController = navigationController
        self.name = name
        self.tape = tape
        self.describe = describe
        super.init()
    }

    /// Snapshots the current stack and replaces the delegate with a forwarding
    /// observer. No initial event is emitted. Retain the previous delegate in
    /// your app as usual; forwarding keeps only a weak reference to it.
    public func install() {
        guard !isInstalled, let navigationController else { return }
        previousDelegate = navigationController.delegate
        stack = navigationController.viewControllers
        isInstalled = true
        navigationController.delegate = self
    }

    /// Restores the prior delegate only if this adapter is still the delegate.
    /// Safe after the app replaces the delegate or releases the controller.
    public func uninstall() {
        guard isInstalled else { return }
        if let navigationController,
           navigationController.delegate === self {
            navigationController.delegate = previousDelegate
        }
        previousDelegate = nil
        stack.removeAll()
        isInstalled = false
    }

    /// UIKit callback that compares completed stacks, logs push/pop/replace at
    /// debug severity, and forwards to the previous delegate. Cancelled gestures
    /// with an unchanged stack do not create an entry. Not for direct invocation.
    public func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        let next = navigationController.viewControllers
        let oldIDs = stack.map(ObjectIdentifier.init)
        let newIDs = next.map(ObjectIdentifier.init)
        if oldIDs != newIDs {
            let event: String
            if newIDs.starts(with: oldIDs) {
                event = "push"
            } else if oldIDs.starts(with: newIDs) {
                event = "pop"
            } else {
                event = "replace"
            }
            let destination = describe(viewController)
            tape.log(
                "\(name): \(event) → \(destination)",
                key: .navigation,
                metadata: [
                    "stack": .string(name), "event": .string(event),
                    "fromDepth": .int(stack.count),
                    "toDepth": .int(next.count),
                    "destination": .string(destination),
                ]
            )
            stack = next
        }
        previousDelegate?.navigationController?(
            navigationController, didShow: viewController, animated: animated
        )
    }

    /// Reports callbacks implemented by this adapter or its previous delegate.
    /// UIKit may query capabilities outside actor-isolated transition callbacks.
    public nonisolated override func responds(to selector: Selector) -> Bool {
        super.responds(to: selector)
            || forwarding.delegate?.responds(to: selector) == true
    }

    /// Forwards supported Objective-C delegate callbacks to the previous delegate,
    /// including custom animation and interaction-controller callbacks.
    public nonisolated override func forwardingTarget(
        for selector: Selector
    ) -> Any? {
        if let delegate = forwarding.delegate,
           delegate.responds(to: selector) {
            return delegate
        }
        return super.forwardingTarget(for: selector)
    }
}

// Objective-C capability queries are nonisolated even on a UIKit delegate.
// Protect only the weak reference; navigation callbacks remain main-actor-only.
private final class NavigationDelegateReference: @unchecked Sendable {
    private let lock = NSLock()
    private weak var value: (any UINavigationControllerDelegate)?

    var delegate: (any UINavigationControllerDelegate)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            value = newValue
        }
    }
}
#endif
