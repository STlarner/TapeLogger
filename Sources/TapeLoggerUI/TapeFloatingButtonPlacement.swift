import Foundation

/// Normalized placement survives resizing without storing screen coordinates.
/// Only horizontal edges dock; vertical bounds keep the handle reachable.
struct TapeFloatingButtonPlacement: Equatable {
    enum Edge: Equatable {
        case left
        case right
    }

    static let diameter: CGFloat = 44
    static let margin: CGFloat = 16
    static let defaultBottomClearance: CGFloat = 80
    private static let inset = diameter / 2 + margin

    private var horizontalFraction: CGFloat = 1
    private var verticalFraction: CGFloat?
    private(set) var edge: Edge? = .right

    func center(in size: CGSize) -> CGPoint {
        let horizontal = Self.bounds(for: size.width)
        let vertical = Self.bounds(for: size.height)
        let x: CGFloat
        switch edge {
        case .left: x = 0
        case .right: x = max(0, size.width)
        case nil:
            x = horizontal.lowerBound
                + horizontalFraction * Self.span(horizontal)
        }
        return CGPoint(
            x: x,
            y: verticalFraction.map {
                vertical.lowerBound + $0 * Self.span(vertical)
            } ?? max(
                vertical.lowerBound,
                vertical.upperBound - Self.defaultBottomClearance
            )
        )
    }

    func draggedCenter(translation: CGSize, in size: CGSize) -> CGPoint {
        let origin = center(in: size)
        return CGPoint(
            x: Self.clamp(
                origin.x + translation.width, to: 0...max(0, size.width)
            ),
            y: Self.clamp(
                origin.y + translation.height,
                to: Self.bounds(for: size.height)
            )
        )
    }

    /// During a drag, presentation follows the actual visible position rather
    /// than the edge saved at the previous release. Half a diameter inward
    /// makes the whole button visible, so the normal bug can be centered again.
    func indicatorEdge(
        translation: CGSize?, in size: CGSize
    ) -> Edge? {
        guard let translation else { return edge }
        let x = draggedCenter(translation: translation, in: size).x
        let radius = Self.diameter / 2
        if x < radius { return .left }
        if x > size.width - radius { return .right }
        return nil
    }

    mutating func settle(at point: CGPoint, in size: CGSize) {
        let horizontal = Self.bounds(for: size.width)
        let vertical = Self.bounds(for: size.height)
        verticalFraction = Self.fraction(point.y, in: vertical)
        if size.width > Self.inset * 2,
           point.x <= Self.inset {
            edge = .left
        } else if size.width > Self.inset * 2,
                  point.x >= size.width - Self.inset {
            edge = .right
        } else {
            edge = nil
        }
        horizontalFraction = Self.fraction(point.x, in: horizontal)
    }

    mutating func dock(to edge: Edge) {
        self.edge = edge
    }

    mutating func reveal() {
        switch edge {
        case .left: horizontalFraction = 0
        case .right: horizontalFraction = 1
        case nil: break
        }
        edge = nil
    }

    /// A docked tap reveals the handle; only an already-visible tap opens logs.
    mutating func handleTap() -> Bool {
        guard edge == nil else {
            reveal()
            return false
        }
        return true
    }

    private static func bounds(for length: CGFloat) -> ClosedRange<CGFloat> {
        let length = max(0, length)
        let inset = min(Self.inset, length / 2)
        return inset...(length - inset)
    }

    private static func span(_ bounds: ClosedRange<CGFloat>) -> CGFloat {
        bounds.upperBound - bounds.lowerBound
    }

    private static func clamp(
        _ value: CGFloat, to bounds: ClosedRange<CGFloat>
    ) -> CGFloat {
        min(max(value, bounds.lowerBound), bounds.upperBound)
    }

    private static func fraction(
        _ value: CGFloat, in bounds: ClosedRange<CGFloat>
    ) -> CGFloat {
        guard span(bounds) > 0 else { return 0.5 }
        return (clamp(value, to: bounds) - bounds.lowerBound) / span(bounds)
    }
}
