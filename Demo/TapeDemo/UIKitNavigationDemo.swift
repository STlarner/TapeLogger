import SwiftUI
import TapeLoggerAdapters
import UIKit

struct UIKitNavigationDemo: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UINavigationController {
        let navigation = UINavigationController(
            rootViewController: NavigationDemoController(number: 0)
        )
        navigation.delegate = context.coordinator.delegate
        let adapter = TapeNavigationAdapter(
            navigationController: navigation, name: "uikit-demo"
        ) { $0.title ?? String(describing: type(of: $0)) }
        adapter.install()
        context.coordinator.adapter = adapter
        return navigation
    }

    func updateUIViewController(
        _ controller: UINavigationController, context: Context
    ) {}

    static func dismantleUIViewController(
        _ controller: UINavigationController, coordinator: Coordinator
    ) {
        coordinator.adapter?.uninstall()
    }

    @MainActor
    final class Coordinator {
        let delegate = DemoNavigationDelegate()
        var adapter: TapeNavigationAdapter?
    }
}

@MainActor
final class DemoNavigationDelegate: NSObject, UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController, animated: Bool
    ) {
        viewController.navigationItem.prompt = "Original delegate still works"
    }
}

@MainActor
private final class NavigationDemoController: UIViewController {
    private let number: Int

    init(number: Int) {
        self.number = number
        super.init(nibName: nil, bundle: nil)
        title = number == 0 ? "UIKit navigation" : "Screen \(number)"
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let instructions = UILabel()
        instructions.text = "Try push, pop, reset, and swipe-back. Cancel an "
            + "interactive swipe: no pop should be logged. The prompt above "
            + "is set by the original delegate, through the adapter."
        instructions.numberOfLines = 0
        instructions.font = .preferredFont(forTextStyle: .body)
        stack.addArrangedSubview(instructions)
        button("Push", in: stack) { [weak self] in
            guard let self else { return }
            navigationController?.pushViewController(
                NavigationDemoController(number: number + 1), animated: true
            )
        }
        button("Pop", in: stack) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        button("Pop to root", in: stack) { [weak self] in
            self?.navigationController?.popToRootViewController(animated: true)
        }
        button("Replace stack", in: stack) { [weak self] in
            self?.navigationController?.setViewControllers([
                NavigationDemoController(number: 0),
                NavigationDemoController(number: 100),
            ], animated: true)
        }
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24
            ),
            stack.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24
            ),
            stack.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24
            ),
        ])
    }

    private func button(
        _ title: String, in stack: UIStackView,
        action: @escaping @MainActor () -> Void
    ) {
        let button = UIButton(configuration: .tinted())
        button.setTitle(title, for: .normal)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        stack.addArrangedSubview(button)
    }
}
