public enum FarmSeason: String, CaseIterable, Equatable, Sendable {
    case spring
    case summer
    case autumn
    case winter
}

public enum FarmWeather: String, CaseIterable, Equatable, Sendable {
    case gentleRain
    case clear
    case warmSun
    case drySpell
    case lateFrost
    case wind
    case snow
    case thaw
}

public enum CropStage: String, CaseIterable, Equatable, Sendable {
    case bare
    case sown
    case sprouting
    case growing
    case mature
    case harvested
    case resting
}

public enum FarmPlan: String, CaseIterable, Equatable, Sendable {
    case wheat
    case beans
    case fallow
}

/// A short-lived, typed presentation cue for the most important event on a
/// weekly tick. The simulation owns the meaning; renderers decide how it looks.
public enum FarmVisualEvent: Equatable, Sendable {
    case weeds
    case crows
    case deer
    case neighborProvisions(food: Int)
    case windDamage
    case repairDay(points: Int)
    case harvest(plan: FarmPlan, totalYield: Int)
    case yearEnd(outcome: FarmOutcome, paid: Int)
}

public struct HarvestReport: Equatable, Sendable {
    public let plan: FarmPlan
    public let baseYield: Int
    public let growthContribution: Int
    public let soilContribution: Int
    public let moistureContribution: Int
    public let damagePenalty: Int
    public let totalYield: Int
    public let foodGained: Int
    public let cashGained: Int
    public let soilChange: Int
    public let summary: String

    public init(
        plan: FarmPlan,
        baseYield: Int,
        growthContribution: Int,
        soilContribution: Int,
        moistureContribution: Int,
        damagePenalty: Int,
        totalYield: Int,
        foodGained: Int,
        cashGained: Int,
        soilChange: Int,
        summary: String
    ) {
        self.plan = plan
        self.baseYield = baseYield
        self.growthContribution = growthContribution
        self.soilContribution = soilContribution
        self.moistureContribution = moistureContribution
        self.damagePenalty = damagePenalty
        self.totalYield = totalYield
        self.foodGained = foodGained
        self.cashGained = cashGained
        self.soilChange = soilChange
        self.summary = summary
    }
}

public enum FarmOutcome: String, CaseIterable, Equatable, Sendable {
    case stable
    case strained
    case debt
}

public struct FarmState: Equatable, Sendable {
    public let seed: UInt64
    public let plan: FarmPlan
    public var week: Int
    public var season: FarmSeason
    public var weekOfSeason: Int
    public var soilQuality: Int
    public var moisture: Int
    public var storedFood: Int
    public var cash: Int
    public var buildingCondition: Int
    public var cropGrowth: Int
    public var cropStage: CropStage
    public var currentWeather: FarmWeather?
    public var latestVisualEvent: FarmVisualEvent?
    public var eventLog: [String]
    public var harvestReport: HarvestReport?
    public var outcome: FarmOutcome?
    public var isFinished: Bool

    public init(seed: UInt64, plan: FarmPlan) {
        self.seed = seed
        self.plan = plan
        self.week = 0
        self.season = .spring
        self.weekOfSeason = 0
        self.soilQuality = 60
        self.moisture = 55
        self.storedFood = 42
        self.cash = 28
        self.buildingCondition = 82
        self.cropGrowth = 0
        self.cropStage = .bare
        self.currentWeather = nil
        self.latestVisualEvent = nil
        self.eventLog = []
        self.harvestReport = nil
        self.outcome = nil
        self.isFinished = false
    }
}
