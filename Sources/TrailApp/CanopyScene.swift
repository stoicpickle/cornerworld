import AppKit
import CanopyCore
import SpriteKit

struct CanopyPresentationSnapshot {
    let revision: Int
    let seed: UInt64
    let tick: Int
    let vines: [CanopyVine]
    let density: Int
    let swingCount: Int
    let visualEvent: CanopyVisualEvent?
    let message: String

    init(simulation: CanopySimulation, latestEvent: String, revision: Int = 0) {
        seed = simulation.seed
        tick = simulation.tickCount
        vines = simulation.vines
        density = simulation.density
        swingCount = simulation.swingCount
        visualEvent = simulation.latestVisualEvent
        message = latestEvent
        self.revision = revision
    }

    init(state: CanopyState, latestEvent: String, revision: Int = 0) {
        self.revision = revision
        seed = state.seed
        tick = state.tick
        vines = state.vines
        let capacity = CanopySimulation.maximumVines * CanopySimulation.maximumVineHeight
        density = min(100, state.vines.reduce(0) { $0 + $1.height } * 100 / capacity)
        swingCount = state.swingCount
        visualEvent = state.latestVisualEvent
        message = latestEvent
    }
}

final class CanopyScene: SKScene {
    static let logicalSize = CGSize(width: 320, height: 200)

    private enum Layout {
        static let panelTop: CGFloat = 42
        static let messageTop: CGFloat = 58
        static let worldBottom: CGFloat = 58
    }

    private enum SwingTiming {
        /// Four clean arc segments total 1.28 seconds for a readable, lazy swing.
        static let arcSegment: TimeInterval = 0.32
        static let impactTurn: TimeInterval = 0.08
        static let impactPause: TimeInterval = 0.18
        static let impactSlide: TimeInterval = 0.75
    }

    private var pendingSnapshot: CanopyPresentationSnapshot
    private let staticEventPose: Bool
    private struct MistParticle {
        let node: SKSpriteNode
        let origin: CGPoint
        let drift: CGFloat
        let cycle: TimeInterval
        let phase: CGFloat
    }
    private struct FireflyParticle {
        let node: SKSpriteNode
        let origin: CGPoint
        let drift: CGVector
        let cycle: TimeInterval
        let phase: CGFloat
    }
    private var mistParticles: [MistParticle] = []
    private var fireflyParticles: [FireflyParticle] = []
    private var atmosphereLayer: SKNode?
    private var atmosphereSeed: UInt64?
    private lazy var fallAnimationTextures: [SKTexture] = loadFallTextures()

    init(snapshot: CanopyPresentationSnapshot, staticEventPose: Bool = false) {
        pendingSnapshot = snapshot
        self.staticEventPose = staticEventPose
        super.init(size: Self.logicalSize)
        scaleMode = .aspectFit
        anchorPoint = .zero
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        render(pendingSnapshot)
    }

    override func update(_ currentTime: TimeInterval) {
        guard !staticEventPose else { return }
        for particle in mistParticles {
            let angle = CGFloat(currentTime / particle.cycle) * 2 * .pi + particle.phase
            particle.node.position.x = particle.origin.x + sin(angle) * particle.drift
            particle.node.alpha = 0.045 + (cos(angle) + 1) * 0.008
        }
        for particle in fireflyParticles {
            let angle = CGFloat(currentTime / particle.cycle) * 2 * .pi + particle.phase
            let glow = (sin(angle) + 1) / 2
            particle.node.position = CGPoint(
                x: particle.origin.x + sin(angle * 0.62) * particle.drift.dx,
                y: particle.origin.y + cos(angle * 0.47) * particle.drift.dy
            )
            particle.node.alpha = 0.16 + glow * 0.52
        }
    }

    func apply(_ snapshot: CanopyPresentationSnapshot) {
        pendingSnapshot = snapshot
        guard view != nil else { return }
        render(snapshot)
    }

    private func render(_ snapshot: CanopyPresentationSnapshot) {
        // The atmosphere outlives gameplay redraws so its long, quiet phases never restart on a tick.
        atmosphereLayer?.removeFromParent()
        removeAllActions()
        removeAllChildren()
        backgroundColor = .black

        drawJungle(snapshot: snapshot)
        drawAtmosphere(snapshot: snapshot)
        drawVines(snapshot.vines)
        drawEvent(snapshot.visualEvent, snapshot: snapshot)
        drawPanel(snapshot)
    }

    private func drawJungle(snapshot: CanopyPresentationSnapshot) {
        let sky = color(0.018, 0.030, 0.060)
        let distantTrunk = color(0.030, 0.050, 0.055)
        let distantLeaf = color(0.035, 0.075, 0.070)
        let nearLeaf = color(0.050, 0.105, 0.080)
        addRect(x: 0, y: Layout.worldBottom, width: 320, height: 142, color: sky, z: 0)
        drawGeneratedJungleBackdrop()

        for (x, width, height) in [(10, 8, 111), (66, 6, 78), (224, 9, 118), (307, 8, 93)] {
            addRect(
                x: CGFloat(x), y: Layout.worldBottom,
                width: CGFloat(width), height: CGFloat(height),
                color: distantTrunk, z: 1
            )
        }
        addRect(x: 10, y: 153, width: 29, height: 5, color: distantTrunk, z: 1)
        addRect(x: 205, y: 151, width: 28, height: 5, color: distantTrunk, z: 1)
        addRect(x: 289, y: 128, width: 26, height: 5, color: distantTrunk, z: 1)

        let canopy = ["..JJJ...", ".JJJJJ..", "JJJJJJJ.", ".JJJJJJ.", "..JJJ..."]
        for (index, x) in [-10, 22, 58, 96, 136, 176, 216, 302].enumerated() {
            drawPixels(
                canopy,
                palette: ["J": index.isMultiple(of: 2) ? distantLeaf : nearLeaf],
                scale: 4,
                x: CGFloat(x),
                y: CGFloat(176 + (index % 3) * 4),
                z: 2
            )
        }

        addRect(x: 0, y: Layout.worldBottom, width: 320, height: 10, color: distantLeaf, z: 2)
        for index in 0..<24 {
            let x = index * 14 - 8
            let height = 5 + deterministic(index + 150, seed: snapshot.seed, modulo: 13)
            let width = 10 + deterministic(index + 180, seed: snapshot.seed, modulo: 9)
            addRect(
                x: CGFloat(x), y: Layout.worldBottom + 8,
                width: CGFloat(width), height: CGFloat(height),
                color: index.isMultiple(of: 2) ? distantLeaf : nearLeaf,
                z: 3
            )
        }

        drawPixels(
            [
                "...MMM..",
                "..MMMM..",
                ".MMMM...",
                ".MMM....",
                ".MMM....",
                ".MMMM...",
                "..MMMM..",
                "...MMM..",
            ],
            palette: ["M": color(0.82, 0.77, 0.56)],
            scale: 2,
            x: 279,
            y: 174,
            z: 2
        )

    }

    private func drawGeneratedJungleBackdrop() {
        guard
            let url = Bundle.module.url(
                forResource: "canopy-lofi-background",
                withExtension: "png"
            ),
            let image = NSImage(contentsOf: url)
        else { return }

        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        let backdrop = SKSpriteNode(
            texture: texture,
            color: color(0.01, 0.05, 0.07),
            size: CGSize(width: 320, height: 144)
        )
        backdrop.anchorPoint = .zero
        backdrop.position = CGPoint(x: 0, y: Layout.worldBottom)
        backdrop.zPosition = 0.5
        backdrop.alpha = 0.24
        backdrop.colorBlendFactor = 0.42
        addChild(backdrop)
    }

    private func drawAtmosphere(snapshot: CanopyPresentationSnapshot) {
        if atmosphereSeed == snapshot.seed, let atmosphereLayer {
            addChild(atmosphereLayer)
            return
        }

        mistParticles.removeAll(keepingCapacity: true)
        fireflyParticles.removeAll(keepingCapacity: true)
        let layer = SKNode()
        atmosphereLayer = layer
        atmosphereSeed = snapshot.seed
        addChild(layer)

        let mistColor = color(0.28, 0.39, 0.42)
        for index in 0..<3 {
            let mist = SKSpriteNode(
                color: mistColor,
                size: CGSize(
                    width: CGFloat(72 + deterministic(index + 310, seed: snapshot.seed, modulo: 34)),
                    height: CGFloat(3 + deterministic(index + 330, seed: snapshot.seed, modulo: 4))
                )
            )
            mist.anchorPoint = .zero
            mist.position = CGPoint(
                x: CGFloat(deterministic(index + 350, seed: snapshot.seed, modulo: 270) - 18),
                y: CGFloat(78 + deterministic(index + 370, seed: snapshot.seed, modulo: 72))
            )
            mist.alpha = 0.045 + CGFloat(index) * 0.012
            mist.zPosition = 4
            layer.addChild(mist)

            let drift = CGFloat(22 + deterministic(index + 390, seed: snapshot.seed, modulo: 24))
            mistParticles.append(MistParticle(
                node: mist,
                origin: mist.position,
                drift: index.isMultiple(of: 2) ? drift : -drift,
                cycle: TimeInterval(44 + deterministic(index + 410, seed: snapshot.seed, modulo: 30)),
                phase: CGFloat(deterministic(index + 420, seed: snapshot.seed, modulo: 628)) / 100
            ))
        }

        for index in 0..<6 {
            let firefly = SKSpriteNode(
                color: color(0.72, 0.70, 0.34),
                size: CGSize(width: index.isMultiple(of: 3) ? 2 : 1, height: index.isMultiple(of: 3) ? 2 : 1)
            )
            firefly.anchorPoint = .zero
            firefly.position = CGPoint(
                x: CGFloat(18 + deterministic(index + 430, seed: snapshot.seed, modulo: 284)),
                y: CGFloat(74 + deterministic(index + 450, seed: snapshot.seed, modulo: 72))
            )
            firefly.alpha = 0.22 + CGFloat(deterministic(index + 470, seed: snapshot.seed, modulo: 18)) / 100
            firefly.zPosition = 7
            layer.addChild(firefly)

            let driftX = CGFloat(deterministic(index + 530, seed: snapshot.seed, modulo: 9) - 4)
            let driftY = CGFloat(deterministic(index + 550, seed: snapshot.seed, modulo: 7) - 3)
            fireflyParticles.append(FireflyParticle(
                node: firefly,
                origin: firefly.position,
                drift: CGVector(dx: driftX, dy: driftY),
                cycle: TimeInterval(7 + deterministic(index + 510, seed: snapshot.seed, modulo: 6)),
                phase: CGFloat(deterministic(index + 490, seed: snapshot.seed, modulo: 628)) / 100
            ))
        }

        for index in 0..<12 {
            let x = deterministic(index, seed: snapshot.seed, modulo: 300) + 10
            let y = deterministic(index + 40, seed: snapshot.seed, modulo: 105) + 82
            addTwinklingStar(
                index: index,
                seed: snapshot.seed,
                x: CGFloat(x),
                y: CGFloat(y)
            )
        }
    }

    private func addTwinklingStar(index: Int, seed: UInt64, x: CGFloat, y: CGFloat) {
        let star = SKSpriteNode(
            color: color(0.38, 0.58, 0.70),
            size: CGSize(width: 1, height: 1)
        )
        star.anchorPoint = .zero
        star.position = CGPoint(x: x, y: y)
        star.zPosition = 2
        star.alpha = 0.28 + CGFloat(deterministic(index + 80, seed: seed, modulo: 28)) / 100
        (atmosphereLayer ?? self).addChild(star)

        // Fixture captures stay byte-stable; only the live scene twinkles.
        guard !staticEventPose else { return }
        let halfCycle = 1.6 + TimeInterval(deterministic(index + 120, seed: seed, modulo: 18)) / 10
        let delay = TimeInterval(deterministic(index + 160, seed: seed, modulo: 16)) / 10
        let brighten = SKAction.fadeAlpha(to: 0.82, duration: halfCycle)
        brighten.timingMode = .easeInEaseOut
        let dim = SKAction.fadeAlpha(to: 0.24, duration: halfCycle)
        dim.timingMode = .easeInEaseOut
        star.run(.sequence([
            .wait(forDuration: delay),
            .repeatForever(.sequence([brighten, dim])),
        ]))
    }

    private func drawVines(_ vines: [CanopyVine]) {
        let stem = color(0.13, 0.52, 0.24)
        let oldStem = color(0.08, 0.34, 0.17)
        let leaf = color(0.35, 0.70, 0.38)
        let darkLeaf = color(0.17, 0.46, 0.25)

        for vine in vines {
            let steps = max(1, vine.height / 4)
            var previousX = vine.baseX
            for step in 0..<steps {
                let y = Int(Layout.worldBottom) + step * 4
                let x = vineX(vine: vine, step: step)
                let vineColor = step < 5 ? oldStem : stem
                addRect(x: CGFloat(x), y: CGFloat(y), width: 2, height: 5, color: vineColor, z: 8)
                if x != previousX {
                    addRect(
                        x: CGFloat(min(x, previousX)), y: CGFloat(y),
                        width: CGFloat(abs(x - previousX) + 2), height: 2,
                        color: vineColor, z: 8
                    )
                }

                if step > 2, step.isMultiple(of: 4) {
                    let facesRight = deterministic(step, seed: vine.shapeSeed, modulo: 2) == 0
                    let leafX = facesRight ? x + 2 : x - 7
                    drawPixels(
                        facesRight ? [".GG", "GG."] : ["GG.", ".GG"],
                        palette: ["G": step.isMultiple(of: 8) ? leaf : darkLeaf],
                        scale: 2, x: CGFloat(leafX), y: CGFloat(y + 1), z: 9
                    )
                }
                previousX = x
            }

            if vine.hasFlower {
                let uncappedTopY = Int(Layout.worldBottom)
                    + min(vine.height, CanopySimulation.maximumVineHeight) - 3
                let topY = min(uncappedTopY, Int(size.height) - 6)
                let topX = vineX(vine: vine, step: max(0, steps - 1))
                drawPixels(
                    [".R.", "RWR", ".R."],
                    palette: ["R": color(0.95, 0.10, 0.18), "W": color(1.00, 0.70, 0.12)],
                    scale: 2, x: CGFloat(topX - 2), y: CGFloat(topY), z: 12
                )
            }
        }
    }

    private func vineX(vine: CanopyVine, step: Int) -> Int {
        var x = vine.baseX
        for index in 0...step {
            x += deterministic(index, seed: vine.shapeSeed, modulo: 3) - 1
        }
        return min(316, max(3, x))
    }

    private func drawEvent(_ event: CanopyVisualEvent?, snapshot: CanopyPresentationSnapshot) {
        guard let event else { return }
        switch event {
        case .rain:
            for index in 0..<24 {
                let x = deterministic(index, seed: snapshot.seed ^ UInt64(snapshot.tick), modulo: 314) + 3
                let y = deterministic(index + 90, seed: snapshot.seed, modulo: 132) + 63
                addRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 6, color: color(0.15, 0.65, 0.90), z: 20)
            }
        case .bloom(let vineID):
            guard let vine = snapshot.vines.first(where: { $0.id == vineID }) else { return }
            let y = Int(Layout.worldBottom) + min(vine.height, CanopySimulation.maximumVineHeight) - 5
            let x = vineX(vine: vine, step: max(0, vine.height / 4 - 1))
            for offset in [-9, 9] {
                addRect(x: CGFloat(x + offset), y: CGFloat(y + 2), width: 4, height: 2, color: color(1.00, 0.46, 0.10), z: 21)
            }
        case .bird:
            drawPixels(
                ["..BB....", ".BBBBB..", "BBBBBBBB", "..B..B.."],
                palette: ["B": color(0.10, 0.78, 0.92)],
                scale: 2, x: 202, y: 149, z: 22
            )
        case .swing(let outcome):
            drawSwing(outcome, staticPose: staticEventPose)
        case .pruned:
            drawPixels(
                ["K...K", ".K.K.", "..K..", ".K.K.", "K...K"],
                palette: ["K": color(0.96, 0.70, 0.10)],
                scale: 3, x: 145, y: 113, z: 22
            )
        }
    }

    private func drawSwing(_ outcome: CanopySwingOutcome, staticPose: Bool) {
        let direction: CanopySide = switch outcome {
        case .clean(let direction): direction
        case .wallImpact(let side): side
        }
        let node = swingSprite(for: outcome)
        node.zPosition = 30
        addChild(node)

        if case .wallImpact(let side) = outcome {
            drawPixels(
                ["Y.Y", ".Y.", "Y.Y"],
                palette: ["Y": color(1.00, 0.72, 0.08)],
                scale: 2,
                x: side == .right ? 303 : 11,
                y: 120,
                z: 31
            )
        }

        let startX: CGFloat = direction == .right ? -24 : 344
        let endX: CGFloat = direction == .right ? 344 : -24
        if staticPose {
            switch outcome {
            case .clean:
                node.position = CGPoint(x: 160, y: 125)
            case .wallImpact(let side):
                node.position = CGPoint(x: side == .right ? 280 : 40, y: 121)
                node.zRotation = side == .right ? -.pi / 9 : .pi / 9
            }
            return
        }

        node.position = CGPoint(x: startX, y: 116)
        let destination: CGPoint
        let duration: TimeInterval
        switch outcome {
        case .clean:
            destination = CGPoint(x: endX, y: 116)
            duration = SwingTiming.arcSegment * 4
        case .wallImpact(let side):
            let wallX: CGFloat = side == .right ? 280 : 40
            destination = CGPoint(x: wallX, y: 121)
            duration = SwingTiming.arcSegment * 3
        }

        var actions: [SKAction] = [swingArcAction(
            from: CGPoint(x: startX, y: 116),
            to: destination,
            controlY: 190,
            duration: duration
        )]
        if case .wallImpact(let side) = outcome {
            actions.append(.rotate(
                toAngle: side == .right ? -.pi / 9 : .pi / 9,
                duration: SwingTiming.impactTurn
            ))
            actions.append(.wait(forDuration: SwingTiming.impactPause))
            let fallFrames = fallAnimationTextures
            if let fall = makeFallSprite(for: side) {
                fall.isHidden = true
                node.addChild(fall)
                actions.append(.run { [weak node, weak fall] in
                    guard let node, let fall else { return }
                    for child in node.children where child !== fall {
                        child.isHidden = true
                    }
                    node.zRotation = 0
                    fall.isHidden = false
                    fall.run(.animate(
                        with: fallFrames,
                        timePerFrame: SwingTiming.impactSlide / TimeInterval(fallFrames.count),
                        resize: false,
                        restore: false
                    ))
                })
            }
            actions.append(.moveBy(x: 0, y: -52, duration: SwingTiming.impactSlide))
        }
        node.run(.sequence(actions))
    }

    private func makeFallSprite(for side: CanopySide) -> SKSpriteNode? {
        guard let first = fallAnimationTextures.first else { return nil }
        let sprite = SKSpriteNode(texture: first, size: CGSize(width: 64, height: 64))
        sprite.position = CGPoint(x: 0, y: 29)
        sprite.xScale = side == .right ? 1 : -1
        return sprite
    }

    private func loadFallTextures() -> [SKTexture] {
        guard
            let url = Bundle.module.url(
                forResource: "canopy-wanderer-fall-sheet",
                withExtension: "png"
            ),
            let image = NSImage(contentsOf: url)
        else { return [] }

        let sheet = SKTexture(image: image)
        sheet.filteringMode = .nearest
        return (0..<8).map { index in
            let column = index % 4
            let rowFromTop = index / 4
            let texture = SKTexture(
                rect: CGRect(
                    x: CGFloat(column) / 4,
                    y: rowFromTop == 0 ? 0.5 : 0,
                    width: 0.25,
                    height: 0.5
                ),
                in: sheet
            )
            texture.filteringMode = .nearest
            return texture
        }
    }

    private func swingArcAction(
        from start: CGPoint,
        to end: CGPoint,
        controlY: CGFloat,
        duration: TimeInterval
    ) -> SKAction {
        let direction: CGFloat = end.x >= start.x ? 1 : -1
        return SKAction.customAction(withDuration: duration) { node, elapsedTime in
            let progress = min(1, max(0, elapsedTime / CGFloat(duration)))
            // A cosine ease mimics a pendulum: lingering at the ends and moving fastest mid-swing.
            let eased = (1 - cos(.pi * progress)) / 2
            let inverse = 1 - eased
            node.position = CGPoint(
                x: start.x + (end.x - start.x) * eased,
                y: inverse * inverse * start.y
                    + 2 * inverse * eased * controlY
                    + eased * eased * end.y
            )
            node.zRotation = -direction * sin(.pi * progress) * 0.045
        }
    }

    private func swingSprite(for outcome: CanopySwingOutcome) -> SKNode {
        let node = SKNode()
        for step in 0..<12 {
            let rope = SKSpriteNode(color: color(0.50, 0.29, 0.08), size: CGSize(width: 2, height: 4))
            rope.anchorPoint = .zero
            rope.position = CGPoint(x: CGFloat(step / 4), y: CGFloat(29 + step * 4))
            node.addChild(rope)
        }

        let direction: CanopySide
        let rows: [String]
        switch outcome {
        case .clean(let swingDirection):
            direction = swingDirection
            rows = [
                "..S.HHH..",
                "..S.HSH..",
                "..SSSS...",
                "...TTT...",
                ".S.TTTS..",
                "...TT....",
                "..L..L...",
                ".LL...L..",
                "LL....LL.",
            ]
        case .wallImpact(let side):
            direction = side
            rows = [
                "..S.HHH..",
                "..S.HSH..",
                "..SSSS.S.",
                "...TTTSS.",
                "...TTT...",
                "..LTT....",
                ".LL..L...",
                "L...LL...",
                "....L....",
            ]
        }
        let person = pixelNode(
            rows: rows,
            palette: [
                "H": color(0.12, 0.055, 0.025),
                "S": color(0.94, 0.48, 0.16),
                "T": color(0.94, 0.68, 0.12),
                "L": color(0.29, 0.11, 0.035),
            ],
            scale: 3
        )
        person.position = CGPoint(x: direction == .right ? -6 : 21, y: 2)
        person.xScale = direction == .right ? 1 : -1
        node.addChild(person)
        return node
    }

    private func drawPanel(_ snapshot: CanopyPresentationSnapshot) {
        addRect(x: 0, y: 0, width: 320, height: Layout.panelTop, color: .black, z: 50)
        addRect(x: 0, y: Layout.panelTop, width: 320, height: 16, color: color(0.07, 0.10, 0.085), z: 50)
        let green = color(0.38, 0.72, 0.46)
        let paper = color(0.82, 0.83, 0.76)
        addLabel("GROWTH \(snapshot.density)%  VINES \(snapshot.vines.count)  SWINGS \(snapshot.swingCount)", y: 27, color: green, size: 8.5)
        addLabel("SEED 0X\(String(snapshot.seed, radix: 16, uppercase: true))  TICK \(snapshot.tick)", y: 12, color: green, size: 8.5)
        addLabel(fitted(snapshot.message), y: 48, color: paper, size: 7.5)
    }

    private func fitted(_ message: String) -> String {
        let text = message.isEmpty ? "THE JUNGLE WAITS FOR GREEN." : message
        if text.count <= 54 { return text }
        return String(text.prefix(51)).trimmingCharacters(in: .whitespaces) + "..."
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

    private func pixelNode(
        rows: [String],
        palette: [Character: NSColor],
        scale: CGFloat
    ) -> SKNode {
        let node = SKNode()
        for (rowIndex, row) in rows.enumerated() {
            for (column, character) in row.enumerated() {
                guard let pixelColor = palette[character] else { continue }
                let pixel = SKSpriteNode(color: pixelColor, size: CGSize(width: scale, height: scale))
                pixel.anchorPoint = .zero
                pixel.position = CGPoint(
                    x: CGFloat(column) * scale,
                    y: CGFloat(rows.count - rowIndex - 1) * scale
                )
                node.addChild(pixel)
            }
        }
        return node
    }

    private func drawPixels(
        _ rows: [String],
        palette: [Character: NSColor],
        scale: CGFloat,
        x: CGFloat,
        y: CGFloat,
        z: CGFloat
    ) {
        let node = pixelNode(rows: rows, palette: palette, scale: scale)
        node.position = CGPoint(x: x, y: y)
        node.zPosition = z
        addChild(node)
    }

    private func deterministic(_ index: Int, seed: UInt64, modulo: Int) -> Int {
        var value = seed &+ UInt64(index &* 1_009)
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return Int((value ^ (value >> 31)) % UInt64(modulo))
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
