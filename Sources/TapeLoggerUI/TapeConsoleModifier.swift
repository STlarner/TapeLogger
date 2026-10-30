import SwiftUI
import TapeLogger

/// Installs the way the console is opened: a floating button, a shake, or
/// nothing at all.
///
/// ```swift
/// struct DebugRoot: View {
///     var body: some View {
///         Text("Example")
///             .tapeConsole(trigger: .button)
///     }
/// }
/// ```
public struct TapeConsoleModifier: ViewModifier {
    private let store: TapeStore
    private let theme: TapeTheme
    private let trigger: TapeConsoleTrigger

    @State private var isPresented = false

    /// Creates a console presenter; prefer the `tapeConsole` view convenience.
    ///
    /// - Parameters:
    ///   - store: History presented in the sheet.
    ///   - theme: Palette for the trigger and console.
    ///   - trigger: How the sheet is opened; none installs no visible trigger.
    public init(store: TapeStore, theme: TapeTheme, trigger: TapeConsoleTrigger) {
        self.store = store
        self.theme = theme
        self.trigger = trigger
    }

    /// Adds the selected trigger and a console sheet without changing the content.
    public func body(content: Content) -> some View {
        content
            .overlay {
                if trigger == .button {
                    TapeFloatingConsoleButton(theme: theme) {
                        isPresented = true
                    }
                }
            }
            .background {
                if trigger == .shake {
                    shakeDetector
                }
            }
            .sheet(isPresented: $isPresented) {
                TapeConsoleView(store: store, theme: theme)
            }
    }

    @ViewBuilder
    private var shakeDetector: some View {
        #if os(iOS)
            TapeShakeDetector { isPresented = true }
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        #endif
    }
}

/// Adds optional console presentation to any SwiftUI view.
public extension View {
    /// Installs the in-app console.
    /// - Parameters:
    ///   - store: History to display; defaults to the shared logger's store.
    ///     Pass your logger's store when using a custom logger.
    ///   - theme: Palette for the floating button and in-app console.
    ///     Configure text sinks separately to use the same palette.
    ///   - trigger: `.button` (default), `.shake`, or `.none` if you present
    ///     `TapeConsoleView` yourself.
    func tapeConsole(
        store: TapeStore = Tape.shared.store,
        theme: TapeTheme = .default,
        trigger: TapeConsoleTrigger = .button
    ) -> some View {
        modifier(TapeConsoleModifier(store: store, theme: theme, trigger: trigger))
    }
}
