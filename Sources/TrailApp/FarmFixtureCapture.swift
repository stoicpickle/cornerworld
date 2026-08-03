import AppKit
import FarmCore
import SpriteKit

/// Process-owned visual fixtures for Farm. These captures render SpriteKit
/// directly and never require Screen Recording permission or include desktop UI.
@MainActor
enum FarmFixtureCapture {
    private struct Fixture {
        let filename: String
        let plan: FarmPlan
        let week: Int
        let visualEvent: FarmVisualEvent?
        let message: String?

        init(
            filename: String,
            plan: FarmPlan,
            week: Int,
            visualEvent: FarmVisualEvent? = nil,
            message: String? = nil
        ) {
            self.filename = filename
            self.plan = plan
            self.week = week
            self.visualEvent = visualEvent
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
            case .textureUnavailable(let filename):
                "SpriteKit could not render the Farm fixture \(filename)."
            case .bitmapContextUnavailable:
                "A 320 by 200 bitmap context could not be created."
            case .bitmapImageUnavailable:
                "The rendered Farm fixture could not be converted to an image."
            case .pngEncodingFailed(let filename):
                "The Farm fixture \(filename) could not be encoded as PNG."
            }
        }
    }

    private static let seed: UInt64 = 1_848
    private static let fixtures = [
        Fixture(filename: "farm-spring-bare.png", plan: .fallow, week: 1),
        Fixture(filename: "farm-spring-sprouting.png", plan: .wheat, week: 2),
        Fixture(filename: "farm-summer-mature.png", plan: .wheat, week: 20),
        Fixture(filename: "farm-autumn-harvested.png", plan: .wheat, week: 33),
        Fixture(filename: "farm-winter-snow.png", plan: .wheat, week: 40),
        Fixture(filename: "farm-adverse-late-frost.png", plan: .wheat, week: 10),
        Fixture(filename: "farm-event-weeds.png", plan: .wheat, week: 18, visualEvent: .weeds, message: "Weeds crowded a row before they could be cut back."),
        Fixture(filename: "farm-event-crows.png", plan: .wheat, week: 8, visualEvent: .crows, message: "Crows pulled at the young crop."),
        Fixture(filename: "farm-event-deer.png", plan: .wheat, week: 20, visualEvent: .deer, message: "Deer watched from the field edge."),
        Fixture(filename: "farm-event-neighbor.png", plan: .beans, week: 8, visualEvent: .neighborProvisions(food: 4), message: "A neighbor left a basket with 4 food."),
        Fixture(filename: "farm-event-wind-damage.png", plan: .wheat, week: 30, visualEvent: .windDamage, message: "A hard wind bent the outer rows."),
        Fixture(filename: "farm-event-repair-day.png", plan: .wheat, week: 44, visualEvent: .repairDay(points: 7), message: "A clear repair day restored the barn."),
        Fixture(filename: "farm-event-harvest.png", plan: .wheat, week: 33, visualEvent: .harvest(plan: .wheat, totalYield: 38), message: "The wheat harvest is brought in."),
        Fixture(filename: "farm-event-year-end.png", plan: .fallow, week: 52, visualEvent: .yearEnd(outcome: .debt, paid: 28), message: "The farm ends the year in debt."),
    ]

    /// Writes deterministic 320x200 seasonal and event PNGs. A fixed seed keeps
    /// visual diffs meaningful across renderer changes.
    static func writeFixtures(to outputDirectory: URL) throws -> [URL] {
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        return try fixtures.map { fixture in
            var simulation = FarmSimulation(seed: seed, plan: fixture.plan)
            var latestEvent = "The field waits for spring planting."
            for _ in 0..<fixture.week {
                latestEvent = simulation.tick().last ?? latestEvent
            }

            var fixtureState = simulation.state
            fixtureState.latestVisualEvent = fixture.visualEvent ?? fixtureState.latestVisualEvent
            if case .repairDay? = fixture.visualEvent {
                fixtureState.buildingCondition = 55
            }
            let snapshot = FarmPresentationSnapshot(
                state: fixtureState,
                latestEvent: fixture.message ?? latestEvent,
                revision: fixture.week
            )
            let scene = FarmScene(snapshot: snapshot)
            let logicalSize = FarmScene.logicalSize
            let view = SKView(frame: CGRect(origin: .zero, size: logicalSize))
            view.ignoresSiblingOrder = true
            view.allowsTransparency = false
            view.presentScene(scene)

            // didMove(to:) has constructed the node tree. Freeze it before
            // rendering so blinking weather never makes fixtures timing-dependent.
            scene.isPaused = true
            view.isPaused = true
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()

            let crop = CGRect(origin: .zero, size: logicalSize)
            guard let texture = view.texture(from: scene, crop: crop) else {
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

    /// `SKView` can render at the backing scale of the host display. Normalize
    /// with nearest-neighbor sampling so fixtures are exactly 320x200 everywhere.
    private static func normalizedImage(_ source: CGImage) throws -> CGImage {
        let width = Int(FarmScene.logicalSize.width)
        let height = Int(FarmScene.logicalSize.height)
        if source.width == width, source.height == height { return source }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CaptureError.bitmapContextUnavailable
        }
        context.interpolationQuality = .none
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else {
            throw CaptureError.bitmapImageUnavailable
        }
        return image
    }
}
