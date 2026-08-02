public final class Simulation {
    enum DailyEventKind: Equatable {
        case illness(Ailment)
        case hunt
        case trailOpportunity
        case oxenWolves
        case wagonBreakdown
        case snakeBite
        case findSpring
        case regionalTrade
        case weatherTurnsBad
        case passiveVignette
        case quiet
    }

    public let seed: UInt64
    public private(set) var party: Party

    public private(set) var supplies: Supplies
    public private(set) var milesTraveled: Int = 0
    public private(set) var day: Int = 0

    public var ration: Ration = .filling
    public var pace: Pace = .moderate

    public private(set) var currentWeather: Weather = Weather(kind: .clear, speedFactor: 1.0)
    public private(set) var eventLog: [String] = []
    public private(set) var isFinished: Bool = false
    public private(set) var outcome: Outcome?

    private var rng: SplitMix64
    private var month: Int = 4
    private var year: Int = 1848
    private var dayOfMonth: Int = 1
    private var crossedLandmarks: Set<String> = []
    private var weatherFrontDaysRemaining = 0
    private var latestDeathCause: String?

    public enum Outcome: Equatable {
        case reachedOregon
        case partyPerished(cause: String)
    }

    public init(seed: UInt64, party: Party? = nil) {
        self.seed = seed
        self.party = party ?? .defaultParty()
        self.supplies = Supplies()
        self.rng = SplitMix64(seed: seed)
        self.latestDeathCause = self.party.members.last(where: { !$0.isAlive })?.causeOfDeath
    }

    /// Internal state injection keeps deterministic edge-case tests focused without
    /// widening the public simulation API into a save/restore API.
    init(seed: UInt64, party: Party? = nil, supplies: Supplies, milesTraveled: Int = 0) {
        precondition((0...Trail.totalMiles).contains(milesTraveled))
        self.seed = seed
        self.party = party ?? .defaultParty()
        self.supplies = supplies
        self.milesTraveled = milesTraveled
        self.rng = SplitMix64(seed: seed)
        self.latestDeathCause = self.party.members.last(where: { !$0.isAlive })?.causeOfDeath
    }

    public var dateString: String {
        let monthName = ["January", "February", "March", "April", "May", "June", "July",
                         "August", "September", "October", "November", "December"][month - 1]
        return "\(monthName) \(dayOfMonth), \(year)"
    }

    public var currentLandmark: Landmark? {
        Trail.landmark(at: milesTraveled)
    }

    public var distanceRemaining: Int {
        max(0, Trail.totalMiles - milesTraveled)
    }

    public var isPartyHealthy: Bool {
        party.aliveCount > 0 && party.averageHealth > 50
    }

    public var memorials: [String] {
        party.members.compactMap { member in
            guard !member.isAlive else { return nil }
            return "\(member.name) — \(member.causeOfDeath ?? "the wilderness")"
        }
    }

    var weatherFrontDaysRemainingForTesting: Int { weatherFrontDaysRemaining }

    // MARK: - Tick

    @discardableResult
    public func tick() -> [String] {
        guard !isFinished else { return [] }
        day += 1
        advanceCalendar()
        var log: [String] = []

        advanceWeatherFront()

        let previousMiles = milesTraveled
        let milesToday = travelDistance()
        milesTraveled = min(Trail.totalMiles, previousMiles + milesToday)
        let travelEndMiles = milesTraveled

        if supplies.oxen == 0, party.aliveCount > 0 {
            log.append("You have no oxen. The wagon cannot move.")
        }

        consumeFood(&log)
        applyHealthDecay(&log)
        checkLandmarksCrossed(from: previousMiles, through: travelEndMiles, log: &log)
        rollEvent(&log)
        checkEndConditions(&log)

        eventLog.append(contentsOf: log)
        return log
    }

    // MARK: - Movement

    private func travelDistance() -> Int {
        guard party.aliveCount > 0, supplies.oxen > 0 else { return 0 }

        let terrain = Trail.terrain(at: milesTraveled)
        let base: Int
        switch terrain {
        case .prairie: base = 14
        case .plains: base = 16
        case .river: base = 12
        case .mountains: base = 9
        }

        var miles = Double(base + pace.milesPerDayBonus) * currentWeather.speedFactor

        let healthRatio = party.aliveCount > 0 ? party.averageHealth / 100.0 : 0
        miles *= (0.6 + 0.4 * healthRatio)

        let oxenFactor = min(1.0, Double(supplies.oxen) / 5.0)
        if oxenFactor < 1.0 {
            miles *= (0.5 + 0.5 * oxenFactor)
        }

        return max(0, Int(miles.rounded()))
    }

    // MARK: - Food

    private func consumeFood(_ log: inout [String]) {
        guard party.aliveCount > 0 else { return }
        let perPerson = ration.poundsPerPersonPerDay
        let needed = perPerson * party.aliveCount
        supplies.foodPounds -= needed
        if supplies.foodPounds <= 0 {
            supplies.foodPounds = 0
            log.append("The food is gone. The wagons roll on empty stomachs.")
        } else if supplies.foodPounds < 200 {
            log.append("Supplies run thin. Only \(supplies.foodPounds) lbs of food remain.")
        }
    }

    // MARK: - Health

    private func applyHealthDecay(_ log: inout [String]) {
        guard party.aliveCount > 0 else { return }
        let weatherPenalty = [Weather.Kind.snow, .coldSnap].contains(currentWeather.kind) ? 3 : 0
        let foodPenalty = supplies.foodPounds == 0 ? 6 : (ration == .bareBones ? 2 : 0)

        for i in party.members.indices {
            guard party.members[i].isAlive else { continue }

            if let ailment = party.members[i].ailment {
                party.members[i].daysIll += 1
                // Ailments run their course; recovery chance grows with time.
                if recoveryChance(for: ailment, daysIll: party.members[i].daysIll, rng: &rng) {
                    party.members[i].ailment = nil
                    party.members[i].daysIll = 0
                    party.members[i].health = min(100, party.members[i].health + 15)
                    log.append("\(party.members[i].name) shakes off the \(ailment.rawValue).")
                    continue
                }
                let penalty = healthPenalty(for: ailment)
                party.members[i].health = max(0, party.members[i].health - penalty)
            } else {
                let delta = weatherPenalty + foodPenalty
                if delta > 0 {
                    party.members[i].health = max(0, party.members[i].health - delta)
                } else {
                    party.members[i].health = min(100, party.members[i].health + 2)
                }
            }

            if party.members[i].health <= 0 {
                party.members[i].isAlive = false
                let cause = party.members[i].ailment?.rawValue ?? "exposure"
                party.members[i].causeOfDeath = cause
                latestDeathCause = cause
                log.append("\(party.members[i].name) has died of \(cause).")
            }
        }
    }

    private func recoveryChance(for ailment: Ailment, daysIll: Int, rng: inout SplitMix64) -> Bool {
        let base: Double
        switch ailment {
        case .dysentery: base = 0.10
        case .cholera: base = 0.06
        case .typhoid: base = 0.08
        case .measles: base = 0.12
        case .snakebite: base = 0.15
        case .exhaustion: base = 0.20
        case .injury: base = 0.15
        }
        let dayFactor = Double(min(daysIll, 20)) / 20.0
        return rng.chance(base + dayFactor * 0.12)
    }

    private func healthPenalty(for ailment: Ailment) -> Int {
        switch ailment {
        case .dysentery: return 3
        case .cholera: return 6
        case .typhoid: return 4
        case .measles: return 2
        case .snakebite: return 3
        case .exhaustion: return 1
        case .injury: return 4
        }
    }

    // MARK: - Rivers

    private func rollRiverCrossing(at landmark: Landmark, log: inout [String]) {
        log.append("You arrive at the \(landmark.name) crossing.")

        let depth = rng.double(in: 0.5...1.0)
        let attempt = rng.chance(0.7 + depth * 0.1)
        if attempt {
            let loss = rng.chance(0.3)
            if loss {
                let lostFood = rng.int(in: 40...120)
                supplies.foodPounds = max(0, supplies.foodPounds - lostFood)
                log.append("The water is high. \(lostFood) lbs of supplies wash away.")
            } else {
                log.append("The wagons ford the crossing. Everyone makes it across.")
            }
        } else {
            let drowned = party.members.indices.filter { party.members[$0].isAlive }.randomElement(using: &rng)
            if let index = drowned {
                party.members[index].isAlive = false
                party.members[index].health = 0
                party.members[index].ailment = nil
                party.members[index].causeOfDeath = "drowning"
                latestDeathCause = "drowning"
                log.append("The wagon tips in the current. \(party.members[index].name) is lost.")
            } else {
                log.append("The river is impassable. You wait a day on the bank.")
            }
        }
    }

    // MARK: - Events

    private func rollEvent(_ log: inout [String]) {
        guard party.aliveCount > 0 else { return }
        let roll = rng.double(in: 0...1)

        switch Self.dailyEventKind(for: roll) {
        case .illness(let ailment): giveIllness(ailment, log: &log)
        case .hunt: hunt(log: &log)
        case .trailOpportunity: trailOpportunity(log: &log)
        case .oxenWolves: oxenWolves(log: &log)
        case .wagonBreakdown: wagonBreakdown(log: &log)
        case .snakeBite: snakeBite(log: &log)
        case .findSpring: findSpring(log: &log)
        case .regionalTrade: regionalTrade(log: &log)
        case .weatherTurnsBad: weatherTurnsBad(log: &log)
        case .passiveVignette: appendPassiveVignetteIfNoEvent(to: &log)
        case .quiet: break
        }
    }

    /// Existing tick messages are consequential and must remain the last message
    /// shown by the event strip. Ambient color only fills an otherwise quiet day.
    func appendPassiveVignetteIfNoEvent(to log: inout [String]) {
        guard log.isEmpty else { return }
        let terrain = Trail.terrain(at: milesTraveled)
        let choices = Self.passiveVignettes(terrain: terrain, weather: currentWeather.kind)
        if let choice = choices.randomElement(using: &rng) {
            log.append(choice)
        }
    }

    /// Routes one daily roll without consuming more randomness. Existing mechanical
    /// events retain their approximate relative weights but now occupy 45% of days;
    /// passive trail color occupies 18%, leaving 37% genuinely quiet.
    static func dailyEventKind(for roll: Double) -> DailyEventKind {
        precondition((0...1).contains(roll))
        return switch roll {
        case ..<0.080: .illness(.dysentery)
        case ..<0.120: .illness(.cholera)
        case ..<0.160: .illness(.typhoid)
        case ..<0.200: .illness(.measles)
        case ..<0.240: .hunt
        case ..<0.280: .trailOpportunity
        case ..<0.310: .oxenWolves
        case ..<0.340: .wagonBreakdown
        case ..<0.370: .snakeBite
        case ..<0.400: .findSpring
        case ..<0.430: .regionalTrade
        case ..<0.450: .weatherTurnsBad
        case ..<0.630: .passiveVignette
        default: .quiet
        }
    }

    /// A passive vignette describes the trail without changing party, supplies,
    /// travel, weather, or calendar state. Notable weather takes precedence;
    /// clear and overcast days alternate between terrain and sky observations.
    static func passiveVignettes(terrain: Terrain, weather: Weather.Kind) -> [String] {
        let terrainLine: String = switch terrain {
        case .prairie: "Wagon ruts disappear beneath the tall prairie grass."
        case .plains: "A buffalo herd darkens the northern horizon."
        case .river: "Cottonwood leaves turn silver along the riverbank."
        case .mountains: "Loose stone rattles down the mountain slope."
        }

        let weatherLine: String = switch weather {
        case .clear: "Long shadows stretch east across the trail."
        case .overcast: "Low gray clouds flatten the distant horizon."
        case .rain: "Fresh wagon tracks slowly fill with rainwater."
        case .storm: "Lightning shows the trail ahead for an instant."
        case .snow: "Snow softens the ruts left by the wagons ahead."
        case .heatwave: "Heat shimmers above the dry and empty trail."
        case .coldSnap: "A hard frost rims the grass beside the wagon."
        }

        switch weather {
        case .clear, .overcast: return [terrainLine, weatherLine]
        case .rain, .storm, .snow, .heatwave, .coldSnap: return [weatherLine]
        }
    }

    private func giveIllness(_ ailment: Ailment, log: inout [String]) {
        let candidates = party.members.indices.filter { party.members[$0].isAlive && party.members[$0].ailment == nil }
        guard let i = candidates.randomElement(using: &rng) else { return }
        party.members[i].ailment = ailment
        party.members[i].daysIll = 0
        log.append("\(party.members[i].name) has come down with \(ailment.rawValue).")
    }

    private func hunt(log: inout [String]) {
        guard supplies.ammunition >= 20 else {
            log.append("Buffalo graze in the distance, but you have no shot to spare.")
            return
        }
        let ammunitionUsed = min(supplies.ammunition, rng.int(in: 10...30))
        supplies.ammunition -= ammunitionUsed
        let meat = rng.int(in: 80...300)
        supplies.foodPounds += meat
        log.append("A hunt succeeds. You dress \(meat) lbs of meat and press on.")
    }

    func trailOpportunity(log: inout [String]) {
        switch rng.int(in: 0...3) {
        case 0:
            let food = rng.int(in: 35...80)
            supplies.foodPounds += food
            log.append("An abandoned cache yields \(food) lbs of usable food.")
        case 1:
            supplies.spareWheels += 1
            log.append("A discarded wagon leaves behind one sound spare wheel.")
        case 2:
            supplies.spareAxles += 1
            log.append("You salvage a sound axle from a discarded wagon.")
        default:
            supplies.clothingSets += 1
            log.append("A folded wool coat is found beside an old campsite.")
        }
    }

    private func oxenWolves(log: inout [String]) {
        if supplies.oxen > 0 {
            supplies.oxen -= 1
            log.append("Wolves harry the herd at dusk. You lose an ox.")
        } else {
            log.append("Wolves circle the camp, but you've nothing left to lose.")
        }
    }

    func wagonBreakdown(log: inout [String]) {
        let part = rng.int(in: 0...2)
        if part == 0 && supplies.spareWheels > 0 {
            supplies.spareWheels -= 1
            log.append("A wheel cracks. You fit a spare and keep moving.")
        } else if part == 1 && supplies.spareAxles > 0 {
            supplies.spareAxles -= 1
            log.append("The axle groans and splits. A spare saves the day.")
        } else if part == 2 && supplies.spareTongues > 0 {
            supplies.spareTongues -= 1
            log.append("The tongue splinters on a rock. You swap in the spare.")
        } else {
            let lostMiles = rng.int(in: 8...18)
            milesTraveled = max(0, milesTraveled - lostMiles)
            for i in party.members.indices where party.members[i].isAlive {
                party.members[i].health = max(1, party.members[i].health - 2)
            }
            log.append("With no matching spare, repairs cost \(lostMiles) miles.")
        }
    }

    private func snakeBite(log: inout [String]) {
        let candidates = party.members.indices.filter { party.members[$0].isAlive }
        guard let i = candidates.randomElement(using: &rng) else { return }
        party.members[i].ailment = .snakebite
        party.members[i].daysIll = 0
        log.append("A rattler strikes at \(party.members[i].name)'s boot. The wound swells.")
    }

    private func findSpring(log: inout [String]) {
        for i in party.members.indices where party.members[i].isAlive {
            party.members[i].health = min(100, party.members[i].health + 10)
        }
        log.append("You find a cold spring. Everyone drinks their fill and feels stronger.")
    }

    func regionalTrade(log: inout [String]) {
        switch milesTraveled {
        case ..<890:
            tradeFood(
                cost: 8,
                amount: 55,
                success: "You trade $8 for 55 lbs of food at a trail camp.",
                fallback: "A trail trader points out the next reliable water.",
                log: &log
            )
        case ..<1320:
            milesTraveled = min(Trail.totalMiles, milesTraveled + 5)
            log.append("Shoshone travelers point out a better route to water.")
        case ..<1890:
            tradeFood(
                cost: 10,
                amount: 70,
                success: "Shoshone traders exchange 70 lbs of food for $10.",
                fallback: "Shoshone traders share news of the trail ahead.",
                log: &log
            )
        default:
            tradeFood(
                cost: 12,
                amount: 80,
                success: "Cayuse and Walla Walla traders exchange food for $12.",
                fallback: "Cayuse and Walla Walla traders describe the river route.",
                log: &log
            )
        }
    }

    private func tradeFood(
        cost: Int,
        amount: Int,
        success: String,
        fallback: String,
        log: inout [String]
    ) {
        guard supplies.cash >= cost else {
            log.append(fallback)
            return
        }
        supplies.cash -= cost
        supplies.foodPounds += amount
        log.append(success)
    }

    private func weatherTurnsBad(log: inout [String]) {
        if currentWeather.kind == .clear || currentWeather.kind == .overcast {
            log.append("A squall line builds on the horizon. The oxen stamp their feet.")
        } else {
            log.append("The weather worsens. You hunker down and lose ground.")
            milesTraveled = max(0, milesTraveled - rng.int(in: 5...15))
        }
    }

    // MARK: - Landmarks

    private func checkLandmarksCrossed(from startMiles: Int, through endMiles: Int, log: inout [String]) {
        guard endMiles > startMiles else { return }

        let reached = Trail.landmarks.filter {
            $0.distance > startMiles && $0.distance <= endMiles && !crossedLandmarks.contains($0.name)
        }

        for landmark in reached {
            crossedLandmarks.insert(landmark.name)
            if landmark.requiresRiverCrossing {
                rollRiverCrossing(at: landmark, log: &log)
            } else {
                log.append("You reach \(landmark.name) — \(landmark.distance) miles in.")
            }
        }
    }

    // MARK: - End conditions

    private func checkEndConditions(_ log: inout [String]) {
        if party.isAllDead {
            isFinished = true
            let cause = latestDeathCause ?? "the wilderness"
            outcome = .partyPerished(cause: cause)
            log.append("The trail has taken everyone. The wagons sit still on the prairie.")
        } else if milesTraveled >= Trail.totalMiles {
            isFinished = true
            outcome = .reachedOregon
            log.append("After \(day) days, you reach the Willamette Valley. Oregon, at last.")
        }
    }

    // MARK: - Calendar

    private func advanceWeatherFront() {
        if weatherFrontDaysRemaining == 0 {
            currentWeather = Weather.roll(month: month, rng: &rng)
            weatherFrontDaysRemaining = rng.int(in: 2...4)
        }
        weatherFrontDaysRemaining -= 1
    }

    private func advanceCalendar() {
        dayOfMonth += 1
        let daysInMonth: Int
        switch month {
        case 4, 6, 9, 11: daysInMonth = 30
        case 2: daysInMonth = 28
        default: daysInMonth = 31
        }
        if dayOfMonth > daysInMonth {
            dayOfMonth = 1
            month += 1
            if month > 12 {
                month = 1
                year += 1
            }
        }
    }
}
