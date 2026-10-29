import SwiftUI
import TapeLogger

/// The geometry fills the overlay, but only the circular button handles hits.
/// Clipping at the physical horizontal edges leaves exactly half visible.
struct TapeFloatingConsoleButton: View {
    let theme: TapeTheme
    let onOpen: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var placement = TapeFloatingButtonPlacement()
    @GestureState private var translation: CGSize?

    private static let coordinateSpace = "TapeLogger.floatingButton"

    var body: some View {
        GeometryReader { geometry in
            let indicatorEdge = placement.indicatorEdge(
                translation: translation, in: geometry.size
            )
            Button {
                if placement.handleTap() { onOpen() }
            } label: {
                Image(systemName: symbolName(for: indicatorEdge))
                    .font(.system(
                        size: indicatorEdge == nil ? 15 : 12,
                        weight: .semibold
                    ))
                    .foregroundStyle(theme.card.color(for: colorScheme))
                    // Center the arrow in the visible semicircle, rather
                    // than clipping half of the glyph at the screen edge.
                    .offset(x: symbolOffset(for: indicatorEdge))
                    .frame(
                        width: TapeFloatingButtonPlacement.diameter,
                        height: TapeFloatingButtonPlacement.diameter
                    )
                    .background(
                        theme.text.color(for: colorScheme).opacity(0.85),
                        in: .circle
                    )
                    .overlay {
                        Circle().strokeBorder(
                            theme.card.color(for: colorScheme).opacity(0.15),
                            lineWidth: 1
                        )
                    }
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            // Once a drag is recognized it wins over Button's tap gesture.
            .highPriorityGesture(drag(in: geometry.size))
            .accessibilityLabel(placement.edge == nil
                ? "Open log console" : "Show debug button")
            .accessibilityHint(
                placement.edge == nil
                    ? "Drag to move."
                    : "Tap or drag inward to reveal the debug button."
            )
            .accessibilityAction(named: Text("Move away from edge")) {
                withAnimation(.snappy(duration: 0.25)) { placement.reveal() }
            }
            .accessibilityAction(named: Text("Move to left edge")) {
                withAnimation(.snappy(duration: 0.25)) {
                    placement.dock(to: .left)
                }
            }
            .accessibilityAction(named: Text("Move to right edge")) {
                withAnimation(.snappy(duration: 0.25)) {
                    placement.dock(to: .right)
                }
            }
            .position(center(in: geometry.size))
            .animation(.snappy(duration: 0.25), value: placement)
        }
        .coordinateSpace(name: Self.coordinateSpace)
        .ignoresSafeArea(.container, edges: .horizontal)
        .clipped()
    }

    private func symbolName(
        for edge: TapeFloatingButtonPlacement.Edge?
    ) -> String {
        switch edge {
        case .left: "chevron.right"
        case .right: "chevron.left"
        case nil: "ladybug.fill"
        }
    }

    private func symbolOffset(
        for edge: TapeFloatingButtonPlacement.Edge?
    ) -> CGFloat {
        switch edge {
        case .left: TapeFloatingButtonPlacement.diameter / 4
        case .right: -TapeFloatingButtonPlacement.diameter / 4
        case nil: 0
        }
    }

    private func center(in size: CGSize) -> CGPoint {
        if let translation {
            return placement.draggedCenter(translation: translation, in: size)
        }
        return placement.center(in: size)
    }

    private func drag(in size: CGSize) -> some Gesture {
        DragGesture(
            minimumDistance: 6,
            coordinateSpace: .named(Self.coordinateSpace)
        )
        .updating($translation) { value, translation, _ in
            translation = value.translation
        }
        .onEnded { value in
            placement.settle(
                at: placement.draggedCenter(
                    translation: value.translation, in: size
                ),
                in: size
            )
        }
    }
}
