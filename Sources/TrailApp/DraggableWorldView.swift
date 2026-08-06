import SpriteKit

/// Lets the borderless world window be dragged from anywhere in its scene.
final class DraggableWorldView: SKView {
    override var mouseDownCanMoveWindow: Bool { true }
}
