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
        let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let tex = SKTexture(cgImage: ctx.makeImage()!)
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
}
