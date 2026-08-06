import AppKit

/// Renders only Cornerworld's status-item components against controlled menu-bar
/// backgrounds, so visual proof never captures unrelated desktop icons.
@MainActor
enum MenuBarFixtureCapture {
    private enum CaptureError: LocalizedError {
        case appearanceUnavailable
        case bitmapUnavailable(String)
        case pngEncodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .appearanceUnavailable:
                "The requested macOS appearance is unavailable."
            case .bitmapUnavailable(let filename):
                "The menu-bar fixture \(filename) could not be rasterized."
            case .pngEncodingFailed(let filename):
                "The menu-bar fixture \(filename) could not be encoded as PNG."
            }
        }
    }

    private struct Fixture {
        let filename: String
        let appearanceName: NSAppearance.Name
        let overlandAccent: NSColor
        let farmAccent: NSColor
        let canopyAccent: NSColor
        let miles: Int
        let alive: Int
        let week: Int
        let cash: Int
        let vines: Int
        let density: Int
    }

    private static let fixtures = [
        Fixture(
            filename: "menu-bar-light-normal.png",
            appearanceName: .aqua,
            overlandAccent: .systemGreen,
            farmAccent: .systemGreen,
            canopyAccent: .systemGreen,
            miles: 912,
            alive: 5,
            week: 20,
            cash: 28,
            vines: 6,
            density: 62
        ),
        Fixture(
            filename: "menu-bar-dark-normal.png",
            appearanceName: .darkAqua,
            overlandAccent: .systemGreen,
            farmAccent: .systemGreen,
            canopyAccent: .systemGreen,
            miles: 912,
            alive: 5,
            week: 20,
            cash: 28,
            vines: 6,
            density: 62
        ),
        Fixture(
            filename: "menu-bar-light-warning.png",
            appearanceName: .aqua,
            overlandAccent: .systemOrange,
            farmAccent: .systemRed,
            canopyAccent: .systemGreen,
            miles: 1_894,
            alive: 2,
            week: 52,
            cash: 0,
            vines: 9,
            density: 100
        ),
        Fixture(
            filename: "menu-bar-dark-warning.png",
            appearanceName: .darkAqua,
            overlandAccent: .systemOrange,
            farmAccent: .systemRed,
            canopyAccent: .systemGreen,
            miles: 1_894,
            alive: 2,
            week: 52,
            cash: 0,
            vines: 9,
            density: 100
        ),
    ]

    static func writeFixtures(to outputDirectory: URL) throws -> [URL] {
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        return try fixtures.map { fixture in
            guard let appearance = NSAppearance(named: fixture.appearanceName) else {
                throw CaptureError.appearanceUnavailable
            }
            var image: NSImage!
            appearance.performAsCurrentDrawingAppearance {
                image = render(fixture: fixture)
            }
            let scale = 2
            guard let representation = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(ceil(image.size.width)) * scale,
                pixelsHigh: Int(ceil(image.size.height)) * scale,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ) else {
                throw CaptureError.bitmapUnavailable(fixture.filename)
            }
            representation.size = image.size
            guard let context = NSGraphicsContext(bitmapImageRep: representation) else {
                throw CaptureError.bitmapUnavailable(fixture.filename)
            }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            appearance.performAsCurrentDrawingAppearance {
                image.draw(in: NSRect(origin: .zero, size: image.size))
            }
            NSGraphicsContext.restoreGraphicsState()
            guard let png = representation.representation(using: .png, properties: [:]) else {
                throw CaptureError.pngEncodingFailed(fixture.filename)
            }
            let url = outputDirectory.appendingPathComponent(fixture.filename)
            try png.write(to: url, options: .atomic)
            return url
        }
    }

    private static func render(fixture: Fixture) -> NSImage {
        let overlandIcon = MenuBarPresentation.overlandIcon(accent: fixture.overlandAccent)
        let overlandTitle = MenuBarPresentation.overlandTitle(
            miles: fixture.miles,
            alive: fixture.alive,
            total: 5,
            accent: fixture.overlandAccent
        )
        let farmIcon = MenuBarPresentation.farmIcon(accent: fixture.farmAccent)
        let farmTitle = MenuBarPresentation.farmTitle(week: fixture.week, cash: fixture.cash)
        let canopyIcon = MenuBarPresentation.canopyIcon(accent: fixture.canopyAccent)
        let canopyTitle = MenuBarPresentation.canopyTitle(
            vines: fixture.vines,
            density: fixture.density
        )

        let inset: CGFloat = 7
        let iconGap: CGFloat = 3
        let worldGap: CGFloat = 13
        let height: CGFloat = 24
        let overlandWidth = overlandIcon.size.width + iconGap + ceil(overlandTitle.size().width)
        let farmWidth = farmIcon.size.width + iconGap + ceil(farmTitle.size().width)
        let canopyWidth = canopyIcon.size.width + iconGap + ceil(canopyTitle.size().width)
        let width = inset * 2 + overlandWidth + farmWidth + canopyWidth + worldGap * 2
        let image = NSImage(size: NSSize(width: width, height: height))

        image.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()

        var x = inset
        draw(icon: overlandIcon, title: overlandTitle, x: x, height: height)
        x += overlandWidth + worldGap
        draw(icon: farmIcon, title: farmTitle, x: x, height: height)
        x += farmWidth + worldGap
        draw(icon: canopyIcon, title: canopyTitle, x: x, height: height)

        image.unlockFocus()
        return image
    }

    private static func draw(
        icon: NSImage,
        title: NSAttributedString,
        x: CGFloat,
        height: CGFloat
    ) {
        let iconY = floor((height - icon.size.height) / 2)
        icon.draw(
            in: NSRect(x: x, y: iconY, width: icon.size.width, height: icon.size.height),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        let titleSize = title.size()
        title.draw(at: NSPoint(
            x: x + icon.size.width + 3,
            y: floor((height - titleSize.height) / 2)
        ))
    }
}
