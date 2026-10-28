import SwiftUI
import TapeLogger

/// Adds a floating trigger that opens the console in a sheet.
///
/// ```swift
/// WindowGroup { ContentView() }
///     #if DEBUG
///     .tapeConsole()
///     #endif
/// ```
public struct TapeConsoleModifier: ViewModifier {
    private let store: TapeStore
    private let theme: TapeTheme
    private let showsTrigger: Bool

    @State private var isPresented = false

    public init(store: TapeStore, theme: TapeTheme, showsTrigger: Bool) {
        self.store = store
        self.theme = theme
        self.showsTrigger = showsTrigger
    }

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                if showsTrigger {
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
            }
            .sheet(isPresented: $isPresented) {
                TapeConsoleView(store: store, theme: theme)
            }
    }
}

public extension View {
    /// Installs the in-app console.
    /// - Parameters:
    ///   - store: must be the store of the `Tape` instance you log through.
    ///   - theme: palette shared with the console renderer.
    ///   - showsTrigger: set `false` if you present `TapeConsoleView` yourself.
    func tapeConsole(
        store: TapeStore = Tape.shared.store,
        theme: TapeTheme = .default,
        showsTrigger: Bool = true
    ) -> some View {
        modifier(TapeConsoleModifier(store: store, theme: theme, showsTrigger: showsTrigger))
    }
}
