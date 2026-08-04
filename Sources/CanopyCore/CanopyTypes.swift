public enum CanopySide: String, Equatable, Sendable {
    case left
    case right
}

public enum CanopySwingOutcome: Equatable, Sendable {
    case clean(direction: CanopySide)
    case wallImpact(side: CanopySide)
}

public enum CanopyVisualEvent: Equatable, Sendable {
    case rain
    case bloom(vineID: Int)
    case bird
    case swing(CanopySwingOutcome)
    case pruned
}

public struct CanopyVine: Equatable, Sendable, Identifiable {
    public let id: Int
    public let baseX: Int
    public var height: Int
    public let shapeSeed: UInt64
    public var hasFlower: Bool

    public init(
        id: Int,
        baseX: Int,
        height: Int,
        shapeSeed: UInt64,
        hasFlower: Bool = false
    ) {
        self.id = id
        self.baseX = baseX
        self.height = height
        self.shapeSeed = shapeSeed
        self.hasFlower = hasFlower
    }
}

public struct CanopyState: Equatable, Sendable {
    public let seed: UInt64
    public var tick: Int
    public var vines: [CanopyVine]
    public var swingCount: Int
    public var latestVisualEvent: CanopyVisualEvent?
    public var eventLog: [String]

    public init(seed: UInt64, vines: [CanopyVine]) {
        self.seed = seed
        self.tick = 0
        self.vines = vines
        self.swingCount = 0
        self.latestVisualEvent = nil
        self.eventLog = []
    }
}
