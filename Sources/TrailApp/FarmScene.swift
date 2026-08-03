import FarmCore
import SpriteKit

struct FarmPresentationSnapshot {
    let revision: Int
    let seed: UInt64
    let plan: FarmPlan
    let week: Int
    let season: FarmSeason
    let weekOfSeason: Int
    let soilQuality: Int
    let moisture: Int
    let storedFood: Int
    let cash: Int
    let buildingCondition: Int
    let cropStage: CropStage
    let weather: FarmWeather?
    let visualEvent: FarmVisualEvent?
    let message: String
    let outcome: FarmOutcome?

    init(state: FarmState, latestEvent: String, revision: Int = 0) {
        self.revision = revision
        seed = state.seed
        plan = state.plan
        week = state.week
        season = state.season
        weekOfSeason = state.weekOfSeason
        soilQuality = state.soilQuality
        moisture = state.moisture
        storedFood = state.storedFood
        cash = state.cash
        buildingCondition = state.buildingCondition
        cropStage = state.cropStage
        weather = state.currentWeather
        visualEvent = state.latestVisualEvent
        message = latestEvent
        outcome = state.outcome
    }

    init(simulation: FarmSimulation, latestEvent: String, revision: Int = 0) {
        self.init(state: simulation.state, latestEvent: latestEvent, revision: revision)
    }
}

/// A fixed, whole-pixel farm view. The homestead never changes position, so
/// crop, weather, and season changes read as changes to one place over time.
final class FarmScene: SKScene {
    static let logicalSize = CGSize(width: 320, height: 200)

    private enum Layout {
        static let panelTop: CGFloat = 56
        static let messageTop: CGFloat = 72
        static let horizon: CGFloat = 139
    }

    private struct Palette {
        let sky: NSColor
        let distant: NSColor
        let field: NSColor
        let soil: NSColor
        let crop: NSColor
        let accent: NSColor
    }

    private var pendingSnapshot: FarmPresentationSnapshot

    init(snapshot: FarmPresentationSnapshot) {
        pendingSnapshot = snapshot
        super.init(size: Self.logicalSize)
        scaleMode = .aspectFit
        anchorPoint = .zero
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        render(pendingSnapshot)
    }

    func apply(_ snapshot: FarmPresentationSnapshot) {
        pendingSnapshot = snapshot
        guard view != nil else { return }
        render(snapshot)
    }

    private func render(_ snapshot: FarmPresentationSnapshot) {
        removeAllActions()
        removeAllChildren()
        backgroundColor = .black

        let palette = palette(for: snapshot.season)
        addRect(x: 0, y: Layout.messageTop, width: 320, height: 128, color: palette.sky, z: 0)
        drawHorizon(palette: palette, season: snapshot.season)
        drawField(snapshot: snapshot, palette: palette)
        drawFence(season: snapshot.season)
        drawFarmhouse(season: snapshot.season)
        drawBarn(season: snapshot.season, condition: snapshot.buildingCondition)
        drawTree(season: snapshot.season)
        drawWeather(snapshot: snapshot, palette: palette)
        drawEvent(snapshot.visualEvent, palette: palette)
        drawPanel(snapshot: snapshot)
    }

    private func palette(for season: FarmSeason) -> Palette {
        switch season {
        case .spring:
            Palette(
                sky: color(0.10, 0.60, 0.94), distant: color(0.34, 0.72, 0.26),
                field: color(0.18, 0.67, 0.08), soil: color(0.40, 0.20, 0.07),
                crop: color(0.38, 0.93, 0.09), accent: color(0.98, 0.86, 0.18)
            )
        case .summer:
            Palette(
                sky: color(0.04, 0.55, 0.93), distant: color(0.08, 0.50, 0.08),
                field: color(0.10, 0.54, 0.02), soil: color(0.46, 0.24, 0.06),
                crop: color(0.92, 0.76, 0.08), accent: color(1.00, 0.43, 0.02)
            )
        case .autumn:
            Palette(
                sky: color(0.20, 0.48, 0.77), distant: color(0.45, 0.26, 0.08),
                field: color(0.67, 0.39, 0.04), soil: color(0.34, 0.15, 0.04),
                crop: color(0.97, 0.62, 0.04), accent: color(0.84, 0.18, 0.04)
            )
        case .winter:
            Palette(
                sky: color(0.20, 0.38, 0.64), distant: color(0.12, 0.22, 0.39),
                field: color(0.88, 0.91, 0.92), soil: color(0.28, 0.25, 0.24),
                crop: color(0.49, 0.39, 0.27), accent: color(0.96, 0.97, 0.93)
            )
        }
    }

    private func drawHorizon(palette: Palette, season: FarmSeason) {
        addRect(x: 0, y: 126, width: 320, height: 13, color: palette.distant, z: 1)
        for index in 0..<9 {
            let x = CGFloat(index * 42 - 18)
            let height = CGFloat(8 + (index % 3) * 4)
            addRect(x: x, y: 139, width: 34, height: height, color: palette.distant, z: 1)
            addRect(x: x + 6, y: 139 + height, width: 22, height: 4, color: palette.distant, z: 1)
        }
        if season == .winter {
            addRect(x: 0, y: 126, width: 320, height: 3, color: .white, z: 2)
        }
    }

    private func drawField(snapshot: FarmPresentationSnapshot, palette: Palette) {
        addRect(x: 0, y: Layout.messageTop, width: 320, height: 54, color: palette.field, z: 2)

        // Receding furrows keep the broad field recognizable even when fallow.
        for row in 0..<7 {
            let y = CGFloat(76 + row * 7)
            let inset = CGFloat(row * 8)
            addRect(x: inset, y: y, width: 320 - inset * 2, height: 2, color: palette.soil, z: 3)
        }

        if snapshot.season == .winter {
            for row in 0..<5 {
                addRect(x: CGFloat(row * 17), y: CGFloat(75 + row * 10), width: 290 - CGFloat(row * 16), height: 3, color: .white, z: 4)
            }
            return
        }

        let cropColor: NSColor = snapshot.plan == .beans
            ? color(0.68, 0.24, 0.82)
            : palette.crop
        switch snapshot.cropStage {
        case .bare:
            break
        case .sown:
            for index in 0..<18 {
                addRect(x: CGFloat(8 + index * 17), y: CGFloat(81 + (index % 5) * 8), width: 2, height: 2, color: cropColor, z: 5)
            }
        case .sprouting:
            drawCrops(height: 4, spacing: 16, color: cropColor)
        case .growing:
            drawCrops(height: 9, spacing: 14, color: cropColor)
        case .mature:
            drawCrops(height: 15, spacing: 12, color: cropColor)
        case .harvested:
            for index in 0..<24 {
                let x = CGFloat(5 + index * 13)
                let y = CGFloat(79 + (index % 5) * 8)
                addRect(x: x, y: y, width: 2, height: 5, color: cropColor, z: 5)
            }
            addRect(x: 118, y: 91, width: 19, height: 10, color: palette.crop, z: 7)
            addRect(x: 121, y: 101, width: 13, height: 3, color: palette.accent, z: 7)
        case .resting:
            for index in 0..<10 {
                addRect(x: CGFloat(18 + index * 31), y: CGFloat(78 + (index % 4) * 10), width: 3, height: 3, color: palette.soil, z: 5)
            }
        }
    }

    private func drawCrops(height: Int, spacing: Int, color cropColor: NSColor) {
        var index = 0
        for y in stride(from: 81, through: 116, by: 8) {
            let offset = (index % 2) * (spacing / 2)
            for x in stride(from: 5 + offset, through: 315, by: spacing) {
                let plantHeight = max(2, height - index)
                addRect(x: CGFloat(x), y: CGFloat(y), width: 2, height: CGFloat(plantHeight), color: cropColor, z: 5)
                if plantHeight > 5 {
                    addRect(x: CGFloat(x - 2), y: CGFloat(y + plantHeight - 5), width: 6, height: 2, color: cropColor, z: 5)
                }
            }
            index += 1
        }
    }

    private func drawFence(season: FarmSeason) {
        let wood = season == .winter ? color(0.29, 0.25, 0.22) : color(0.30, 0.16, 0.05)
        addRect(x: 0, y: 119, width: 320, height: 3, color: wood, z: 9)
        addRect(x: 0, y: 111, width: 320, height: 2, color: wood, z: 9)
        for x in stride(from: 4, through: 316, by: 28) {
            addRect(x: CGFloat(x), y: 107, width: 3, height: 19, color: wood, z: 10)
        }
    }

    private func drawFarmhouse(season: FarmSeason) {
        let wall = season == .winter ? color(0.86, 0.88, 0.88) : color(0.94, 0.84, 0.63)
        let roof = color(0.17, 0.10, 0.08)
        addRect(x: 22, y: 125, width: 55, height: 31, color: wall, z: 12)
        for step in 0..<8 {
            addRect(x: CGFloat(16 + step * 4), y: CGFloat(156 + step * 2), width: CGFloat(67 - step * 8), height: 2, color: roof, z: 13)
        }
        addRect(x: 60, y: 163, width: 7, height: 20, color: roof, z: 12)
        addRect(x: 31, y: 133, width: 12, height: 13, color: color(0.03, 0.34, 0.59), z: 14)
        addRect(x: 55, y: 125, width: 13, height: 21, color: color(0.40, 0.20, 0.07), z: 14)
        addRect(x: 57, y: 135, width: 2, height: 2, color: color(0.98, 0.76, 0.10), z: 15)
        if season == .winter {
            addRect(x: 18, y: 156, width: 61, height: 3, color: .white, z: 15)
        }
    }

    private func drawBarn(season: FarmSeason, condition: Int) {
        let barn = condition < 50 ? color(0.52, 0.12, 0.04) : color(0.76, 0.14, 0.04)
        let trim = season == .winter ? color(0.92, 0.94, 0.94) : color(0.95, 0.82, 0.60)
        addRect(x: 246, y: 122, width: 54, height: 42, color: barn, z: 12)
        for step in 0..<7 {
            addRect(x: CGFloat(240 + step * 4), y: CGFloat(164 + step * 2), width: CGFloat(66 - step * 8), height: 2, color: color(0.16, 0.09, 0.07), z: 13)
        }
        addRect(x: 263, y: 122, width: 20, height: 27, color: color(0.17, 0.08, 0.04), z: 14)
        addRect(x: 268, y: 153, width: 11, height: 9, color: trim, z: 14)
        addRect(x: 246, y: 145, width: 54, height: 3, color: trim, z: 14)
        if condition < 65 {
            addRect(x: 291, y: 129, width: 3, height: 13, color: color(0.08, 0.05, 0.04), z: 15)
        }
        if season == .winter {
            addRect(x: 242, y: 164, width: 62, height: 3, color: .white, z: 15)
        }
    }

    private func drawTree(season: FarmSeason) {
        let trunk = color(0.28, 0.14, 0.05)
        addRect(x: 207, y: 121, width: 6, height: 43, color: trunk, z: 11)
        addRect(x: 199, y: 145, width: 8, height: 4, color: trunk, z: 11)
        addRect(x: 213, y: 151, width: 8, height: 4, color: trunk, z: 11)
        guard season != .winter else { return }
        let leaves = season == .autumn ? color(0.92, 0.34, 0.02) : color(0.05, 0.43, 0.05)
        addRect(x: 192, y: 154, width: 34, height: 18, color: leaves, z: 12)
        addRect(x: 198, y: 172, width: 23, height: 8, color: leaves, z: 12)
        addRect(x: 187, y: 160, width: 10, height: 8, color: leaves, z: 12)
    }

    private func drawWeather(snapshot: FarmPresentationSnapshot, palette: Palette) {
        guard let weather = snapshot.weather else { return }
        switch weather {
        case .gentleRain:
            for index in 0..<18 {
                let x = deterministic(index, snapshot: snapshot, modulo: 310) + 5
                let y = 148 + deterministic(index + 40, snapshot: snapshot, modulo: 43)
                addRect(x: CGFloat(x), y: CGFloat(y), width: 2, height: 5, color: color(0.70, 0.88, 1.00), z: 20)
            }
        case .warmSun, .clear:
            addRect(x: 281, y: 177, width: 14, height: 14, color: palette.accent, z: 8)
            if weather == .warmSun {
                addRect(x: 286, y: 171, width: 4, height: 4, color: palette.accent, z: 8)
                addRect(x: 286, y: 193, width: 4, height: 4, color: palette.accent, z: 8)
                addRect(x: 274, y: 182, width: 4, height: 4, color: palette.accent, z: 8)
                addRect(x: 298, y: 182, width: 4, height: 4, color: palette.accent, z: 8)
            }
        case .drySpell:
            addRect(x: 282, y: 177, width: 15, height: 15, color: color(1.00, 0.40, 0.00), z: 8)
            for index in 0..<6 {
                addRect(x: CGFloat(95 + index * 24), y: CGFloat(75 + index % 2 * 4), width: 10, height: 2, color: color(0.18, 0.08, 0.02), z: 8)
            }
        case .lateFrost:
            for index in 0..<24 {
                let x = deterministic(index, snapshot: snapshot, modulo: 310) + 5
                let y = 76 + deterministic(index + 20, snapshot: snapshot, modulo: 48)
                addRect(x: CGFloat(x), y: CGFloat(y), width: 3, height: 2, color: .white, z: 20)
            }
        case .wind:
            for index in 0..<5 {
                let x = 105 + index * 31
                let y = 165 + (index % 3) * 8
                addRect(x: CGFloat(x), y: CGFloat(y), width: 20, height: 2, color: color(0.85, 0.89, 0.88), z: 20)
                addRect(x: CGFloat(x + 16), y: CGFloat(y - 3), width: 7, height: 2, color: color(0.85, 0.89, 0.88), z: 20)
            }
        case .snow:
            for index in 0..<28 {
                let x = deterministic(index, snapshot: snapshot, modulo: 314) + 3
                let y = 132 + deterministic(index + 80, snapshot: snapshot, modulo: 63)
                addRect(x: CGFloat(x), y: CGFloat(y), width: 3, height: 3, color: .white, z: 20)
            }
        case .thaw:
            for index in 0..<9 {
                addRect(x: CGFloat(25 + index * 34), y: CGFloat(75 + index % 3 * 5), width: 12, height: 2, color: color(0.06, 0.34, 0.62), z: 20)
            }
        }
    }

    // MARK: - Event vignettes

    private func drawEvent(_ event: FarmVisualEvent?, palette: Palette) {
        guard let event else { return }
        let ink = color(0.06, 0.05, 0.04)
        let white = color(0.96, 0.96, 0.92)
        let brown = color(0.43, 0.20, 0.05)
        let orange = color(1.00, 0.38, 0.00)
        let green = color(0.08, 0.42, 0.04)
        let eventPalette: [Character: NSColor] = [
            "K": ink, "W": white, "B": brown, "O": orange,
            "G": green, "C": palette.crop, "S": palette.soil,
        ]

        switch event {
        case .weeds:
            for offset in [0, 66, 137] {
                drawPixels(
                    ["K.K.K", ".KKK.", "..K..", ".K.K."],
                    palette: eventPalette, scale: 3,
                    x: CGFloat(45 + offset), y: CGFloat(82 + offset % 17), z: 31
                )
            }
        case .crows:
            drawPixels(
                ["K...K.....K...K", ".K.K.......K.K.", "..K.........K.."],
                palette: eventPalette, scale: 2, x: 126, y: 168, z: 31
            )
            drawPixels(
                ["K...K", ".K.K.", "..K.."],
                palette: eventPalette, scale: 2, x: 211, y: 157, z: 31
            )
        case .deer:
            drawPixels(
                ["....B..B.", "....BBBB.", "BBBBBBB..", ".BBBB....", ".B..B....", ".B..B...."],
                palette: eventPalette, scale: 3, x: 133, y: 125, z: 31
            )
            drawPixels(
                ["...B.B", "...BBB", "BBBB..", ".BBB..", ".B.B.."],
                palette: eventPalette, scale: 3, x: 179, y: 127, z: 31
            )
        case .neighborProvisions:
            drawPixels(
                [".OO.", ".OO.", "WWWW", ".BB.", ".BB.", "B..B"],
                palette: eventPalette, scale: 3, x: 84, y: 123, z: 32
            )
            drawPixels(
                ["BBBBB", "BOOOB", "BBBBB"],
                palette: eventPalette, scale: 3, x: 101, y: 122, z: 32
            )
        case .windDamage:
            for offset in stride(from: 0, through: 165, by: 55) {
                drawPixels(
                    ["....B", "...B.", "..B..", ".B...", "B...."],
                    palette: eventPalette, scale: 3,
                    x: CGFloat(55 + offset), y: CGFloat(84 + offset % 17), z: 31
                )
            }
            drawPixels(
                ["OOO....OOO", "...OOO....", "......OO.."],
                palette: eventPalette, scale: 2, x: 108, y: 172, z: 32
            )
        case .repairDay:
            drawPixels(
                ["W.....W", ".W...W.", ".W...W.", "..W.W..", "..W.W..", "...W..."],
                palette: eventPalette, scale: 3, x: 222, y: 125, z: 32
            )
            drawPixels(
                [".OO.", ".OO.", "WWWW", ".BB.", "B..B"],
                palette: eventPalette, scale: 3, x: 207, y: 122, z: 33
            )
            drawPixels(["KKK", ".K.", ".B."], palette: eventPalette, scale: 3, x: 235, y: 150, z: 34)
        case .harvest(let plan, _):
            let load = plan == .beans ? "O" : "C"
            drawPixels(
                ["..\(load)\(load)\(load)\(load)...", ".\(load)\(load)\(load)\(load)\(load)\(load)..", "BBBBBBBB", "B......B", ".K....K."],
                palette: eventPalette, scale: 3, x: 137, y: 98, z: 32
            )
            drawPixels(
                [".OO.", ".OO.", "WWWW", ".BB.", "B..B"],
                palette: eventPalette, scale: 3, x: 116, y: 102, z: 33
            )
        case .yearEnd:
            drawPixels(
                [".WWWW.", "WW..WW", "W....W", "W.KK.W", ".WWWW."],
                palette: eventPalette, scale: 3, x: 86, y: 124, z: 32
            )
            drawPixels(
                ["BBBBB", "B...B", "B...B", "BBBBB"],
                palette: eventPalette, scale: 3, x: 110, y: 123, z: 31
            )
        }
    }

    private func drawPixels(
        _ rows: [String],
        palette: [Character: NSColor],
        scale: CGFloat,
        x: CGFloat,
        y: CGFloat,
        z: CGFloat
    ) {
        for (rowIndex, row) in rows.enumerated() {
            let rowY = y + CGFloat(rows.count - rowIndex - 1) * scale
            for (column, character) in row.enumerated() {
                guard let pixelColor = palette[character] else { continue }
                addRect(
                    x: x + CGFloat(column) * scale,
                    y: rowY,
                    width: scale,
                    height: scale,
                    color: pixelColor,
                    z: z
                )
            }
        }
    }

    private func drawPanel(snapshot: FarmPresentationSnapshot) {
        addRect(x: 0, y: 0, width: 320, height: Layout.panelTop, color: .black, z: 50)
        addRect(x: 0, y: Layout.panelTop, width: 320, height: 16, color: color(0.11, 0.11, 0.11), z: 50)

        let green = color(0.12, 1.00, 0.34)
        let paper = color(0.96, 0.96, 0.92)
        addLabel(
            "YEAR 1  \(name(snapshot.season)) \(snapshot.weekOfSeason)/13  \(name(snapshot.plan))",
            y: 43, color: green, size: 8.5
        )
        addLabel(
            "FIELD \(name(snapshot.cropStage))  \(weatherName(snapshot.weather))",
            y: 28, color: green, size: 8.5
        )
        addLabel(
            "SOIL \(snapshot.soilQuality)  WATER \(snapshot.moisture)  FOOD \(snapshot.storedFood)  $\(snapshot.cash)",
            y: 13, color: green, size: 8.5
        )
        let message = snapshot.outcome.map(outcomeMessage) ?? snapshot.message
        addLabel(fitted(message), y: 62, color: paper, size: 7.5)
    }

    private func addLabel(_ text: String, y: CGFloat, color: NSColor, size: CGFloat) {
        let label = SKLabelNode(fontNamed: "Courier-Bold")
        label.text = text.uppercased()
        label.fontSize = size
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 160, y: y)
        label.zPosition = 60
        addChild(label)
    }

    private func fitted(_ message: String) -> String {
        let fallback = "THE FARM SETTLES INTO THE WEEK."
        let text = message.isEmpty ? fallback : message
        if text.count <= 54 { return text }
        return String(text.prefix(51)).trimmingCharacters(in: .whitespaces) + "..."
    }

    private func outcomeMessage(_ outcome: FarmOutcome) -> String {
        switch outcome {
        case .stable: "THE FARM ENTERS SPRING READY FOR ANOTHER YEAR."
        case .strained: "THE FARM SURVIVED, BUT ITS RESERVES ARE THIN."
        case .debt: "WINTER COSTS EXCEEDED THE FARM'S RESERVES."
        }
    }

    private func name<T: RawRepresentable>(_ value: T) -> String where T.RawValue == String {
        value.rawValue.replacingOccurrences(of: "_", with: " ").uppercased()
    }

    private func weatherName(_ weather: FarmWeather?) -> String {
        guard let weather else { return "WAITING" }
        return switch weather {
        case .gentleRain: "GENTLE RAIN"
        case .clear: "CLEAR"
        case .warmSun: "WARM SUN"
        case .drySpell: "DRY SPELL"
        case .lateFrost: "LATE FROST"
        case .wind: "WIND"
        case .snow: "SNOW"
        case .thaw: "THAW"
        }
    }

    private func deterministic(
        _ index: Int,
        snapshot: FarmPresentationSnapshot,
        modulo: Int
    ) -> Int {
        var value = snapshot.seed
        value &+= UInt64(snapshot.week &* 97 &+ index &* 1_009)
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        return Int(value % UInt64(modulo))
    }

    private func addRect(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        color: NSColor,
        z: CGFloat
    ) {
        guard width > 0, height > 0 else { return }
        let node = SKSpriteNode(color: color, size: CGSize(width: width, height: height))
        node.anchorPoint = .zero
        node.position = CGPoint(x: x.rounded(), y: y.rounded())
        node.zPosition = z
        addChild(node)
    }

    private func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }
}
