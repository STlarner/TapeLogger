import SwiftUI

/// How the in-app console is opened.
public enum TapeConsoleTrigger: Sendable, Equatable {
    /// Floating ladybug button in the bottom trailing corner.
    case button
    /// Physical device shake. Useful on device, invisible in the UI.
    case shake
    /// Nothing is installed: present `TapeConsoleView` yourself.
    case none
}

#if os(iOS)
    /// Forwards shake gestures from the responder chain to a closure.
    ///
    /// It lives as a zero-sized child of the hosting controller and asks to
    /// become first responder, which is what makes `motionEnded` fire. The
    /// gesture does not exist on Simulator: use a real device to test it.
    struct TapeShakeDetector: UIViewControllerRepresentable {
        let onShake: () -> Void

        func makeUIViewController(context: Context) -> ShakeController {
            ShakeController(onShake: onShake)
        }

        func updateUIViewController(_ controller: ShakeController, context: Context) {
            controller.onShake = onShake
        }

        final class ShakeController: UIViewController {
            var onShake: () -> Void

            init(onShake: @escaping () -> Void) {
                self.onShake = onShake
                super.init(nibName: nil, bundle: nil)
            }

            @available(*, unavailable)
            required init?(coder: NSCoder) {
                fatalError("init(coder:) is not supported")
            }

            override var canBecomeFirstResponder: Bool { true }

            override func viewWillAppear(_ animated: Bool) {
                super.viewWillAppear(animated)
                claimFirstResponder()
            }

            override func viewDidAppear(_ animated: Bool) {
                super.viewDidAppear(animated)
                claimFirstResponder()
            }

            override func viewWillDisappear(_ animated: Bool) {
                super.viewWillDisappear(animated)
                resignFirstResponder()
            }

            override func motionEnded(
                _ motion: UIEvent.EventSubtype,
                with event: UIEvent?
            ) {
                if motion == .motionShake {
                    onShake()
                }
                super.motionEnded(motion, with: event)
            }

            private func claimFirstResponder() {
                guard !isFirstResponder else { return }
                becomeFirstResponder()
            }
        }
    }
#endif
