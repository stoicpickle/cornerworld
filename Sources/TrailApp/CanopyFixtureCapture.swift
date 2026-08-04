import AppKit
import CanopyCore
import SpriteKit

@MainActor
enum CanopyFixtureCapture {
    private struct Fixture {
        let filename: String
        let tick: Int
        let event: CanopyVisualEvent?
        let message: String?

        init(filename: String, tick: Int, event: CanopyVisualEvent? = nil, message: String? = nil) {
            self.filename = filename
            self.tick = tick
            self.event = event
            self.message = message
        }
    }

    private enum CaptureError: LocalizedError {
        case textureUnavailable(String)
        case bitmapContextUnavailable
        case bitmapImageUnavailable
        case pngEncodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .textureUnavailable(let filename): "SpriteKit could not render \(filename)."
            case .bitmapContextUnavailable: "A 320 by 200 bitmap context could not be created."
            case .bitmapImageUnavailable: "The Canopy fixture could not be converted to an image."
            case .pngEncodingFailed(let filename): "The Canopy fixture \(filename) could not be encoded as PNG."
            }
        }
    }

    private static let seed: UInt64 = 1_993
    private static let fixtures = [
        Fixture(filename: "canopy-young.png", tick: 4),
        Fixture(filename: "canopy-established.png", tick: 30),
        Fixture(filename: "canopy-overgrown.png", tick: 120),
        Fixture(filename: "canopy-event-rain.png", tick: 42, event: .rain, message: "Warm rain sends fresh growth toward the canopy."),
        Fixture(filename: "canopy-event-bloom.png", tick: 48, event: .bloom(vineID: 0), message: "A night flower opens beneath the moon."),
        Fixture(filename: "canopy-event-bird.png", tick: 55, event: .bird, message: "A bright bird pauses among the new leaves."),
        Fixture(filename: "canopy-event-clean-swing.png", tick: 72, event: .swing(.clean(direction: .right)), message: "A wild whoop crosses the canopy."),
        Fixture(filename: "canopy-event-clean-swing-left.png", tick: 73, event: .swing(.clean(direction: .left)), message: "The wanderer arcs back across the canopy."),
        Fixture(filename: "canopy-event-wall-impact.png", tick: 96, event: .swing(.wallImpact(side: .right)), message: "The wanderer clips the edge and slides down."),
        Fixture(filename: "canopy-event-wall-impact-left.png", tick: 97, event: .swing(.wallImpact(side: .left)), message: "The wanderer clips the other edge this time."),
        Fixture(filename: "canopy-event-pruned.png", tick: 120, event: .pruned, message: "The oldest growth is pruned back."),
    ]

    static func writeFixtures(to outputDirectory: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        return try fixtures.map { fixture in
            var simulation = CanopySimulation(seed: seed)
            var latestEvent = "The jungle waits for green."
            for _ in 0..<fixture.tick {
                latestEvent = simulation.tick().last ?? latestEvent
            }
            if fixture.event == .pruned {
                latestEvent = simulation.prune()
            }
            var state = simulation.state
            if case .bloom? = fixture.event, !state.vines.isEmpty {
                state.vines[0].hasFlower = true
                state.latestVisualEvent = .bloom(vineID: state.vines[0].id)
            }
            state.latestVisualEvent = fixture.event ?? state.latestVisualEvent
            let snapshot = CanopyPresentationSnapshot(
                state: state,
                latestEvent: fixture.message ?? latestEvent,
                revision: fixture.tick
            )
            let scene = CanopyScene(snapshot: snapshot, staticEventPose: true)
            let size = CanopyScene.logicalSize
            let view = SKView(frame: CGRect(origin: .zero, size: size))
            view.ignoresSiblingOrder = true
            view.allowsTransparency = false
            view.presentScene(scene)
            scene.isPaused = true
            view.isPaused = true
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()

            guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: size)) else {
                throw CaptureError.textureUnavailable(fixture.filename)
            }
            let image = try normalizedImage(texture.cgImage())
            let representation = NSBitmapImageRep(cgImage: image)
            guard let png = representation.representation(using: .png, properties: [:]) else {
                throw CaptureError.pngEncodingFailed(fixture.filename)
            }
            let url = outputDirectory.appendingPathComponent(fixture.filename)
            try png.write(to: url, options: .atomic)
            return url
        }
    }

    private static func normalizedImage(_ source: CGImage) throws -> CGImage {
        let width = Int(CanopyScene.logicalSize.width)
        let height = Int(CanopyScene.logicalSize.height)
        if source.width == width, source.height == height { return source }
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw CaptureError.bitmapContextUnavailable }
        context.interpolationQuality = .none
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { throw CaptureError.bitmapImageUnavailable }
        return image
    }
}
