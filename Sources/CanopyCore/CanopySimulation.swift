private struct CanopyRNG: Equatable, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        precondition(range.lowerBound <= range.upperBound)
        let width = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % width)
    }

    mutating func chance(_ numerator: Int, outOf denominator: Int = 100) -> Bool {
        int(in: 1...denominator) <= numerator
    }
}

public struct CanopySimulation: Equatable, Sendable {
    public static let maximumVineHeight = 142
    public static let maximumVines = 9
    public static let eventLogLimit = 64

    public private(set) var state: CanopyState

    private var growthRNG: CanopyRNG
    private var eventRNG: CanopyRNG
    private var nextVineID: Int
    private var nextSwingTick: Int

    public init(seed: UInt64) {
        var initialRNG = CanopyRNG(seed: seed ^ 0x4341_4E4F_5059)
        let bases = [42, 158, 276]
        let vines = bases.enumerated().map { index, x in
            CanopyVine(
                id: index,
                baseX: x + initialRNG.int(in: -8...8),
                height: initialRNG.int(in: 5...11),
                shapeSeed: initialRNG.next()
            )
        }
        state = CanopyState(seed: seed, vines: vines)
        growthRNG = CanopyRNG(seed: seed ^ 0x4752_4F57_5448)
        eventRNG = CanopyRNG(seed: seed ^ 0x5357_494E_4745_52)
        nextVineID = vines.count
        nextSwingTick = 9 + initialRNG.int(in: 0...4)
    }

    public var seed: UInt64 { state.seed }
    public var tickCount: Int { state.tick }
    public var vines: [CanopyVine] { state.vines }
    public var swingCount: Int { state.swingCount }
    public var latestVisualEvent: CanopyVisualEvent? { state.latestVisualEvent }
    public var eventLog: [String] { state.eventLog }

    public var density: Int {
        let totalHeight = state.vines.reduce(0) { $0 + $1.height }
        let capacity = Self.maximumVines * Self.maximumVineHeight
        return min(100, totalHeight * 100 / capacity)
    }

    @discardableResult
    public mutating func tick() -> [String] {
        state.tick += 1
        state.latestVisualEvent = nil
        var messages: [String] = []

        growVines()
        sproutVineIfNeeded(messages: &messages)
        bloomIfNeeded(messages: &messages)

        if state.tick >= nextSwingTick {
            performSwing(messages: &messages)
            nextSwingTick = state.tick + eventRNG.int(in: 9...14)
        } else if eventRNG.chance(5) {
            applyRain(messages: &messages)
        } else if eventRNG.chance(4) {
            state.latestVisualEvent = .bird
            messages.append("A bright bird pauses among the new leaves.")
        }

        if messages.isEmpty {
            messages.append("The vines climb another little way.")
        }
        record(messages)
        return messages
    }

    @discardableResult
    public mutating func prune() -> String {
        for index in state.vines.indices {
            state.vines[index].height = max(8, state.vines[index].height / 3)
            state.vines[index].hasFlower = false
        }
        state.latestVisualEvent = .pruned
        let message = "The oldest growth is pruned back to make room for new vines."
        record([message])
        return message
    }

    private mutating func growVines() {
        guard !state.vines.isEmpty else { return }
        let growthPasses = min(3, state.vines.count)
        for _ in 0..<growthPasses {
            let index = growthRNG.int(in: 0...(state.vines.count - 1))
            let growth = growthRNG.int(in: 2...6)
            state.vines[index].height = min(
                Self.maximumVineHeight,
                state.vines[index].height + growth
            )
        }
    }

    private mutating func sproutVineIfNeeded(messages: inout [String]) {
        guard state.vines.count < Self.maximumVines,
              state.tick.isMultiple(of: 8),
              growthRNG.chance(62) else { return }

        var baseX = growthRNG.int(in: 18...302)
        for _ in 0..<8 where state.vines.contains(where: { abs($0.baseX - baseX) < 18 }) {
            baseX = growthRNG.int(in: 18...302)
        }
        let vine = CanopyVine(
            id: nextVineID,
            baseX: baseX,
            height: growthRNG.int(in: 5...10),
            shapeSeed: growthRNG.next()
        )
        nextVineID += 1
        state.vines.append(vine)
        messages.append("A new vine catches a trunk and begins to climb.")
    }

    private mutating func bloomIfNeeded(messages: inout [String]) {
        let candidates = state.vines.indices.filter {
            state.vines[$0].height >= 72 && !state.vines[$0].hasFlower
        }
        guard let index = candidates.first, eventRNG.chance(28) else { return }
        state.vines[index].hasFlower = true
        state.latestVisualEvent = .bloom(vineID: state.vines[index].id)
        messages.append("A red flower opens high on a vine.")
    }

    private mutating func performSwing(messages: inout [String]) {
        state.swingCount += 1
        let direction: CanopySide = state.swingCount.isMultiple(of: 2) ? .left : .right
        let collisionOffset = Int(state.seed % 4)
        let collision = (state.swingCount + collisionOffset).isMultiple(of: 4)
        let outcome: CanopySwingOutcome
        if collision {
            outcome = .wallImpact(side: direction)
            messages.append("The canopy wanderer clips the \(direction.rawValue) edge and slides down.")
        } else {
            outcome = .clean(direction: direction)
            messages.append("A wild whoop crosses the canopy as the wanderer swings past.")
        }
        state.latestVisualEvent = .swing(outcome)
    }

    private mutating func applyRain(messages: inout [String]) {
        for index in state.vines.indices {
            state.vines[index].height = min(
                Self.maximumVineHeight,
                state.vines[index].height + 2
            )
        }
        state.latestVisualEvent = .rain
        messages.append("Warm rain sends fresh green growth toward the canopy.")
    }

    private mutating func record(_ messages: [String]) {
        state.eventLog.append(contentsOf: messages)
        let excess = state.eventLog.count - Self.eventLogLimit
        if excess > 0 {
            state.eventLog.removeFirst(excess)
        }
    }
}
