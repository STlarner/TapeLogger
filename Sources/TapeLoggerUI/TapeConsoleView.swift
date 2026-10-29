import SwiftUI
import TapeLogger

/// In-app console: search, level filter, one card per entry.
///
/// Present it with `.tapeConsole()` or push it wherever you want in your
/// own debug menu.
@MainActor
public struct TapeConsoleView: View {
    @State private var model: TapeConsoleModel
    private let theme: TapeTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    public init(store: TapeStore = Tape.shared.store, theme: TapeTheme = .default) {
        _model = State(initialValue: TapeConsoleModel(store: store))
        self.theme = theme
    }

    public var body: some View {
        @Bindable var model = model

        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                Divider().opacity(0.3)
                list
            }
            .background(theme.background.color(for: colorScheme))
            .navigationTitle("Tape")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $model.searchText, prompt: "Search logs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear") { model.clear() }
                        .disabled(model.entries.isEmpty)
                }
            }
        }
        .task {
            await model.consume()
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.visibleEntries) { entry in
                        TapeEntryCard(entry: entry, theme: theme)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            // Unlike an onAppear scroll, this applies after the initial
            // layout, when lazy rows have their real positions.
            .defaultScrollAnchor(.bottom)
            .onChange(of: model.visibleEntries.last?.id) { _, id in
                scrollToBottom(proxy, id: id)
            }
            .overlay {
                if model.visibleEntries.isEmpty {
                    ContentUnavailableView(
                        "No logs",
                        systemImage: "text.alignleft",
                        description: Text(
                            model.entries.isEmpty
                                ? "Logs will appear here."
                                : "No entry matches the filter."
                        )
                    )
                }
            }
        }
    }

    private func scrollToBottom(
        _ proxy: ScrollViewProxy,
        id: TapeEntry.ID?
    ) {
        guard let id else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TapeLevel.allCases, id: \.self) { level in
                    levelChip(level)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func levelChip(_ level: TapeLevel) -> some View {
        let isOn = model.selectedLevels.contains(level)
        let tint = theme.color(for: level).color(for: colorScheme)

        return Button {
            if isOn {
                model.selectedLevels.remove(level)
            } else {
                model.selectedLevels.insert(level)
            }
        } label: {
            Text(level.label)
                .font(.system(.caption2, design: .monospaced, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundStyle(isOn ? tint : theme.secondary.color(for: colorScheme))
                .background(isOn ? tint.opacity(0.15) : .clear, in: .capsule)
                .overlay {
                    Capsule().strokeBorder(
                        isOn ? tint : theme.secondary.color(for: colorScheme).opacity(0.3),
                        lineWidth: 1
                    )
                }
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "Included" : "Excluded")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
