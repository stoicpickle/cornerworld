import AppKit

@MainActor
enum MenuBarPresentation {
    static func overlandIcon(accent: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 23, height: 16))
        image.lockFocus()
        let color = NSColor.controlTextColor

        let canvas = NSBezierPath()
        canvas.move(to: NSPoint(x: 2.5, y: 7.5))
        canvas.line(to: NSPoint(x: 2.5, y: 9))
        canvas.curve(
            to: NSPoint(x: 6, y: 14),
            controlPoint1: NSPoint(x: 2.5, y: 11.8),
            controlPoint2: NSPoint(x: 4, y: 14)
        )
        canvas.line(to: NSPoint(x: 12, y: 14))
        canvas.curve(
            to: NSPoint(x: 15.5, y: 9),
            controlPoint1: NSPoint(x: 14, y: 14),
            controlPoint2: NSPoint(x: 15.5, y: 11.8)
        )
        canvas.line(to: NSPoint(x: 15.5, y: 7.5))
        canvas.close()
        color.withAlphaComponent(0.18).setFill()
        canvas.fill()
        color.setStroke()
        canvas.lineWidth = 1.25
        canvas.lineJoinStyle = .round
        canvas.stroke()

        let body = NSBezierPath(
            roundedRect: NSRect(x: 1.5, y: 5, width: 15, height: 3.5),
            xRadius: 0.75,
            yRadius: 0.75
        )
        color.setFill()
        body.fill()

        let tongue = NSBezierPath()
        tongue.move(to: NSPoint(x: 16, y: 7))
        tongue.line(to: NSPoint(x: 19.25, y: 5.25))
        color.setStroke()
        tongue.lineWidth = 1.25
        tongue.lineCapStyle = .round
        tongue.stroke()

        for x in [3.0, 12.0] {
            let wheel = NSBezierPath(ovalIn: NSRect(x: x, y: 1.5, width: 4, height: 4))
            color.setStroke()
            wheel.lineWidth = 1.25
            wheel.stroke()
        }

        accent.setFill()
        NSBezierPath(ovalIn: NSRect(x: 19, y: 11.5, width: 3.5, height: 3.5)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    static func farmIcon(accent: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 23, height: 16))
        image.lockFocus()
        let color = NSColor.controlTextColor

        let roof = NSBezierPath()
        roof.move(to: NSPoint(x: 1.5, y: 8))
        roof.line(to: NSPoint(x: 9, y: 15))
        roof.line(to: NSPoint(x: 16.5, y: 8))
        roof.close()
        color.setFill()
        roof.fill()

        let barn = NSBezierPath(rect: NSRect(x: 3, y: 2, width: 12, height: 7))
        color.withAlphaComponent(0.82).setFill()
        barn.fill()

        accent.withAlphaComponent(0.78).setFill()
        NSBezierPath(rect: NSRect(x: 7, y: 2, width: 4, height: 5)).fill()

        accent.setStroke()
        let stem = NSBezierPath()
        stem.move(to: NSPoint(x: 19, y: 2))
        stem.line(to: NSPoint(x: 19, y: 10))
        stem.lineWidth = 1.25
        stem.lineCapStyle = .round
        stem.stroke()
        accent.setFill()
        NSBezierPath(ovalIn: NSRect(x: 15.5, y: 7, width: 4, height: 3)).fill()
        NSBezierPath(ovalIn: NSRect(x: 18.5, y: 9, width: 4, height: 3)).fill()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    static func overlandTitle(
        miles: Int,
        alive: Int,
        total: Int,
        accent: NSColor
    ) -> NSAttributedString {
        let milesText = " \(miles) mi"
        let separator = " · "
        let partyText = "\(alive)/\(total)"
        let title = NSMutableAttributedString(string: milesText + separator + partyText)
        let digitFont = NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .medium)
        title.addAttributes(
            [.foregroundColor: NSColor.labelColor, .font: digitFont],
            range: NSRange(location: 0, length: (milesText as NSString).length)
        )
        title.addAttributes(
            [.foregroundColor: NSColor.secondaryLabelColor, .font: digitFont],
            range: NSRange(
                location: (milesText as NSString).length,
                length: (separator as NSString).length
            )
        )
        title.addAttributes(
            [
                .foregroundColor: alive < total ? accent : NSColor.secondaryLabelColor,
                .font: NSFont.monospacedDigitSystemFont(
                    ofSize: 12.5,
                    weight: alive < total ? .semibold : .regular
                ),
            ],
            range: NSRange(
                location: (milesText as NSString).length + (separator as NSString).length,
                length: (partyText as NSString).length
            )
        )
        return title
    }

    static func canopyIcon(accent: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 23, height: 16))
        image.lockFocus()
        let color = NSColor.controlTextColor
        let stem = NSBezierPath()
        stem.move(to: NSPoint(x: 4, y: 1.5))
        stem.curve(
            to: NSPoint(x: 11, y: 14.5),
            controlPoint1: NSPoint(x: 3, y: 7),
            controlPoint2: NSPoint(x: 13, y: 8)
        )
        stem.curve(
            to: NSPoint(x: 18.5, y: 3),
            controlPoint1: NSPoint(x: 9, y: 10),
            controlPoint2: NSPoint(x: 18, y: 9)
        )
        color.setStroke()
        stem.lineWidth = 1.5
        stem.lineCapStyle = .round
        stem.stroke()
        accent.setFill()
        NSBezierPath(ovalIn: NSRect(x: 2, y: 5, width: 6, height: 3.5)).fill()
        NSBezierPath(ovalIn: NSRect(x: 9, y: 10.5, width: 6, height: 3.5)).fill()
        NSBezierPath(ovalIn: NSRect(x: 15, y: 3.5, width: 6, height: 3.5)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    static func farmTitle(week: Int, cash: Int) -> NSAttributedString {
        NSAttributedString(
            string: " W\(week) · $\(cash)",
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .medium),
            ]
        )
    }

    static func canopyTitle(vines: Int, density: Int) -> NSAttributedString {
        NSAttributedString(
            string: " \(vines) vines · \(density)%",
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .medium),
            ]
        )
    }
}
