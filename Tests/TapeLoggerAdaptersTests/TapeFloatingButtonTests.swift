import Foundation
import Testing
@testable import TapeLoggerUI

@Suite("Floating console button")
struct TapeFloatingButtonTests {
    private let size = CGSize(width: 390, height: 800)

    @Test("The button starts docked on the right above bottom bars")
    func initialPlacement() {
        let placement = TapeFloatingButtonPlacement()
        #expect(placement.center(in: size) == CGPoint(x: 390, y: 682))
        #expect(placement.edge == .right)
    }

    @Test("The first docked tap reveals and the second opens the console")
    func tapping() {
        var placement = TapeFloatingButtonPlacement()
        let firstTap = placement.handleTap()
        #expect(!firstTap)
        #expect(placement.edge == nil)
        #expect(placement.center(in: size) == CGPoint(x: 352, y: 682))
        let secondTap = placement.handleTap()
        #expect(secondTap)
        placement.dock(to: .left)
        let leftReveal = placement.handleTap()
        #expect(!leftReveal)
        #expect(placement.center(in: size) == CGPoint(x: 38, y: 682))
        let leftOpen = placement.handleTap()
        #expect(leftOpen)
    }

    @Test("Releasing in the interior keeps the chosen position")
    func interiorPlacement() {
        var placement = TapeFloatingButtonPlacement()
        let target = CGPoint(x: 150, y: 260)
        placement.settle(at: target, in: size)
        #expect(placement.edge == nil)
        #expect(abs(placement.center(in: size).x - target.x) < 0.001)
        #expect(abs(placement.center(in: size).y - target.y) < 0.001)
    }

    @Test("The right arrow becomes a bug during the drag at full visibility")
    func rightIndicatorThreshold() {
        let placement = TapeFloatingButtonPlacement()
        #expect(placement.indicatorEdge(translation: nil, in: size) == .right)
        #expect(placement.indicatorEdge(
            translation: CGSize(width: -21, height: 0), in: size
        ) == .right)
        #expect(placement.indicatorEdge(
            translation: CGSize(width: -22, height: 0), in: size
        ) == nil)
        #expect(placement.indicatorEdge(
            translation: CGSize(width: -100, height: 0), in: size
        ) == nil)
        // The saved docking state has not changed yet: the finger is down.
        #expect(placement.edge == .right)
    }

    @Test("The left arrow changes at the same inward threshold")
    func leftIndicatorThreshold() {
        var placement = TapeFloatingButtonPlacement()
        placement.dock(to: .left)
        #expect(placement.indicatorEdge(
            translation: CGSize(width: 21, height: 0), in: size
        ) == .left)
        #expect(placement.indicatorEdge(
            translation: CGSize(width: 22, height: 0), in: size
        ) == nil)
    }

    @Test("Dragging a visible bug into an edge changes it back to an arrow")
    func draggingTowardEdge() {
        var placement = TapeFloatingButtonPlacement()
        placement.settle(at: CGPoint(x: 200, y: 300), in: size)
        #expect(placement.indicatorEdge(
            translation: CGSize(width: -190, height: 0), in: size
        ) == .left)
        #expect(placement.indicatorEdge(
            translation: CGSize(width: 180, height: 0), in: size
        ) == .right)
        #expect(placement.indicatorEdge(translation: .zero, in: size) == nil)
    }

    @Test("Both side edges hide exactly half of the button")
    func edgeSnapping() {
        var placement = TapeFloatingButtonPlacement()
        placement.settle(at: CGPoint(x: 20, y: 300), in: size)
        #expect(placement.edge == .left)
        #expect(placement.center(in: size).x == 0)
        #expect(abs(placement.center(in: size).y - 300) < 0.001)
        placement.settle(at: CGPoint(x: 375, y: 300), in: size)
        #expect(placement.edge == .right)
        #expect(placement.center(in: size).x == size.width)
    }

    @Test("A docked button can be dragged fully back into the screen")
    func draggingInward() {
        var placement = TapeFloatingButtonPlacement()
        placement.dock(to: .right)
        let destination = placement.draggedCenter(
            translation: CGSize(width: -90, height: -200), in: size
        )
        placement.settle(at: destination, in: size)
        #expect(placement.edge == nil)
        #expect(placement.center(in: size) == CGPoint(x: 300, y: 482))
    }

    @Test("Dragging cannot lose the handle above or below the container")
    func clamping() {
        let placement = TapeFloatingButtonPlacement()
        let top = placement.draggedCenter(
            translation: CGSize(width: -5_000, height: -5_000), in: size
        )
        #expect(top == CGPoint(x: 0, y: 38))
        let bottom = placement.draggedCenter(
            translation: CGSize(width: 5_000, height: 5_000), in: size
        )
        #expect(bottom == CGPoint(x: 390, y: 762))
    }

    @Test("Docking and relative height survive rotation and window resizing")
    func resizing() {
        var placement = TapeFloatingButtonPlacement()
        placement.settle(at: CGPoint(x: 390, y: 400), in: size)
        let rotated = CGSize(width: 800, height: 390)
        #expect(placement.center(in: rotated) == CGPoint(x: 800, y: 195))
        placement.reveal()
        #expect(placement.edge == nil)
        #expect(placement.center(in: rotated) == CGPoint(x: 762, y: 195))
    }

    @Test("Small and initially empty containers have finite positions")
    func smallContainers() {
        var placement = TapeFloatingButtonPlacement()
        #expect(placement.center(in: .zero) == .zero)
        let small = CGSize(width: 40, height: 40)
        placement.settle(at: CGPoint(x: 1_000, y: -1_000), in: small)
        #expect(placement.center(in: small) == CGPoint(x: 20, y: 20))
        #expect(placement.edge == nil)
    }
}
