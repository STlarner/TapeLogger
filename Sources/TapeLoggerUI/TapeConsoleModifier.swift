import SwiftUI
import TapeLogger

/// Installs the way the console is opened: a floating button, a shake, or
/// nothing at all.
///
/// ```swift
/// WindowGroup { ContentView() }
///     #if DEBUG
///     .tapeConsole(trigger: .button)
///     #endif
/// ```
public struct TapeConsoleModifier: ViewModifier {
    private let store: TapeStore
    private let theme: TapeTheme
    private let trigger: TapeConsoleTrigger

    @State private var isPresented = false

    public init(store: TapeStore, theme: TapeTheme, trigger: TapeConsoleTrigger) {
        self.store = store
        self.theme = theme
        self.trigger = trigger
    }

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                if trigger == .button {
                    triggerButton
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

    private var triggerButton: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "ladybug.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(10)
                .background(.black.opacity(0.75), in: .circle)
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .padding(16)
        .accessibilityLabel("Open log console")
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

public extension View {
    /// Installs the in-app console.
    /// - Parameters:
    ///   - store: must be the store of the `Tape` instance you log through.
    ///   - theme: palette shared with the console renderer.
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
