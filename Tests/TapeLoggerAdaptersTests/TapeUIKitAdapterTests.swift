#if canImport(UIKit)
import Foundation
import TapeLogger
import TapeLoggerAdapters
import Testing
import UIKit

@Suite("UIKit adapters")
@MainActor
struct TapeUIKitAdapterTests {
    @Test("Lifecycle installation is idempotent and removal stops events")
    func lifecycle() {
        let tape = Tape(sinks: [])
        let center = NotificationCenter()
        let adapter = TapeLifecycleAdapter(
            tape: tape, notificationCenter: center
        )
        adapter.install()
        adapter.install()
        let notifications: [Notification.Name] = [
            UIApplication.willEnterForegroundNotification,
            UIApplication.didBecomeActiveNotification,
            UIApplication.willResignActiveNotification,
            UIApplication.didEnterBackgroundNotification,
        ]
        for name in notifications { center.post(name: name, object: nil) }
        #expect(tape.store.snapshot().count == 4)
        #expect(tape.store.snapshot().allSatisfy { $0.key == .lifecycle })
        adapter.uninstall()
        adapter.uninstall()
        center.post(name: notifications[0], object: nil)
        #expect(tape.store.snapshot().count == 4)
        adapter.install()
        center.post(name: notifications[0], object: nil)
        #expect(tape.store.snapshot().count == 5)
        adapter.uninstall()
    }

    @Test("Navigation records changed stacks and forwards the old delegate")
    func navigation() {
        let tape = Tape(sinks: [])
        let root = UIViewController()
        let detail = UIViewController()
        let navigation = UINavigationController(rootViewController: root)
        let delegate = NavigationDelegate()
        navigation.delegate = delegate
        let adapter = TapeNavigationAdapter(
            navigationController: navigation, tape: tape
        )
        adapter.install()
        adapter.install()
        navigation.setViewControllers([root, detail], animated: false)
        adapter.navigationController(
            navigation, didShow: detail, animated: false
        )
        #expect(tape.store.snapshot().last?.message.contains("push") == true)
        let count = tape.store.snapshot().count
        // A cancelled gesture ends on the original stack: no new entry.
        adapter.navigationController(
            navigation, didShow: detail, animated: true
        )
        #expect(tape.store.snapshot().count == count)
        #expect(delegate.didShowCount >= 2)
        let willShow = #selector(
            UINavigationControllerDelegate.navigationController(
                _:willShow:animated:
            )
        )
        #expect(adapter.responds(to: willShow))
        #expect(adapter.forwardingTarget(for: willShow) as? NavigationDelegate
            === delegate)
        navigation.setViewControllers([root], animated: false)
        adapter.navigationController(navigation, didShow: root, animated: false)
        #expect(tape.store.snapshot().last?.message.contains("pop") == true)
        let replacement = UIViewController()
        navigation.setViewControllers([replacement], animated: false)
        adapter.navigationController(
            navigation, didShow: replacement, animated: false
        )
        #expect(tape.store.snapshot().last?.message.contains("replace") == true)
        adapter.uninstall()
        #expect(navigation.delegate === delegate)
    }

    @Test("Removal never overwrites a delegate installed by the app later")
    func replacementDelegate() {
        let navigation = UINavigationController()
        let adapter = TapeNavigationAdapter(navigationController: navigation)
        adapter.install()
        let replacement = NavigationDelegate()
        navigation.delegate = replacement
        adapter.uninstall()
        #expect(navigation.delegate === replacement)
    }
}

@MainActor
private final class NavigationDelegate: NSObject,
    UINavigationControllerDelegate
{
    var didShowCount = 0

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController, animated: Bool
    ) {
        didShowCount += 1
    }

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController, animated: Bool
    ) {}
}
#endif
