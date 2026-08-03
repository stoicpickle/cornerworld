private struct FarmRNG: Equatable, Sendable {
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

public struct FarmSimulation: Equatable, Sendable {
    public private(set) var state: FarmState

    private var weatherRNG: FarmRNG
    private var eventRNG: FarmRNG
    private var weatherDamage = 0
    private var hardship = 0

    public init(seed: UInt64, plan: FarmPlan) {
        self.state = FarmState(seed: seed, plan: plan)
        self.weatherRNG = FarmRNG(seed: seed)
        self.eventRNG = FarmRNG(seed: seed ^ 0x4641_524D_4556_4E54)
    }

    public var seed: UInt64 { state.seed }
    public var plan: FarmPlan { state.plan }
    public var week: Int { state.week }
    public var season: FarmSeason { state.season }
    public var weekOfSeason: Int { state.weekOfSeason }
    public var soilQuality: Int { state.soilQuality }
    public var moisture: Int { state.moisture }
    public var storedFood: Int { state.storedFood }
    public var cash: Int { state.cash }
    public var buildingCondition: Int { state.buildingCondition }
    public var cropGrowth: Int { state.cropGrowth }
    public var cropStage: CropStage { state.cropStage }
    public var currentWeather: FarmWeather? { state.currentWeather }
    public var latestVisualEvent: FarmVisualEvent? { state.latestVisualEvent }
    public var eventLog: [String] { state.eventLog }
    public var harvestReport: HarvestReport? { state.harvestReport }
    public var outcome: FarmOutcome? { state.outcome }
    public var isFinished: Bool { state.isFinished }

    @discardableResult
    public mutating func tick() -> [String] {
        guard !state.isFinished else { return [] }

        state.latestVisualEvent = nil

        state.week += 1
        state.season = Self.season(for: state.week)
        state.weekOfSeason = ((state.week - 1) % 13) + 1

        let weather = drawWeather(for: state.season)
        state.currentWeather = weather
        var messages = [
            "Week \(state.week) — \(state.season.displayName): \(weather.description)."
        ]

        apply(weather: weather, messages: &messages)
        applyFieldGrowth(weather: weather)
        applyAuthoredEvent(messages: &messages)

        if state.season == .autumn, state.weekOfSeason == 7, state.harvestReport == nil {
            harvest(messages: &messages)
        }

        if state.season == .winter {
            applyWinterPressure(weather: weather, messages: &messages)
        }

        updateCropStage()
        clampResources()

        if state.week == 52 {
            finishYear(messages: &messages)
        }

        state.eventLog.append(contentsOf: messages)
        return messages
    }

    private static func season(for week: Int) -> FarmSeason {
        switch (week - 1) / 13 {
        case 0: .spring
        case 1: .summer
        case 2: .autumn
        default: .winter
        }
    }

    private mutating func drawWeather(for season: FarmSeason) -> FarmWeather {
        let roll = weatherRNG.int(in: 1...100)
        switch season {
        case .spring:
            switch roll {
            case 1...32: return .gentleRain
            case 33...56: return .clear
            case 57...71: return .warmSun
            case 72...81: return .drySpell
            case 82...91: return .lateFrost
            default: return .wind
            }
        case .summer:
            switch roll {
            case 1...16: return .gentleRain
            case 17...37: return .clear
            case 38...65: return .warmSun
            case 66...90: return .drySpell
            default: return .wind
            }
        case .autumn:
            switch roll {
            case 1...24: return .gentleRain
            case 25...54: return .clear
            case 55...64: return .warmSun
            case 65...74: return .drySpell
            case 75...96: return .wind
            default: return .lateFrost
            }
        case .winter:
            switch roll {
            case 1...36: return .snow
            case 37...56: return .clear
            case 57...74: return .wind
            case 75...90: return .thaw
            default: return .lateFrost
            }
        }
    }

    private mutating func apply(weather: FarmWeather, messages: inout [String]) {
        switch weather {
        case .gentleRain:
            state.moisture += 14
        case .clear:
            state.moisture -= 4
        case .warmSun:
            state.moisture -= 8
        case .drySpell:
            state.moisture -= 13
            if state.season == .summer {
                weatherDamage += 2
            }
        case .lateFrost:
            state.moisture += 2
            if state.season == .spring, state.plan != .fallow {
                weatherDamage += 3
                state.cropGrowth -= 2
                messages.append("Late frost silvered the young field and slowed its growth.")
            }
        case .wind:
            state.moisture -= 6
            if state.season == .autumn, state.harvestReport == nil, state.plan != .fallow {
                weatherDamage += 2
            }
        case .snow:
            state.moisture += 7
        case .thaw:
            state.moisture += 10
        }
    }

    private mutating func applyFieldGrowth(weather: FarmWeather) {
        guard state.plan != .fallow else {
            if state.season == .spring || state.season == .summer, state.weekOfSeason.isMultiple(of: 2) {
                state.soilQuality += 1
            }
            return
        }
        guard state.harvestReport == nil, state.season != .winter else { return }

        var growth = state.plan == .wheat ? 3 : 2
        if state.season == .summer { growth += 2 }
        if (35...75).contains(state.moisture) { growth += 2 }
        if state.moisture < 20 || state.moisture > 85 { growth -= 1 }
        if weather == .warmSun { growth += 1 }
        if weather == .drySpell || weather == .lateFrost { growth -= 1 }
        state.cropGrowth += max(0, growth)
    }

    private mutating func applyAuthoredEvent(messages: inout [String]) {
        if (state.season == .spring || state.season == .summer),
           state.plan != .fallow,
           eventRNG.chance(8) {
            state.cropGrowth -= 3
            weatherDamage += 1
            state.latestVisualEvent = .weeds
            messages.append("Weeds crowded a row before they could be cut back.")
        }

        if (state.season == .spring || state.season == .summer),
           state.plan != .fallow,
           eventRNG.chance(5) {
            state.cropGrowth -= 2
            weatherDamage += 1
            state.latestVisualEvent = .crows
            messages.append("Crows dropped into the field and pulled at the young crop.")
        }

        if state.season == .summer, eventRNG.chance(7) {
            state.latestVisualEvent = .deer
            messages.append("Deer watched from the field edge, then slipped into the trees.")
        }

        if state.season == .spring, state.weekOfSeason == 8, eventRNG.chance(55) {
            let food = 4
            state.storedFood += food
            state.latestVisualEvent = .neighborProvisions(food: food)
            messages.append("A neighbor left a basket with \(food) food for the household.")
        }

        if state.season == .autumn, state.weekOfSeason < 7, eventRNG.chance(6) {
            state.cropGrowth -= 2
            weatherDamage += 1
            state.latestVisualEvent = .windDamage
            messages.append("A hard wind bent the outer rows.")
        }

        if state.season == .winter, state.weekOfSeason == 5, eventRNG.chance(45) {
            let repair = min(7, 100 - state.buildingCondition)
            let cost = 2
            if repair > 0, state.cash >= cost {
                state.buildingCondition += repair
                state.cash -= cost
                state.latestVisualEvent = .repairDay(points: repair)
                messages.append("A clear repair day restored \(repair) points of building condition for $\(cost).")
            }
        }
    }

    private mutating func harvest(messages: inout [String]) {
        let base: Int
        switch state.plan {
        case .wheat: base = 18
        case .beans: base = 11
        case .fallow: base = 0
        }

        let growth = state.plan == .fallow ? 0 : state.cropGrowth / 5
        let soil = state.plan == .fallow ? 0 : state.soilQuality / 10
        let moisture = state.plan == .fallow ? 0 : max(0, 10 - abs(state.moisture - 55) / 6)
        let damage = state.plan == .fallow ? 0 : weatherDamage
        let rawTotal = base + growth + soil + moisture - damage
        let total = max(0, rawTotal)

        let food: Int
        let cash: Int
        let soilChange: Int
        switch state.plan {
        case .wheat:
            food = total / 2
            cash = total * 2
            soilChange = -14
        case .beans:
            food = total
            cash = total + total / 2
            soilChange = 8
        case .fallow:
            food = 0
            cash = 0
            soilChange = 18
        }

        state.storedFood += food
        state.cash += cash
        state.soilQuality += soilChange
        let summary = "Harvest \(total) = max(0, base \(base) + growth \(growth) + soil \(soil) + moisture \(moisture) - damage \(damage)); +\(food) food, +$\(cash), soil \(soilChange >= 0 ? "+" : "")\(soilChange)."
        state.harvestReport = HarvestReport(
            plan: state.plan,
            baseYield: base,
            growthContribution: growth,
            soilContribution: soil,
            moistureContribution: moisture,
            damagePenalty: damage,
            totalYield: total,
            foodGained: food,
            cashGained: cash,
            soilChange: soilChange,
            summary: summary
        )
        state.latestVisualEvent = .harvest(plan: state.plan, totalYield: total)
        messages.append(summary)
    }

    private mutating func applyWinterPressure(weather: FarmWeather, messages: inout [String]) {
        let weeklyNeed = 2
        if state.storedFood >= weeklyNeed {
            state.storedFood -= weeklyNeed
        } else {
            let missing = weeklyNeed - state.storedFood
            state.storedFood = 0
            let paid = min(missing * 2, state.cash)
            state.cash -= paid
            hardship += missing
            messages.append("Thin stores forced the farm to spend $\(paid) on food.")
        }

        switch weather {
        case .snow:
            if state.weekOfSeason.isMultiple(of: 2) { state.buildingCondition -= 1 }
        case .wind:
            state.buildingCondition -= 2
        case .thaw:
            if state.weekOfSeason.isMultiple(of: 3) { state.buildingCondition -= 1 }
        default:
            break
        }
    }

    private mutating func updateCropStage() {
        if state.season == .winter {
            state.cropStage = .resting
            return
        }
        if state.plan == .fallow {
            state.cropStage = state.season == .autumn ? .resting : .bare
            return
        }
        if state.harvestReport != nil {
            state.cropStage = .harvested
            return
        }
        switch state.cropGrowth {
        case ..<8: state.cropStage = .sown
        case 8..<30: state.cropStage = .sprouting
        case 30..<70: state.cropStage = .growing
        default: state.cropStage = .mature
        }
    }

    private mutating func finishYear(messages: inout [String]) {
        let annualCosts = 28
        let paid = min(annualCosts, state.cash)
        state.cash -= paid
        messages.append("Year-end taxes and provisions cost $\(paid) of $\(annualCosts) owed.")

        let result: FarmOutcome
        if state.storedFood == 0 || state.cash == 0 || state.buildingCondition < 30 || hardship >= 6 {
            result = .debt
        } else if state.storedFood < 30 || state.cash < 40 || state.buildingCondition < 65 || hardship > 0 {
            result = .strained
        } else {
            result = .stable
        }
        state.outcome = result
        state.isFinished = true
        state.latestVisualEvent = .yearEnd(outcome: result, paid: paid)
        messages.append("The farm ends the year \(result.rawValue): \(state.storedFood) food, $\(state.cash), buildings \(state.buildingCondition).")
    }

    private mutating func clampResources() {
        state.soilQuality = min(100, max(0, state.soilQuality))
        state.moisture = min(100, max(0, state.moisture))
        state.buildingCondition = min(100, max(0, state.buildingCondition))
        state.cropGrowth = min(100, max(0, state.cropGrowth))
        state.storedFood = max(0, state.storedFood)
        state.cash = max(0, state.cash)
    }
}

private extension FarmSeason {
    var displayName: String {
        switch self {
        case .spring: "Spring"
        case .summer: "Summer"
        case .autumn: "Autumn"
        case .winter: "Winter"
        }
    }
}

private extension FarmWeather {
    var description: String {
        switch self {
        case .gentleRain: "Gentle rain settles over the field"
        case .clear: "The sky stays clear"
        case .warmSun: "Warm sun draws the crop upward"
        case .drySpell: "A dry spell pulls moisture from the soil"
        case .lateFrost: "Late frost reaches the low ground"
        case .wind: "Wind presses across the farm"
        case .snow: "Snow gathers against the fence"
        case .thaw: "A thaw darkens the winter ground"
        }
    }
}
