import AppKit

final class CornerWindow: NSWindow {
    init(size: NSSize) {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.minX + 12,
            y: visible.maxY - size.height - 12
        )

        super.init(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = true
        self.backgroundColor = NSColor(calibratedRed: 0.87, green: 0.82, blue: 0.72, alpha: 1)
        self.hasShadow = true
        self.level = .statusBar
        self.isMovableByWindowBackground = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { false }
}
