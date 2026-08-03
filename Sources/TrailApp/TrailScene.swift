import SpriteKit
import GameCore

/// A value-only view of one simulated day. Keeping the mutable simulation out of
/// the scene makes rendering an explicit, once-per-day operation.
struct TrailPresentationSnapshot {
    let revision: Int
    let seed: UInt64
    let day: Int
    let date: String
    let weather: Weather.Kind
    let terrain: Terrain
    let health: String
    let foodPounds: Int
    let milesToNextLandmark: Int
    let nextLandmarkName: String?
    let milesTraveled: Int
    let message: String
    let visualEvent: VisualEvent?
    let endingTitle: String?
    let endingDetail: String?
    let endingSummary: [String]

    init(simulation: Simulation, latestEvent: String, revision: Int = 0) {
        self.revision = revision
        seed = simulation.seed
        day = simulation.day
        date = simulation.dateString
        weather = simulation.currentWeather.kind
        terrain = Trail.terrain(at: simulation.milesTraveled)
        switch simulation.party.averageHealth {
        case 80...: health = "good"
        case 55..<80: health = "fair"
        case 30..<55: health = "poor"
        default: health = "very poor"
        }
        foodPounds = simulation.supplies.foodPounds
        let nextLandmark = Trail.nextLandmark(after: simulation.milesTraveled)
        milesToNextLandmark = max(
            0,
            (nextLandmark?.distance ?? Trail.totalMiles)
                - simulation.milesTraveled
        )
        nextLandmarkName = nextLandmark?.name
        milesTraveled = simulation.milesTraveled
        message = latestEvent
        visualEvent = simulation.latestVisualEvent

        switch simulation.outcome {
        case .reachedOregon:
            endingTitle = "YOU HAVE REACHED OREGON!"
            endingDetail = "\(simulation.milesTraveled) MILES IN \(simulation.day) DAYS"
        case .partyPerished(let cause):
            endingTitle = "ALL MEMBERS OF YOUR PARTY"
            endingDetail = "HAVE DIED — LAST CAUSE: \(cause.uppercased())"
        case nil:
            endingTitle = nil
            endingDetail = nil
        }
        endingSummary = [
            "SURVIVORS: \(simulation.party.aliveCount)/\(simulation.party.members.count)",
            "SEED: \(String(simulation.seed, radix: 16, uppercase: true))",
        ] + simulation.memorials.prefix(2).map { "IN MEMORY: \($0.uppercased())" }
    }
}

// MARK: - Tiny pixel canvas for hand-built sprite art

struct PixelCanvas {
    let w: Int, h: Int
    var grid: [[Character]]

    init(w: Int, h: Int) {
        self.w = w; self.h = h
        grid = Array(repeating: Array(repeating: Character("."), count: w), count: h)
    }

    mutating func rect(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ ch: Character) {
        for yy in y..<(y + rh) {
            for xx in x..<(x + rw) {
                guard yy >= 0, yy < h, xx >= 0, xx < w else { continue }
                grid[yy][xx] = ch
            }
        }
    }

    mutating func line(from start: (Int, Int), to end: (Int, Int), _ ch: Character) {
        var (x0, y0) = start
        let (x1, y1) = end
        let dx = abs(x1 - x0)
        let sx = x0 < x1 ? 1 : -1
        let dy = -abs(y1 - y0)
        let sy = y0 < y1 ? 1 : -1
        var error = dx + dy

        while true {
            rect(x0, y0, 1, 1, ch)
            if x0 == x1 && y0 == y1 { break }
            let twiceError = 2 * error
            if twiceError >= dy { error += dy; x0 += sx }
            if twiceError <= dx { error += dx; y0 += sy }
        }
    }

    var rows: [String] { grid.map { String($0) } }
}

final class TrailScene: SKScene {
    static let logicalSize = CGSize(width: 320, height: 200)

    private var pendingSnapshot: TrailPresentationSnapshot
    private var appliedSeed: UInt64?
    private var appliedRevision: Int?

    // Restrained Apple II-style artifact-color palette.
    private let grassGreen = NSColor(calibratedRed: 0.20, green: 0.82, blue: 0.00, alpha: 1)
    private let mountainPurple = NSColor(calibratedRed: 0.76, green: 0.24, blue: 1.00, alpha: 1)
    private let dustOrange = NSColor(calibratedRed: 1.00, green: 0.38, blue: 0.00, alpha: 1)
    private let inkBlack = NSColor.black
    private let paperWhite = NSColor(calibratedWhite: 0.98, alpha: 1)
    private let artifactBlue = NSColor(calibratedRed: 0.00, green: 0.62, blue: 1.00, alpha: 1)

    private let dataPanelH: CGFloat = 62
    private let promptBarH: CGFloat = 16
    private let groundBandH: CGFloat = 52

    private var wagonSprite: SKSpriteNode!
    private var groundNode: SKSpriteNode!
    private var wagonFrames: [SKTexture] = []
    private var frameFlip: TimeInterval = 0
    private var frameIndex = 0

    private let terrainNode = SKNode()
    private let landmarkNode = SKNode()
    private let fxNode = SKNode()
    private let eventNode = SKNode()
    private var lastTerrain: Terrain?

    private var statusLabels: [SKLabelNode] = []
    private var messageLabel: SKLabelNode!
    private var hasEnded = false

    private var groundBottomY: CGFloat { dataPanelH + promptBarH }
    private var groundTopY: CGFloat { groundBottomY + groundBandH }

    init(snapshot: TrailPresentationSnapshot) {
        pendingSnapshot = snapshot
        super.init(size: Self.logicalSize)
        scaleMode = .aspectFit
    }
    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        backgroundColor = inkBlack

        // The original travel screen is mostly black, with a weather-colored
        // strip below the tiny wagon rather than a full illustrated sky.
        groundNode = SKSpriteNode(color: grassGreen,
                                  size: CGSize(width: size.width - 8, height: groundBandH))
        groundNode.anchorPoint = .zero
        groundNode.position = CGPoint(x: 4, y: groundBottomY)
        groundNode.zPosition = 1
        addChild(groundNode)

        addChild(terrainNode)
        addChild(landmarkNode)
        addChild(fxNode)
        eventNode.zPosition = 10
        addChild(eventNode)

        // Wagon + ox, 2-frame walk cycle
        wagonFrames = [pixelTexture(rows: Self.wagon(phase: 0), palette: Self.wagonPalette),
                       pixelTexture(rows: Self.wagon(phase: 1), palette: Self.wagonPalette)]
        let rows = Self.wagon(phase: 0)
        wagonSprite = SKSpriteNode(texture: wagonFrames[0])
        wagonSprite.size = CGSize(width: CGFloat(rows[0].count), height: CGFloat(rows.count))
        wagonSprite.anchorPoint = CGPoint(x: 1, y: 0)
        wagonSprite.position = CGPoint(x: size.width - 20, y: groundTopY)
        wagonSprite.zPosition = 3
        addChild(wagonSprite)

        let dataPanel = SKSpriteNode(color: paperWhite,
                                     size: CGSize(width: size.width - 8, height: dataPanelH))
        dataPanel.anchorPoint = .zero
        dataPanel.position = CGPoint(x: 4, y: 0)
        dataPanel.zPosition = 50
        addChild(dataPanel)

        messageLabel = statusLabel(y: dataPanelH + 3, color: paperWhite)
        messageLabel.fontSize = 7.5
        addChild(messageLabel)

        for row in 0..<6 {
            let label = statusLabel(y: dataPanelH - 11 - CGFloat(row * 9), color: inkBlack)
            statusLabels.append(label)
            addChild(label)
        }

        apply(pendingSnapshot)
    }

    private func statusLabel(y: CGFloat, color: NSColor) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: "Courier-Bold")
        l.fontSize = 8.5
        l.fontColor = color
        l.horizontalAlignmentMode = .center
        l.verticalAlignmentMode = .baseline
        l.position = CGPoint(x: size.width / 2, y: y)
        l.zPosition = 51
        return l
    }

    override func update(_ currentTime: TimeInterval) {
        if currentTime - frameFlip > 0.3 {
            frameFlip = currentTime
            frameIndex = (frameIndex + 1) % 2
            wagonSprite.texture = wagonFrames[frameIndex]
        }
    }

    /// Applies all day-level presentation state in one transaction. SpriteKit's
    /// per-frame callback is reserved for animation after this point.
    func apply(_ snapshot: TrailPresentationSnapshot) {
        pendingSnapshot = snapshot
        guard appliedSeed != snapshot.seed || appliedRevision != snapshot.revision else { return }
        appliedSeed = snapshot.seed
        appliedRevision = snapshot.revision

        statusLabels[0].text = "Date: \(snapshot.date)"
        statusLabels[1].text = "Weather: \(weatherName(snapshot.weather))"
        statusLabels[2].text = "Health: \(snapshot.health)"
        statusLabels[3].text = "Food: \(snapshot.foodPounds) pounds"
        statusLabels[4].text = "Next landmark: \(snapshot.milesToNextLandmark) miles"
        statusLabels[5].text = "Miles traveled: \(snapshot.milesTraveled) miles"
        messageLabel.text = fittedMessage(snapshot.message)
        groundNode.color = groundColor(snapshot.weather)

        if snapshot.terrain != lastTerrain {
            lastTerrain = snapshot.terrain
            rebuildTerrain(snapshot.terrain)
        }
        rebuildLandmarkApproach(snapshot)
        rebuildWeather(for: snapshot)
        rebuildEvent(snapshot.visualEvent)

        if snapshot.endingTitle != nil {
            renderEndScene(snapshot)
        }
    }

    private func weatherName(_ weather: Weather.Kind) -> String {
        switch weather {
        case .clear: "warm"
        case .overcast: "cool"
        case .rain: "rainy"
        case .storm: "stormy"
        case .snow: "snowing"
        case .heatwave: "hot"
        case .coldSnap: "cold"
        }
    }

    private func groundColor(_ weather: Weather.Kind) -> NSColor {
        switch weather {
        case .snow, .coldSnap: paperWhite
        case .heatwave: dustOrange
        default: grassGreen
        }
    }

    // MARK: - Terrain

    private func rebuildTerrain(_ terrain: Terrain) {
        terrainNode.removeAllChildren()

        let color = terrain == .mountains ? mountainPurple : (terrain == .river ? artifactBlue : grassGreen)
        let horizon = pixelNode(rows: Self.horizon(terrain), palette: ["C": color, "W": paperWhite], scale: 2)
        horizon.anchorPoint = CGPoint(x: 0, y: 0)
        horizon.position = CGPoint(x: 0, y: groundTopY + 20)
        horizon.zPosition = 2
        terrainNode.addChild(horizon)
    }

    private func rebuildLandmarkApproach(_ snapshot: TrailPresentationSnapshot) {
        landmarkNode.removeAllChildren()
        guard let name = snapshot.nextLandmarkName,
              snapshot.milesToNextLandmark <= 70 else { return }

        let rows = Self.landmark(named: name)
        let icon = pixelNode(
            rows: rows,
            palette: ["W": paperWhite, "O": dustOrange, "B": artifactBlue],
            scale: 1
        )
        icon.anchorPoint = CGPoint(x: 0.5, y: 0)
        let progress = CGFloat(70 - snapshot.milesToNextLandmark) / 70
        icon.position = CGPoint(x: 32 + progress * 68, y: groundTopY)
        icon.zPosition = 2.5
        landmarkNode.addChild(icon)
    }

    // MARK: - Weather

    private func rebuildWeather(for snapshot: TrailPresentationSnapshot) {
        fxNode.removeAllChildren()

        let w = snapshot.weather
        guard w == .rain || w == .storm || w == .snow else { return }

        let count = w == .storm ? 18 : 10
        let salt: UInt64 = switch w {
        case .rain: 0x5241_494E
        case .storm: 0x5354_4F52_4D
        case .snow: 0x534E_4F57
        default: 0
        }
        var rng = SplitMix64(seed: snapshot.seed ^ (UInt64(snapshot.day) &* 0x9E37_79B9_7F4A_7C15) ^ salt)
        for _ in 0..<count {
            let p = w == .snow
                ? SKSpriteNode(color: paperWhite, size: CGSize(width: 2, height: 2))
                : SKSpriteNode(color: artifactBlue, size: CGSize(width: 1, height: 4))
            p.position = CGPoint(x: CGFloat(rng.int(in: 0...Int(size.width - 1))),
                                 y: CGFloat(rng.int(in: Int(groundTopY + 20)...Int(size.height - 1))))
            fxNode.addChild(p)
        }
    }

    private func fittedMessage(_ message: String) -> String {
        let fallback = "The wagon train rolls west."
        let text = message.isEmpty ? fallback : message
        let limit = 68
        guard text.count > limit else { return text }
        return String(text.prefix(limit - 3)) + "..."
    }

    // MARK: - Event vignettes

    private enum EventActionKey {
        static let motion = "event.motion"
        static let blink = "event.blink"
    }

    /// Event art is replaced as a single day-level layer. Actions are keyed so a
    /// fast pace can never leave a river bob, muzzle flash, or wolf blink running
    /// after the next snapshot arrives.
    private func rebuildEvent(_ event: VisualEvent?) {
        eventNode.removeAllActions()
        eventNode.enumerateChildNodes(withName: "//*") { node, _ in
            node.removeAllActions()
        }
        eventNode.removeAllChildren()
        wagonSprite.removeAction(forKey: EventActionKey.motion)
        wagonSprite.isHidden = false
        wagonSprite.alpha = 1
        wagonSprite.zRotation = 0
        wagonSprite.position = CGPoint(x: size.width - 20, y: groundTopY)

        guard let event else { return }

        switch event {
        case .illness(_, let ailment):
            renderIllness(ailment)
        case .hunt(let outcome):
            renderHunt(outcome)
        case .trailOpportunity(let item):
            renderTrailOpportunity(item)
        case .wolves(let oxLost):
            renderWolves(oxLost: oxLost)
        case .wagonBreakdown(let part, let repaired):
            renderBreakdown(part: part, repaired: repaired)
        case .snakebite(let outcome):
            renderSnakebite(outcome)
        case .spring:
            renderSpring()
        case .regionalTrade:
            renderTrade()
        case .weatherWorsening:
            renderWeatherWorsening()
        case .ambient(let moment):
            renderAmbient(moment)
        case .riverCrossing(_, let outcome):
            renderRiverCrossing(outcome)
        }
    }

    private func eventSprite(
        rows: [String],
        palette: [Character: NSColor],
        scale: CGFloat = 1,
        position: CGPoint,
        anchorPoint: CGPoint = .zero,
        z: CGFloat = 1
    ) -> SKSpriteNode {
        let sprite = pixelNode(rows: rows, palette: palette, scale: scale)
        sprite.anchorPoint = anchorPoint
        sprite.position = position
        sprite.zPosition = z
        eventNode.addChild(sprite)
        return sprite
    }

    /// Moves only by whole logical pixels, preserving the nearest-neighbor edge.
    private func steppedLoop(_ deltas: [CGVector], wait: TimeInterval = 0.10) -> SKAction {
        let steps = deltas.flatMap { delta in
            [SKAction.moveBy(x: delta.dx, y: delta.dy, duration: 0), .wait(forDuration: wait)]
        }
        return .repeatForever(.sequence(steps))
    }

    private func blinkLoop(on: TimeInterval = 0.12, off: TimeInterval = 0.12) -> SKAction {
        .repeatForever(.sequence([
            .unhide(), .wait(forDuration: on), .hide(), .wait(forDuration: off),
        ]))
    }

    private var eventPalette: [Character: NSColor] {
        [
            "W": paperWhite,
            "O": dustOrange,
            "B": artifactBlue,
            "G": grassGreen,
            "P": mountainPurple,
            "K": inkBlack,
        ]
    }

    private func renderBreakdown(part: WagonPart, repaired: Bool) {
        wagonSprite.isHidden = true
        let scene = eventSprite(
            rows: Self.breakdown(part: part, repaired: repaired),
            palette: eventPalette,
            position: CGPoint(x: 205, y: groundTopY - 1)
        )
        scene.run(
            steppedLoop([CGVector(dx: 0, dy: 1), CGVector(dx: 0, dy: -1)], wait: 0.16),
            withKey: EventActionKey.motion
        )

        let toolFlash = eventSprite(
            rows: ["W.", ".O"],
            palette: eventPalette,
            scale: 2,
            position: CGPoint(x: 279, y: groundTopY + 30),
            z: 2
        )
        toolFlash.run(blinkLoop(on: repaired ? 0.14 : 0.07, off: 0.18), withKey: EventActionKey.blink)
    }

    private func renderRiverCrossing(_ outcome: RiverCrossingOutcome) {
        wagonSprite.isHidden = true
        let water = eventSprite(
            rows: Self.riverWater(),
            palette: eventPalette,
            scale: 2,
            position: CGPoint(x: 4, y: groundBottomY),
            z: 0
        )
        water.run(
            steppedLoop([CGVector(dx: 2, dy: 0), CGVector(dx: -2, dy: 0)], wait: 0.14),
            withKey: EventActionKey.motion
        )

        let wagon = eventSprite(
            rows: Self.riverWagon(outcome),
            palette: eventPalette,
            position: CGPoint(x: 211, y: groundTopY - 13),
            z: 3
        )

        switch outcome {
        case .success:
            wagon.run(
                steppedLoop([CGVector(dx: -2, dy: 1), CGVector(dx: 2, dy: -1)], wait: 0.11),
                withKey: EventActionKey.motion
            )
        case .suppliesLost:
            wagon.run(
                steppedLoop([CGVector(dx: -1, dy: 1), CGVector(dx: 1, dy: -1)], wait: 0.11),
                withKey: EventActionKey.motion
            )
            let crate = eventSprite(
                rows: Self.crate(),
                palette: eventPalette,
                position: CGPoint(x: 230, y: groundTopY - 22),
                z: 4
            )
            let start = crate.position
            crate.run(.repeatForever(.sequence([
                .moveBy(x: -5, y: 1, duration: 0), .wait(forDuration: 0.10),
                .moveBy(x: -5, y: -1, duration: 0), .wait(forDuration: 0.10),
                .moveBy(x: -5, y: 1, duration: 0), .wait(forDuration: 0.10),
                .run { [weak crate] in crate?.position = start },
            ])), withKey: EventActionKey.motion)
        case .travelerLost:
            wagon.run(
                steppedLoop([CGVector(dx: -1, dy: -2), CGVector(dx: 1, dy: 2)], wait: 0.11),
                withKey: EventActionKey.motion
            )
        case .impassable:
            let foam = eventSprite(
                rows: ["WW..WW..WW..WW", "..WW..WW..WW.."],
                palette: eventPalette,
                scale: 2,
                position: CGPoint(x: 180, y: groundTopY - 17),
                z: 4
            )
            foam.run(blinkLoop(on: 0.16, off: 0.16), withKey: EventActionKey.blink)
        }
    }

    private func renderHunt(_ outcome: HuntOutcome) {
        for (index, x) in [22, 61, 98].enumerated() {
            let buffalo = eventSprite(
                rows: Self.buffalo(phase: index % 2),
                palette: eventPalette,
                position: CGPoint(x: CGFloat(x), y: groundTopY + CGFloat(17 - index * 4)),
                z: 1
            )
            buffalo.run(
                steppedLoop([CGVector(dx: -2, dy: 0), CGVector(dx: 2, dy: 0)], wait: 0.15),
                withKey: EventActionKey.motion
            )
        }

        let hunter = eventSprite(
            rows: Self.hunter(),
            palette: eventPalette,
            position: CGPoint(x: 187, y: groundTopY),
            z: 3
        )

        switch outcome {
        case .success:
            let flash = eventSprite(
                rows: [".O.", "OWO", ".O."],
                palette: eventPalette,
                position: CGPoint(x: 180, y: groundTopY + 15),
                z: 4
            )
            flash.run(blinkLoop(on: 0.06, off: 0.24), withKey: EventActionKey.blink)
            hunter.run(
                steppedLoop([CGVector(dx: 1, dy: 0), CGVector(dx: -1, dy: 0)], wait: 0.15),
                withKey: EventActionKey.motion
            )
        case .noAmmunition:
            let empty = eventSprite(
                rows: ["O...O", ".O.O.", "..O..", ".O.O.", "O...O"],
                palette: eventPalette,
                position: CGPoint(x: 178, y: groundTopY + 12),
                z: 4
            )
            empty.run(blinkLoop(on: 0.18, off: 0.12), withKey: EventActionKey.blink)
        }
    }

    private func renderTrailOpportunity(_ item: TrailOpportunityItem) {
        let wreck = eventSprite(
            rows: Self.abandonedWagon(),
            palette: eventPalette,
            position: CGPoint(x: 73, y: groundTopY),
            z: 1
        )
        wreck.run(
            steppedLoop([CGVector(dx: 0, dy: 1), CGVector(dx: 0, dy: -1)], wait: 0.18),
            withKey: EventActionKey.motion
        )
        let rows: [String] = switch item {
        case .food: Self.foodSack()
        case .spareWheel: Self.looseWheel()
        case .spareAxle: Self.spareAxle()
        case .clothing: Self.coat()
        }
        let found = eventSprite(
            rows: rows,
            palette: eventPalette,
            scale: 2,
            position: CGPoint(x: 147, y: groundTopY + 1),
            z: 3
        )
        found.run(blinkLoop(on: 0.20, off: 0.08), withKey: EventActionKey.blink)
    }

    private func renderWolves(oxLost _: Bool) {
        let dusk = SKSpriteNode(color: inkBlack, size: CGSize(width: size.width - 8, height: 10))
        dusk.anchorPoint = .zero
        dusk.position = CGPoint(x: 4, y: groundTopY + 25)
        dusk.zPosition = 0
        eventNode.addChild(dusk)

        for (index, x) in [44, 86, 132].enumerated() {
            let wolf = eventSprite(
                rows: Self.wolf(eyes: index != 1),
                palette: eventPalette,
                position: CGPoint(x: CGFloat(x), y: groundTopY + CGFloat(7 + index * 3)),
                z: 2
            )
            wolf.run(
                steppedLoop([CGVector(dx: 2, dy: 0), CGVector(dx: -2, dy: 0)], wait: 0.14),
                withKey: EventActionKey.motion
            )
        }
    }

    private func renderIllness(_ ailment: Ailment) {
        let camp = eventSprite(
            rows: Self.illnessCamp(ailment),
            palette: eventPalette,
            scale: 2,
            position: CGPoint(x: 84, y: groundTopY),
            z: 2
        )
        camp.run(
            steppedLoop([CGVector(dx: 0, dy: 1), CGVector(dx: 0, dy: -1)], wait: 0.18),
            withKey: EventActionKey.motion
        )
        let fire = eventSprite(
            rows: [".O.", "OWO", ".O."],
            palette: eventPalette,
            position: CGPoint(x: 132, y: groundTopY + 1),
            z: 3
        )
        fire.run(blinkLoop(on: 0.10, off: 0.10), withKey: EventActionKey.blink)
    }

    private func renderSnakebite(_ outcome: SnakebiteOutcome) {
        let snake = eventSprite(
            rows: Self.snake(),
            palette: eventPalette,
            scale: 2,
            position: CGPoint(x: 178, y: groundTopY),
            z: 3
        )
        snake.run(
            steppedLoop([CGVector(dx: 2, dy: 0), CGVector(dx: -2, dy: 0)], wait: 0.12),
            withKey: EventActionKey.motion
        )
        if case .struck = outcome {
            let strike = eventSprite(
                rows: ["O..", ".O.", "..O"],
                palette: eventPalette,
                scale: 2,
                position: CGPoint(x: 197, y: groundTopY + 8),
                z: 4
            )
            strike.run(blinkLoop(on: 0.08, off: 0.16), withKey: EventActionKey.blink)
        }
    }

    private func renderSpring() {
        let spring = eventSprite(
            rows: Self.springScene(),
            palette: eventPalette,
            scale: 2,
            position: CGPoint(x: 60, y: groundTopY - 3),
            z: 2
        )
        spring.run(
            steppedLoop([CGVector(dx: 2, dy: 0), CGVector(dx: -2, dy: 0)], wait: 0.15),
            withKey: EventActionKey.motion
        )
    }

    private func renderTrade() {
        let camp = eventSprite(
            rows: Self.tradeCamp(),
            palette: eventPalette,
            position: CGPoint(x: 39, y: groundTopY),
            z: 2
        )
        camp.run(
            steppedLoop([CGVector(dx: 0, dy: 1), CGVector(dx: 0, dy: -1)], wait: 0.18),
            withKey: EventActionKey.motion
        )
        let parcel = eventSprite(
            rows: Self.crate(),
            palette: eventPalette,
            position: CGPoint(x: 172, y: groundTopY + 7),
            z: 3
        )
        parcel.run(
            steppedLoop([CGVector(dx: 3, dy: 0), CGVector(dx: -3, dy: 0)], wait: 0.14),
            withKey: EventActionKey.motion
        )
    }

    private func renderWeatherWorsening() {
        let clouds = eventSprite(
            rows: Self.squallClouds(),
            palette: eventPalette,
            scale: 2,
            position: CGPoint(x: 18, y: groundTopY + 34),
            z: 2
        )
        clouds.run(
            steppedLoop([CGVector(dx: 2, dy: 0), CGVector(dx: -2, dy: 0)], wait: 0.14),
            withKey: EventActionKey.motion
        )
        let bolt = eventSprite(
            rows: Self.lightningBolt(),
            palette: eventPalette,
            scale: 2,
            position: CGPoint(x: 142, y: groundTopY + 17),
            z: 3
        )
        bolt.run(blinkLoop(on: 0.05, off: 0.24), withKey: EventActionKey.blink)
    }

    private func renderAmbient(_ moment: AmbientMoment) {
        switch moment {
        case .prairieGrass:
            renderPrairieGrass()
        case .buffaloHerd:
            for (index, x) in [28, 58, 91, 125].enumerated() {
                let buffalo = eventSprite(
                    rows: Self.buffalo(phase: index % 2),
                    palette: eventPalette,
                    position: CGPoint(x: CGFloat(x), y: groundTopY + CGFloat(17 - index * 3)),
                    z: 1
                )
                buffalo.run(
                    steppedLoop([CGVector(dx: -2, dy: 0), CGVector(dx: 2, dy: 0)], wait: 0.16),
                    withKey: EventActionKey.motion
                )
            }
        case .cottonwoodLeaves:
            renderCottonwoodLeaves()
        case .fallingStone:
            renderFallingStone()
        case .longShadows:
            let shadows = eventSprite(
                rows: Self.longShadows(),
                palette: eventPalette,
                scale: 2,
                position: CGPoint(x: 10, y: groundTopY + 4),
                z: 2
            )
            shadows.run(blinkLoop(on: 0.20, off: 0.08), withKey: EventActionKey.blink)
        case .lowClouds:
            let clouds = eventSprite(
                rows: Self.lowClouds(),
                palette: eventPalette,
                scale: 2,
                position: CGPoint(x: 20, y: groundTopY + 31),
                z: 2
            )
            clouds.run(
                steppedLoop([CGVector(dx: 2, dy: 0), CGVector(dx: -2, dy: 0)], wait: 0.17),
                withKey: EventActionKey.motion
            )
        case .rainTracks:
            renderTracks(color: artifactBlue)
        case .lightning:
            let bolt = eventSprite(
                rows: Self.lightningBolt(),
                palette: eventPalette,
                scale: 3,
                position: CGPoint(x: 105, y: groundTopY + 8),
                z: 4
            )
            bolt.run(blinkLoop(on: 0.05, off: 0.22), withKey: EventActionKey.blink)
        case .snowRuts:
            renderTracks(color: paperWhite)
        case .heatShimmer:
            let shimmer = eventSprite(
                rows: Self.heatShimmer(),
                palette: eventPalette,
                scale: 2,
                position: CGPoint(x: 13, y: groundTopY + 14),
                z: 2
            )
            shimmer.run(
                steppedLoop([CGVector(dx: 2, dy: 0), CGVector(dx: -4, dy: 0), CGVector(dx: 2, dy: 0)], wait: 0.09),
                withKey: EventActionKey.motion
            )
        case .frostGrass:
            let frost = eventSprite(
                rows: Self.frostGrass(),
                palette: eventPalette,
                scale: 2,
                position: CGPoint(x: 8, y: groundTopY),
                z: 2
            )
            frost.run(blinkLoop(on: 0.18, off: 0.08), withKey: EventActionKey.blink)
        }
    }

    private func renderPrairieGrass() {
        let grass = eventSprite(
            rows: Self.tallGrass(),
            palette: eventPalette,
            scale: 2,
            position: CGPoint(x: 8, y: groundTopY),
            z: 2
        )
        grass.run(
            steppedLoop([CGVector(dx: 1, dy: 0), CGVector(dx: -1, dy: 0)], wait: 0.16),
            withKey: EventActionKey.motion
        )
    }

    private func renderCottonwoodLeaves() {
        let leaves = eventSprite(
            rows: Self.cottonwoodLeaves(),
            palette: eventPalette,
            scale: 2,
            position: CGPoint(x: 20, y: groundTopY + 8),
            z: 2
        )
        leaves.run(blinkLoop(on: 0.12, off: 0.10), withKey: EventActionKey.blink)
    }

    private func renderFallingStone() {
        for (index, start) in [CGPoint(x: 46, y: 170), CGPoint(x: 78, y: 180), CGPoint(x: 110, y: 166)].enumerated() {
            let stone = SKSpriteNode(color: index == 1 ? dustOrange : paperWhite,
                                     size: CGSize(width: 3, height: 3))
            stone.position = start
            stone.zPosition = 3
            eventNode.addChild(stone)
            stone.run(.repeatForever(.sequence([
                .moveBy(x: 5, y: -7, duration: 0), .wait(forDuration: 0.10),
                .moveBy(x: 5, y: -7, duration: 0), .wait(forDuration: 0.10),
                .moveBy(x: 5, y: -7, duration: 0), .wait(forDuration: 0.10),
                .run { [weak stone] in stone?.position = start },
            ])), withKey: EventActionKey.motion)
        }
    }

    private func renderTracks(color: NSColor) {
        let trackPalette = eventPalette.merging(["T": color]) { _, new in new }
        let tracks = eventSprite(
            rows: Self.wagonTracks(),
            palette: trackPalette,
            scale: 2,
            position: CGPoint(x: 18, y: groundBottomY + 3),
            z: 2
        )
        tracks.run(blinkLoop(on: 0.18, off: 0.09), withKey: EventActionKey.blink)
    }

    // MARK: - End screen

    private func renderEndScene(_ snapshot: TrailPresentationSnapshot) {
        guard !hasEnded else { return }
        hasEnded = true

        let overlay = SKSpriteNode(color: inkBlack, size: size)
        overlay.anchorPoint = .zero
        overlay.zPosition = 200
        addChild(overlay)

        let lines = [snapshot.endingTitle, snapshot.endingDetail].compactMap { $0 }
            + snapshot.endingSummary
        for (index, line) in lines.prefix(6).enumerated() {
            let label = SKLabelNode(fontNamed: index == 0 ? "Courier-Bold" : "Courier")
            label.fontSize = index == 0 ? 11 : 7.5
            label.fontColor = index == 0 ? paperWhite : (index == 1 ? grassGreen : paperWhite)
            label.text = fittedMessage(line)
            label.position = CGPoint(x: size.width / 2, y: 132 - CGFloat(index * 18))
            label.zPosition = 201
            addChild(label)
        }
    }

    // MARK: - Pixel art engine

    private func pixelTexture(rows: [String], palette: [Character: NSColor]) -> SKTexture {
        let h = rows.count
        let w = rows.map { $0.count }.max() ?? 1
        guard h > 0, w > 0 else { return SKTexture() }
        var data = [UInt8](repeating: 0, count: w * h * 4)
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                guard let c = palette[ch]?.usingColorSpace(.deviceRGB) else { continue }
                let o = (y * w + x) * 4
                data[o]     = UInt8(c.redComponent * 255)
                data[o + 1] = UInt8(c.greenComponent * 255)
                data[o + 2] = UInt8(c.blueComponent * 255)
                data[o + 3] = 255
            }
        }
        guard let ctx = CGContext(
            data: &data,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = ctx.makeImage() else {
            return SKTexture()
        }
        let tex = SKTexture(cgImage: image)
        tex.filteringMode = .nearest   // keep pixels hard-edged
        return tex
    }

    private func pixelNode(rows: [String], palette: [Character: NSColor], scale: CGFloat) -> SKSpriteNode {
        let node = SKSpriteNode(texture: pixelTexture(rows: rows, palette: palette))
        node.size = CGSize(width: CGFloat(rows.map { $0.count }.max() ?? 1) * scale,
                           height: CGFloat(rows.count) * scale)
        return node
    }

    // MARK: - Sprite art

    static let wagonPalette: [Character: NSColor] = [
        "W": NSColor(calibratedWhite: 0.97, alpha: 1),
        "O": NSColor(calibratedRed: 1.00, green: 0.38, blue: 0.00, alpha: 1),
        "B": NSColor(calibratedRed: 0.00, green: 0.62, blue: 1.00, alpha: 1),
    ]

    private static func wheel(_ c: inout PixelCanvas, _ x: Int, _ y: Int) {
        c.rect(x + 2, y,     3, 1, "W")
        c.rect(x + 1, y + 1, 1, 1, "O"); c.rect(x + 5, y + 1, 1, 1, "O")
        c.rect(x,     y + 2, 1, 3, "W"); c.rect(x + 6, y + 2, 1, 3, "W")
        c.rect(x + 3, y + 3, 1, 1, "O")
        c.rect(x + 1, y + 5, 1, 1, "O"); c.rect(x + 5, y + 5, 1, 1, "O")
        c.rect(x + 2, y + 6, 3, 1, "W")
    }

    /// One small ox, facing left, as in the iconic 1985 travel animation.
    private static func ox(_ c: inout PixelCanvas, x: Int, phase: Int) {
        c.rect(x + 5,  9, 13, 7, "W")
        c.rect(x + 8,  8,  8, 1, "W")
        c.rect(x + 1,  9,  6, 5, "W")
        c.rect(x,     11,  2, 3, "O")
        c.rect(x + 2,  8,  1, 1, "O")
        c.rect(x + 5,  8,  1, 1, "O")
        c.rect(x + 9, 10,  4, 3, "O")
        c.rect(x + 18, 9,  1, 5, "W")

        let frontY = phase == 0 ? 16 : 17
        let rearY = phase == 0 ? 17 : 16
        c.rect(x + 6, frontY, 2, 5, "W")
        c.rect(x + 14, rearY, 2, 5, "W")
    }

    static func wagon(phase: Int) -> [String] {
        var c = PixelCanvas(w: 76, h: 23)
        ox(&c, x: 1, phase: phase)
        c.rect(20, 13, 14, 1, "W")

        // Orange box and wheels beneath a compact white canvas cover.
        c.rect(34, 10, 34, 6, "O")
        c.rect(38,  2, 26, 1, "W")
        c.rect(36,  3, 30, 7, "W")
        c.rect(36,  8, 30, 2, "B")
        c.rect(42,  3,  1, 7, "B")
        c.rect(58,  3,  1, 7, "B")
        wheel(&c, 38, 16)
        wheel(&c, 58, 16)
        return c.rows
    }

    static func horizon(_ terrain: Terrain) -> [String] {
        var c = PixelCanvas(w: 160, h: 18)
        let points: [(Int, Int)]
        switch terrain {
        case .mountains:
            points = [(0, 13), (12, 9), (22, 12), (35, 3), (48, 11), (62, 5),
                      (76, 12), (91, 7), (106, 13), (121, 8), (138, 12), (159, 9)]
        case .river:
            points = [(0, 12), (18, 10), (36, 13), (54, 10), (72, 13),
                      (90, 10), (108, 13), (126, 10), (144, 13), (159, 11)]
        case .prairie, .plains:
            points = [(0, 12), (16, 11), (30, 8), (45, 12), (60, 10),
                      (75, 13), (92, 9), (108, 8), (124, 12), (142, 10), (159, 11)]
        }

        for pair in zip(points, points.dropFirst()) {
            c.line(from: pair.0, to: pair.1, "C")
        }
        if terrain == .mountains {
            for (x, y) in points where y < 9 {
                c.rect(x - 1, y + 1, 3, 1, "W")
            }
        }
        return c.rows
    }

    static func landmark(named name: String) -> [String] {
        var c = PixelCanvas(w: 28, h: 22)
        if name == "Independence Rock" {
            c.rect(4, 12, 20, 8, "O")
            c.rect(7, 8, 14, 4, "O")
            c.rect(10, 6, 8, 2, "O")
        } else if name == "South Pass" {
            c.line(from: (1, 20), to: (10, 7), "W")
            c.line(from: (10, 7), to: (14, 15), "W")
            c.line(from: (14, 15), to: (20, 5), "W")
            c.line(from: (20, 5), to: (27, 20), "W")
            c.rect(18, 7, 4, 1, "B")
        } else if name == "Oregon City" {
            c.rect(3, 12, 7, 8, "W")
            c.rect(12, 9, 10, 11, "W")
            c.rect(23, 14, 4, 6, "W")
            c.line(from: (11, 9), to: (17, 4), "O")
            c.line(from: (17, 4), to: (23, 9), "O")
            c.rect(15, 15, 3, 5, "B")
        } else {
            c.rect(3, 10, 22, 10, "W")
            c.rect(1, 7, 6, 13, "W")
            c.rect(21, 7, 6, 13, "W")
            c.rect(11, 14, 6, 6, "B")
            c.rect(3, 7, 4, 2, "O")
            c.rect(21, 7, 4, 2, "O")
        }
        return c.rows
    }

    // MARK: Event sprite art

    static func breakdown(part: WagonPart, repaired: Bool) -> [String] {
        var c = PixelCanvas(w: 100, h: 30)
        ox(&c, x: 1, phase: 0)
        c.rect(20, 13, 12, 1, "W")
        c.rect(34, 10, 34, 6, "O")
        c.rect(38, 2, 26, 1, "W")
        c.rect(36, 3, 30, 7, "W")
        c.rect(36, 8, 30, 2, "B")

        switch part {
        case .wheel:
            wheel(&c, 38, 16)
            c.line(from: (60, 17), to: (67, 23), "O")
            c.line(from: (67, 17), to: (60, 23), "O")
            wheel(&c, 79, 20)
        case .axle:
            wheel(&c, 38, 16)
            wheel(&c, 58, 16)
            c.line(from: (43, 19), to: (62, 23), "O")
            c.line(from: (52, 18), to: (49, 24), "O")
        case .tongue:
            wheel(&c, 38, 16)
            wheel(&c, 58, 16)
            c.rect(20, 13, 5, 1, "W")
            c.rect(28, 13, 5, 1, "W")
            c.rect(25, 12, 1, 3, "O")
            c.rect(27, 12, 1, 3, "O")
        }

        // Kneeling repair figure and small hand tool.
        c.rect(72, 15, 4, 4, "W")
        c.rect(70, 19, 6, 5, repaired ? "G" : "O")
        c.line(from: (70, 22), to: (66, 26), "W")
        c.line(from: (74, 23), to: (79, 26), "W")
        c.line(from: (70, 20), to: (64, 22), "B")
        return c.rows
    }

    static func riverWater() -> [String] {
        var c = PixelCanvas(w: 154, h: 20)
        c.rect(0, 0, 154, 20, "B")
        for y in stride(from: 2, to: 20, by: 4) {
            for x in stride(from: (y / 2) % 4, to: 154, by: 12) {
                c.rect(x, y, 5, 1, "W")
            }
        }
        return c.rows
    }

    static func riverWagon(_ outcome: RiverCrossingOutcome) -> [String] {
        var c = PixelCanvas(w: 78, h: 29)
        ox(&c, x: 1, phase: 1)
        c.rect(20, 13, 14, 1, "W")
        c.rect(34, 10, 34, 6, "O")
        c.rect(38, 2, 26, 1, "W")
        c.rect(36, 3, 30, 7, "W")
        c.rect(36, 8, 30, 2, "B")
        wheel(&c, 38, 16)
        wheel(&c, 58, 16)
        c.rect(0, 23, 78, 4, "B")
        for x in stride(from: 0, to: 78, by: 9) { c.rect(x, 23, 4, 1, "W") }

        switch outcome {
        case .travelerLost:
            c.line(from: (43, 4), to: (61, 17), "O")
            c.line(from: (61, 4), to: (43, 17), "O")
        case .impassable:
            c.rect(67, 19, 3, 8, "W")
            c.rect(72, 17, 3, 10, "W")
        case .success, .suppliesLost:
            break
        }
        return c.rows
    }

    static func crate() -> [String] {
        [
            "OOOOOOOO",
            "OW....WO",
            "O.W..W.O",
            "O..WW..O",
            "OW....WO",
            "OOOOOOOO",
        ]
    }

    static func buffalo(phase: Int) -> [String] {
        var c = PixelCanvas(w: 25, h: 13)
        c.rect(5, 3, 14, 6, "P")
        c.rect(3, 4, 5, 5, "P")
        c.rect(1, 5, 3, 4, "P")
        c.rect(0, 4, 2, 1, "O")
        c.rect(1, 3, 1, 1, "W")
        c.rect(18, 5, 5, 4, "P")
        c.rect(22, 4, 2, 1, "O")
        c.rect(7, 9, 2, phase == 0 ? 4 : 3, "P")
        c.rect(16, 9, 2, phase == 0 ? 3 : 4, "P")
        return c.rows
    }

    static func hunter() -> [String] {
        var c = PixelCanvas(w: 17, h: 20)
        c.rect(10, 1, 4, 4, "W")
        c.rect(8, 5, 7, 8, "O")
        c.line(from: (8, 7), to: (2, 11), "W")
        c.line(from: (8, 9), to: (1, 9), "W")
        c.rect(0, 8, 9, 1, "B")
        c.line(from: (10, 13), to: (7, 19), "W")
        c.line(from: (13, 13), to: (16, 19), "W")
        return c.rows
    }

    static func abandonedWagon() -> [String] {
        var c = PixelCanvas(w: 68, h: 25)
        c.rect(18, 11, 39, 5, "O")
        c.line(from: (23, 10), to: (28, 3), "W")
        c.line(from: (28, 3), to: (45, 6), "W")
        c.line(from: (45, 6), to: (53, 11), "W")
        c.line(from: (2, 15), to: (18, 13), "W")
        wheel(&c, 22, 16)
        c.line(from: (48, 17), to: (55, 23), "O")
        c.line(from: (55, 17), to: (48, 23), "O")
        c.rect(59, 15, 5, 5, "B")
        return c.rows
    }

    static func foodSack() -> [String] {
        [".OOO.", ".OWO.", "OOOOO", "OWWWO", "OWWWO", ".OOO."]
    }

    static func looseWheel() -> [String] {
        [".WWW.", "W.O.W", "WOOOW", "W.O.W", ".WWW."]
    }

    static func spareAxle() -> [String] {
        ["W.........W", "WWWWWWWWWWW", "W.........W"]
    }

    static func coat() -> [String] {
        [".O...O.", "OOOOOOO", "OOWWWOO", ".OWWWO.", ".OWWWO.", ".OOOOO."]
    }

    static func wolf(eyes: Bool) -> [String] {
        var c = PixelCanvas(w: 28, h: 12)
        c.rect(5, 4, 14, 5, "P")
        c.rect(18, 2, 7, 6, "P")
        c.rect(19, 0, 2, 3, "P")
        c.rect(24, 0, 2, 3, "P")
        c.rect(24, 5, 4, 3, "P")
        c.line(from: (5, 4), to: (0, 1), "P")
        c.rect(7, 9, 2, 3, "P")
        c.rect(16, 9, 2, 3, "P")
        if eyes { c.rect(21, 4, 1, 1, "W"); c.rect(24, 4, 1, 1, "O") }
        return c.rows
    }

    static func illnessCamp(_ ailment: Ailment) -> [String] {
        var c = PixelCanvas(w: 34, h: 18)
        let blanket: Character = switch ailment {
        case .dysentery, .cholera: "B"
        case .typhoid, .injury: "O"
        case .measles: "P"
        case .snakebite: "G"
        case .exhaustion: "W"
        }
        c.rect(4, 10, 24, 6, blanket)
        c.rect(7, 8, 6, 4, "W")
        c.rect(2, 16, 30, 1, "W")
        c.rect(17, 11, 1, 1, "W")
        c.rect(22, 13, 1, 1, "W")
        return c.rows
    }

    static func snake() -> [String] {
        [
            "..........OOO..",
            "..OOO...OO.OOO.",
            ".OO.OO.OO....O.",
            "OO...OOO.......",
            ".O.............",
        ]
    }

    static func springScene() -> [String] {
        var c = PixelCanvas(w: 54, h: 20)
        c.rect(0, 15, 54, 3, "G")
        c.rect(6, 11, 13, 4, "W")
        c.rect(10, 8, 8, 3, "W")
        c.rect(16, 12, 7, 3, "B")
        c.line(from: (19, 13), to: (32, 17), "B")
        c.rect(27, 16, 24, 2, "B")
        c.rect(37, 4, 2, 12, "W")
        c.rect(31, 5, 14, 5, "G")
        c.rect(28, 7, 19, 3, "G")
        for x in stride(from: 27, to: 52, by: 6) { c.rect(x, 17, 3, 1, "W") }
        return c.rows
    }

    static func tradeCamp() -> [String] {
        var c = PixelCanvas(w: 130, h: 25)
        c.line(from: (2, 22), to: (18, 6), "W")
        c.line(from: (18, 6), to: (34, 22), "W")
        c.rect(8, 18, 21, 4, "O")
        c.rect(48, 8, 5, 5, "W")
        c.rect(46, 13, 9, 7, "P")
        c.line(from: (48, 20), to: (44, 24), "W")
        c.line(from: (53, 20), to: (57, 24), "W")
        c.rect(76, 8, 5, 5, "W")
        c.rect(74, 13, 9, 7, "O")
        c.line(from: (76, 20), to: (72, 24), "W")
        c.line(from: (81, 20), to: (85, 24), "W")
        c.rect(101, 17, 7, 5, "O")
        c.rect(112, 15, 10, 7, "B")
        return c.rows
    }

    static func squallClouds() -> [String] {
        var c = PixelCanvas(w: 70, h: 16)
        c.rect(5, 8, 56, 6, "P")
        c.rect(13, 4, 20, 6, "P")
        c.rect(38, 2, 17, 8, "P")
        c.rect(58, 10, 11, 4, "P")
        c.rect(1, 13, 64, 2, "B")
        return c.rows
    }

    static func lightningBolt() -> [String] {
        ["....WW", "...WW.", "..WW..", "...WW.", "..WW..", ".WW...", "WW...."]
    }

    static func tallGrass() -> [String] {
        var c = PixelCanvas(w: 94, h: 12)
        for x in stride(from: 1, to: 94, by: 5) {
            c.line(from: (x, 11), to: (x + (x % 3) - 1, x % 5), "W")
            c.line(from: (x, 8), to: (x + 3, 5), "O")
        }
        return c.rows
    }

    static func cottonwoodLeaves() -> [String] {
        var c = PixelCanvas(w: 80, h: 22)
        c.rect(3, 18, 75, 3, "B")
        c.rect(14, 5, 2, 13, "W")
        c.rect(10, 2, 12, 7, "G")
        c.rect(34, 7, 2, 11, "W")
        c.rect(29, 4, 14, 7, "G")
        c.rect(56, 6, 2, 12, "W")
        c.rect(51, 2, 15, 8, "G")
        for point in [(8, 1), (24, 5), (44, 1), (70, 7), (48, 11), (27, 13)] {
            c.rect(point.0, point.1, 2, 1, "W")
        }
        return c.rows
    }

    static func longShadows() -> [String] {
        var c = PixelCanvas(w: 140, h: 16)
        for y in stride(from: 1, to: 16, by: 4) {
            c.line(from: (4 + y, y), to: (118 + y, y + 4), "O")
        }
        return c.rows
    }

    static func lowClouds() -> [String] {
        var c = PixelCanvas(w: 120, h: 14)
        c.rect(4, 7, 45, 5, "W")
        c.rect(13, 4, 24, 4, "W")
        c.rect(57, 5, 55, 6, "P")
        c.rect(72, 2, 26, 5, "P")
        return c.rows
    }

    static func heatShimmer() -> [String] {
        var c = PixelCanvas(w: 140, h: 12)
        for y in stride(from: 1, to: 12, by: 3) {
            for x in stride(from: y * 2, to: 140, by: 18) {
                c.line(from: (x, y), to: (min(139, x + 8), y + 1), "O")
            }
        }
        return c.rows
    }

    static func frostGrass() -> [String] {
        var c = PixelCanvas(w: 145, h: 12)
        for x in stride(from: 1, to: 145, by: 5) {
            c.line(from: (x, 11), to: (x + (x % 2), 3 + (x % 4)), "W")
            c.rect(x - 1, 3 + (x % 4), 3, 1, "B")
        }
        return c.rows
    }

    static func wagonTracks() -> [String] {
        var c = PixelCanvas(w: 140, h: 15)
        c.line(from: (0, 14), to: (139, 5), "T")
        c.line(from: (0, 7), to: (139, 1), "T")
        for x in stride(from: 5, to: 135, by: 12) {
            c.rect(x, max(1, 13 - x / 18), 6, 1, "T")
        }
        return c.rows
    }
}
