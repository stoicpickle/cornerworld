import XCTest
@testable import GameCore

final class SimulationTests: XCTestCase {

    private func requireSendable<T: Sendable>(_: T.Type) {}

    func testDisplayedSeedsRoundTripAsHexAndDecimalInputStillWorks() {
        let seed = UInt64.max - 123
        XCTAssertEqual(SeedCodec.parse(SeedCodec.display(seed)), seed)
        XCTAssertEqual(SeedCodec.parse("42"), 42)
        XCTAssertEqual(SeedCodec.parse("0x2A"), 42)
        XCTAssertNil(SeedCodec.parse("2A"))
        XCTAssertNil(SeedCodec.parse("not-a-seed"))
    }

    func testSplitMix64MappingHasAStableGoldenSequence() {
        var rng = SplitMix64(seed: 42)
        XCTAssertEqual(rng.next(), 13_679_457_532_755_275_413)
        XCTAssertEqual(rng.next(), 2_949_826_092_126_892_291)
        XCTAssertEqual(rng.next(), 5_139_283_748_462_763_858)

        var mapped = SplitMix64(seed: 42)
        XCTAssertEqual((0..<6).map { _ in mapped.int(in: 0...9) }, [3, 1, 8, 4, 0, 2])
    }

    func testIntegerMappingHandlesFullWidthRanges() {
        var negativeRange = SplitMix64(seed: 42)
        for _ in 0..<100 {
            let value = negativeRange.int(in: Int.min...0)
            XCTAssertGreaterThanOrEqual(value, Int.min)
            XCTAssertLessThanOrEqual(value, 0)
        }

        var fullRange = SplitMix64(seed: 42)
        for _ in 0..<100 {
            let value = fullRange.int(in: Int.min...Int.max)
            XCTAssertGreaterThanOrEqual(value, Int.min)
            XCTAssertLessThanOrEqual(value, Int.max)
        }
    }

    func testDoubleMappingKeepsExtremeFiniteRangesFinite() {
        var rng = SplitMix64(seed: 42)
        for _ in 0..<100 {
            let value = rng.double(in: -Double.greatestFiniteMagnitude...Double.greatestFiniteMagnitude)
            XCTAssertTrue(value.isFinite)
            XCTAssertGreaterThanOrEqual(value, -Double.greatestFiniteMagnitude)
            XCTAssertLessThanOrEqual(value, Double.greatestFiniteMagnitude)
        }
    }

    func testDeterministicRuns() {
        let a = Simulation(seed: 42)
        let b = Simulation(seed: 42)

        var guardDays = 0
        while !a.isFinished, guardDays < 1000 {
            a.tick()
            b.tick()
            guardDays += 1
        }

        XCTAssertTrue(a.isFinished)
        XCTAssertTrue(b.isFinished)
        XCTAssertEqual(a.day, b.day)
        XCTAssertEqual(a.outcome, b.outcome)
        XCTAssertEqual(a.eventLog, b.eventLog)
    }

    func testDifferentSeedsDiffer() {
        let a = Simulation(seed: 42)
        let b = Simulation(seed: 43)

        var guardDays = 0
        while (!a.isFinished || !b.isFinished), guardDays < 1000 {
            if !a.isFinished { a.tick() }
            if !b.isFinished { b.tick() }
            guardDays += 1
        }

        XCTAssertTrue(a.isFinished)
        XCTAssertTrue(b.isFinished)
        XCTAssertNotEqual(a.eventLog, b.eventLog)
    }

    func testRunCompletes() {
        let sim = Simulation(seed: 7)
        var guardDays = 0
        while !sim.isFinished, guardDays < 1000 {
            sim.tick()
            guardDays += 1
        }
        XCTAssertTrue(sim.isFinished, "simulation should finish")
        XCTAssertLessThan(guardDays, 1000)
    }

    func testPartyDefaultsToFive() {
        let sim = Simulation(seed: 1)
        XCTAssertEqual(sim.party.members.count, 5)
        XCTAssertEqual(sim.party.aliveCount, 5)
    }

    func testNoNegativeSupplies() {
        let sim = Simulation(seed: 99)
        while !sim.isFinished, sim.day < 500 {
            sim.tick()
            XCTAssertGreaterThanOrEqual(sim.supplies.foodPounds, 0)
            XCTAssertGreaterThanOrEqual(sim.supplies.oxen, 0)
            XCTAssertGreaterThanOrEqual(sim.supplies.ammunition, 0)
        }
    }

    func testRationLevelsTradeFoodForDailyHealth() {
        func health(after ration: Ration, food: Int = 100) -> Int {
            let party = Party(members: [PartyMember(name: "Ada", health: 80)])
            let sim = Simulation(
                seed: 1,
                party: party,
                supplies: Supplies(foodPounds: food)
            )
            sim.ration = ration
            var log: [String] = []
            sim.applyHealthDecay(&log)
            return sim.party.members[0].health
        }

        XCTAssertEqual(health(after: .filling), 82)
        XCTAssertEqual(health(after: .meager), 80)
        XCTAssertEqual(health(after: .bareBones), 78)
        XCTAssertEqual(health(after: .filling, food: 0), 74)
    }

    func testExactDailyRationFeedsThePartyButPartialRationDoesNot() {
        func result(startingFood: Int) -> (health: Int, food: Int, fullyFed: Bool) {
            let party = Party(members: [PartyMember(name: "Ada", health: 80)])
            let sim = Simulation(
                seed: 1,
                party: party,
                supplies: Supplies(foodPounds: startingFood)
            )
            sim.ration = .filling
            var log: [String] = []
            let fullyFed = sim.consumeFood(&log)
            sim.applyHealthDecay(&log, fullyFed: fullyFed)
            return (sim.party.members[0].health, sim.supplies.foodPounds, fullyFed)
        }

        let exact = result(startingFood: 3)
        XCTAssertEqual(exact.health, 82)
        XCTAssertEqual(exact.food, 0)
        XCTAssertTrue(exact.fullyFed)

        let partial = result(startingFood: 2)
        XCTAssertEqual(partial.health, 74)
        XCTAssertEqual(partial.food, 0)
        XCTAssertFalse(partial.fullyFed)
    }

    func testRecoveryStillPaysStarvationPenalty() {
        var observedRecovery = false

        for seed in UInt64(0)..<100 {
            let party = Party(members: [
                PartyMember(name: "Ada", health: 80, ailment: .exhaustion, daysIll: 20),
            ])
            let sim = Simulation(seed: seed, party: party, supplies: Supplies(foodPounds: 0))
            var log: [String] = []
            sim.applyHealthDecay(&log, fullyFed: false)

            if log.contains(where: { $0.contains("shakes off") }) {
                observedRecovery = true
                XCTAssertEqual(sim.party.members[0].health, 89)
                break
            }
        }

        XCTAssertTrue(observedRecovery)
    }

    func testZeroOxenCannotAdvance() {
        let sim = Simulation(
            seed: 1,
            supplies: Supplies(oxen: 0),
            milesTraveled: 100
        )

        let log = sim.tick()

        XCTAssertEqual(sim.milesTraveled, 100)
        XCTAssertTrue(log.contains("You have no oxen. The wagon cannot move."))
    }

    func testZeroOxenEventuallyEndsTheJourney() {
        let sim = Simulation(
            seed: 7,
            party: Party(members: [PartyMember(name: "Ada", health: 20)]),
            supplies: Supplies(foodPounds: 500, oxen: 0)
        )

        for _ in 0..<30 where !sim.isFinished {
            sim.tick()
        }

        XCTAssertTrue(sim.isFinished)
        XCTAssertEqual(sim.outcome, .partyPerished(cause: "exposure"))
    }

    func testVerySlowPaceMateriallyReducesDailyTravel() {
        func distance(at pace: Pace) -> Int {
            let sim = Simulation(seed: 1, supplies: Supplies())
            sim.pace = pace
            return sim.travelDistance()
        }

        XCTAssertEqual(distance(at: .steady), 17)
        XCTAssertEqual(distance(at: .moderate), 14)
        XCTAssertEqual(distance(at: .slow), 12)
        XCTAssertEqual(distance(at: .verySlow), 8)
    }

    func testCrossedCheckpointsAreNotSkippedByDailyTravel() {
        let fort = Simulation(seed: 1, supplies: Supplies(), milesTraveled: 319)
        let fortLog = fort.tick()
        XCTAssertTrue(fortLog.contains("You reach Fort Kearney — 320 miles in."))

        let river = Simulation(seed: 1, supplies: Supplies(), milesTraveled: 1889)
        let riverLog = river.tick()
        XCTAssertTrue(riverLog.contains("You arrive at the Fort Walla Walla crossing."))

        for _ in 0..<10 where !river.isFinished {
            river.tick()
        }
        XCTAssertEqual(
            river.eventLog.filter { $0 == "You arrive at the Fort Walla Walla crossing." }.count,
            1
        )

        let destination = Simulation(
            seed: 1,
            supplies: Supplies(),
            milesTraveled: Trail.totalMiles - 1
        )
        let destinationLog = destination.tick()
        XCTAssertTrue(destinationLog.contains("You reach Oregon City — 2040 miles in."))
        XCTAssertFalse(destinationLog.contains("You arrive at the Oregon City crossing."))
    }

    func testLastSurvivorDyingOnArrivalCannotWin() {
        let party = Party(members: [
            PartyMember(name: "Ada", health: 1, ailment: .cholera)
        ])
        let sim = Simulation(
            seed: 1,
            party: party,
            supplies: Supplies(),
            milesTraveled: Trail.totalMiles - 1
        )

        sim.tick()

        XCTAssertEqual(sim.party.aliveCount, 0)
        XCTAssertEqual(sim.outcome, .partyPerished(cause: "cholera"))
        XCTAssertEqual(sim.party.members[0].causeOfDeath, "cholera")
        XCTAssertEqual(sim.memorials, ["Ada — cholera"])
    }

    func testArrivalEndsBeforeADailyEventCanUndoProgress() {
        for seed in UInt64(0)..<100 {
            let sim = Simulation(
                seed: seed,
                supplies: Supplies(),
                milesTraveled: Trail.totalMiles - 1
            )

            sim.tick()

            XCTAssertEqual(sim.outcome, .reachedOregon, "seed: \(seed)")
            XCTAssertEqual(sim.milesTraveled, Trail.totalMiles, "seed: \(seed)")
            XCTAssertEqual(sim.eventLog.count, 2, "seed: \(seed)")
        }
    }

    func testPartyOutcomeUsesMostRecentDeathRatherThanMemberOrder() {
        let party = Party(members: [
            PartyMember(name: "Ada", health: 1, ailment: .cholera),
            PartyMember(
                name: "Bea",
                health: 0,
                isAlive: false,
                causeOfDeath: "typhoid"
            ),
        ])
        let sim = Simulation(seed: 1, party: party, supplies: Supplies())

        sim.tick()

        XCTAssertEqual(sim.outcome, .partyPerished(cause: "cholera"))
    }

    func testRecoveryClearsIllnessEpisodeAge() {
        var observedRecovery = false

        for seed in UInt64(0)..<100 {
            let party = Party(members: [
                PartyMember(name: "Ada", ailment: .exhaustion, daysIll: 20)
            ])
            let sim = Simulation(seed: seed, party: party, supplies: Supplies())
            let log = sim.tick()

            if log.contains(where: { $0.contains("shakes off") }) {
                observedRecovery = true
                XCTAssertNil(sim.party.members[0].ailment)
                XCTAssertEqual(sim.party.members[0].daysIll, 0)
                break
            }
        }

        XCTAssertTrue(observedRecovery, "expected at least one deterministic recovery seed")
    }

    func testNewIllnessStartsAtDayZero() {
        var observedIllness = false

        for seed in UInt64(0)..<200 {
            let party = Party(members: [PartyMember(name: "Ada", daysIll: 17)])
            let sim = Simulation(seed: seed, party: party, supplies: Supplies())
            let log = sim.tick()

            if log.contains(where: { $0.contains("come down with") }) {
                observedIllness = true
                XCTAssertNotNil(sim.party.members[0].ailment)
                XCTAssertEqual(sim.party.members[0].daysIll, 0)
                XCTAssertEqual(
                    sim.latestVisualEvent,
                    .illness(memberName: "Ada", ailment: sim.party.members[0].ailment!)
                )
                break
            }
        }

        XCTAssertTrue(observedIllness, "expected at least one deterministic illness seed")
    }

    func testSnakeBiteDoesNotReplaceAnExistingIllness() {
        let party = Party(members: [
            PartyMember(name: "Ada", ailment: .cholera, daysIll: 4),
        ])
        let sim = Simulation(seed: 1, party: party, supplies: Supplies())
        var log: [String] = []

        sim.snakeBite(log: &log)

        XCTAssertEqual(sim.party.members[0].ailment, .cholera)
        XCTAssertEqual(sim.party.members[0].daysIll, 4)
        XCTAssertEqual(log, ["A rattler circles the camp, but no one is struck."])
        XCTAssertEqual(sim.latestVisualEvent, .snakebite(.missed))
    }

    func testHuntingCannotSpendMoreAmmunitionThanAvailable() {
        var observedHunt = false

        for seed in UInt64(0)..<200 {
            let sim = Simulation(
                seed: seed,
                supplies: Supplies(ammunition: 20)
            )
            let log = sim.tick()

            if log.contains(where: { $0.contains("A hunt succeeds") }) {
                observedHunt = true
                XCTAssertGreaterThanOrEqual(sim.supplies.ammunition, 0)
                guard case .hunt(.success(let meat)) = sim.latestVisualEvent else {
                    return XCTFail("expected a typed successful hunt")
                }
                XCTAssertTrue(log.last?.contains("\(meat) lbs of meat") == true)
                break
            }
        }

        XCTAssertTrue(observedHunt, "expected at least one deterministic hunting seed")
    }

    func testDailyEventRoutingHasIntendedWeightsAndBoundaries() {
        let cases: [(Double, Simulation.DailyEventKind)] = [
            (0.000, .illness(.dysentery)),
            (0.044, .illness(.cholera)),
            (0.066, .illness(.typhoid)),
            (0.088, .illness(.measles)),
            (0.110, .hunt),
            (0.132, .trailOpportunity),
            (0.154, .oxenWolves),
            (0.171, .wagonBreakdown),
            (0.188, .snakeBite),
            (0.205, .findSpring),
            (0.222, .regionalTrade),
            (0.239, .weatherTurnsBad),
            (0.250, .passiveVignette),
            (0.329, .passiveVignette),
            (0.330, .quiet),
            (1.000, .quiet),
        ]

        for (roll, expected) in cases {
            XCTAssertEqual(Simulation.dailyEventKind(for: roll), expected, "roll: \(roll)")
        }

        // Cooldown is applied separately after the 25% mechanical, 8% passive roll.
        XCTAssertEqual(0.250 - 0.000, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(0.330 - 0.250, 0.08, accuracy: 0.000_001)
        XCTAssertEqual(1.000 - 0.330, 0.67, accuracy: 0.000_001)
    }

    func testRandomEventsLeaveAtLeastThreeQuietDays() {
        var verifiedCooldowns = 0

        for seed in UInt64(0)..<200 {
            let sim = Simulation(seed: seed)
            while !sim.isFinished, sim.day < 60 {
                sim.tick()
                guard sim.latestVisualEvent != nil,
                      sim.randomEventCooldownDaysForTesting >= 3 else { continue }

                for _ in 0..<3 where !sim.isFinished {
                    sim.tick()
                    XCTAssertNil(sim.latestVisualEvent, "seed: \(seed), day: \(sim.day)")
                }
                verifiedCooldowns += 1
                break
            }
        }

        XCTAssertGreaterThan(verifiedCooldowns, 100)
    }

    func testRandomEventCooldownVariesBetweenThreeAndSixDays() {
        var observed = Set<Int>()

        for seed in UInt64(0)..<300 {
            let sim = Simulation(seed: seed)
            while !sim.isFinished, sim.day < 40, observed.count < 4 {
                sim.tick()
                if sim.latestVisualEvent != nil,
                   (3...6).contains(sim.randomEventCooldownDaysForTesting) {
                    observed.insert(sim.randomEventCooldownDaysForTesting)
                }
            }
        }

        XCTAssertEqual(observed, Set(3...6))
    }

    func testPassiveVignettesAreTerrainAndWeatherAwareAndFitEventStrip() {
        let terrains: [Terrain] = [.prairie, .plains, .river, .mountains]
        let weatherKinds: [Weather.Kind] = [
            .clear, .overcast, .rain, .storm, .snow, .heatwave, .coldSnap,
        ]
        var distinctLines = Set<String>()

        for terrain in terrains {
            for weather in weatherKinds {
                let lines = Simulation.passiveVignettes(terrain: terrain, weather: weather)
                XCTAssertEqual(lines.count, weather == .clear || weather == .overcast ? 2 : 1)
                XCTAssertTrue(lines.allSatisfy { !$0.isEmpty && $0.count <= 68 })
                distinctLines.formUnion(lines)
            }
        }

        XCTAssertEqual(distinctLines.count, 11)
        XCTAssertNotEqual(
            Simulation.passiveVignettes(terrain: .prairie, weather: .clear)[0],
            Simulation.passiveVignettes(terrain: .mountains, weather: .clear)[0]
        )
        XCTAssertNotEqual(
            Simulation.passiveVignettes(terrain: .prairie, weather: .rain)[0],
            Simulation.passiveVignettes(terrain: .prairie, weather: .snow)[0]
        )
    }

    func testPassiveVignetteNeverHidesConsequentialTickMessage() {
        let sim = Simulation(seed: 17)
        var existingLog = ["You reach Fort Kearney — 320 miles in."]

        sim.appendPassiveVignetteIfNoEvent(to: &existingLog)

        XCTAssertEqual(existingLog, ["You reach Fort Kearney — 320 miles in."])

        let suppliesBefore = [
            sim.supplies.foodPounds, sim.supplies.oxen, sim.supplies.ammunition,
            sim.supplies.clothingSets, sim.supplies.spareWheels,
            sim.supplies.spareAxles, sim.supplies.spareTongues, sim.supplies.cash,
        ]
        let partyBefore = sim.party.members.map {
            "\($0.name)|\($0.health)|\($0.isAlive)|\($0.ailment?.rawValue ?? "")|\($0.daysIll)"
        }
        let milesBefore = sim.milesTraveled
        var quietLog: [String] = []
        sim.appendPassiveVignetteIfNoEvent(to: &quietLog)

        XCTAssertEqual(quietLog.count, 1)
        XCTAssertEqual([
            sim.supplies.foodPounds, sim.supplies.oxen, sim.supplies.ammunition,
            sim.supplies.clothingSets, sim.supplies.spareWheels,
            sim.supplies.spareAxles, sim.supplies.spareTongues, sim.supplies.cash,
        ], suppliesBefore)
        XCTAssertEqual(sim.party.members.map {
            "\($0.name)|\($0.health)|\($0.isAlive)|\($0.ailment?.rawValue ?? "")|\($0.daysIll)"
        }, partyBefore)
        XCTAssertEqual(sim.milesTraveled, milesBefore)
    }

    func testWeatherPersistsAsAFrontBeforeRerolling() {
        let sim = Simulation(seed: 83)
        sim.tick()
        let firstWeather = sim.currentWeather.kind
        let remaining = sim.weatherFrontDaysRemainingForTesting

        XCTAssertTrue((1...3).contains(remaining))
        for _ in 0..<remaining {
            sim.tick()
            XCTAssertEqual(sim.currentWeather.kind, firstWeather)
        }

        sim.tick()
        XCTAssertTrue((1...3).contains(sim.weatherFrontDaysRemainingForTesting))
    }

    func testBreakdownWithoutSpareCostsProgressAndHealth() {
        let party = Party(members: [PartyMember(name: "Ada")])
        let sim = Simulation(
            seed: 5,
            party: party,
            supplies: Supplies(spareWheels: 0, spareAxles: 0, spareTongues: 0),
            milesTraveled: 100
        )
        var log: [String] = []

        sim.wagonBreakdown(log: &log)

        XCTAssertLessThan(sim.milesTraveled, 100)
        XCTAssertEqual(sim.party.members[0].health, 98)
        XCTAssertTrue(log[0].contains("repairs cost"))
        guard case .wagonBreakdown(_, repaired: false) = sim.latestVisualEvent else {
            return XCTFail("expected a typed unrepaired breakdown")
        }
    }

    func testRegionalEncountersChangeAlongTheTrail() {
        let mountainParty = Party(members: [PartyMember(name: "Ada", health: 80)])
        let mountain = Simulation(
            seed: 1,
            party: mountainParty,
            supplies: Supplies(),
            milesTraveled: 900
        )
        var mountainLog: [String] = []
        mountain.regionalTrade(log: &mountainLog)
        XCTAssertEqual(mountain.milesTraveled, 900)
        XCTAssertEqual(mountain.party.members[0].health, 85)
        XCTAssertTrue(mountainLog[0].contains("Shoshone"))

        let columbia = Simulation(seed: 1, supplies: Supplies(cash: 0), milesTraveled: 1900)
        var columbiaLog: [String] = []
        columbia.regionalTrade(log: &columbiaLog)
        XCTAssertTrue(columbiaLog[0].contains("Cayuse and Walla Walla"))
        XCTAssertLessThanOrEqual(columbiaLog[0].count, 68)

        let columbiaTrade = Simulation(seed: 1, supplies: Supplies(cash: 12), milesTraveled: 1900)
        var tradeLog: [String] = []
        columbiaTrade.regionalTrade(log: &tradeLog)
        XCTAssertTrue(tradeLog[0].contains("Cayuse and Walla Walla"))
        XCTAssertEqual(columbiaTrade.supplies.cash, 0)
    }

    func testOpportunityAddsAUsefulSupply() {
        let baseline = Supplies()
        let sim = Simulation(seed: 3, supplies: baseline)
        var log: [String] = []

        sim.trailOpportunity(log: &log)

        let gainedSomething = sim.supplies.foodPounds > baseline.foodPounds
            || sim.supplies.spareWheels > baseline.spareWheels
            || sim.supplies.spareAxles > baseline.spareAxles
            || sim.supplies.clothingSets > baseline.clothingSets
        XCTAssertTrue(gainedSomething)
        XCTAssertEqual(log.count, 1)
        XCTAssertLessThanOrEqual(log[0].count, 68)
        guard case .trailOpportunity = sim.latestVisualEvent else {
            return XCTFail("expected a typed trail opportunity")
        }
    }

    func testBadWeatherEventStartsAStormFront() {
        let sim = Simulation(seed: 1, supplies: Supplies())
        var log: [String] = []

        sim.weatherTurnsBad(log: &log)

        XCTAssertEqual(sim.currentWeather.kind, .storm)
        XCTAssertEqual(sim.weatherFrontDaysRemainingForTesting, 2)
        XCTAssertTrue(log[0].contains("squall"))
    }

    func testVisualEventContractIsEquatableAndSendable() {
        requireSendable(VisualEvent.self)
        requireSendable(HuntOutcome.self)
        requireSendable(TrailOpportunityItem.self)
        requireSendable(WagonPart.self)
        requireSendable(SnakebiteOutcome.self)
        requireSendable(RiverCrossingOutcome.self)
        requireSendable(AmbientMoment.self)

        XCTAssertEqual(
            VisualEvent.wagonBreakdown(part: .wheel, repaired: true),
            .wagonBreakdown(part: .wheel, repaired: true)
        )
        XCTAssertNotEqual(
            VisualEvent.hunt(.noAmmunition),
            .hunt(.success(meatPounds: 80))
        )
    }

    func testEventHelpersPublishTypedOutcomesWithoutChangingTheirMessages() {
        let opportunity = Simulation(seed: 3, supplies: Supplies())
        var opportunityLog: [String] = []
        opportunity.trailOpportunity(log: &opportunityLog)
        guard case .trailOpportunity = opportunity.latestVisualEvent else {
            return XCTFail("expected a typed trail opportunity")
        }
        XCTAssertEqual(opportunityLog.count, 1)

        let breakdown = Simulation(
            seed: 5,
            supplies: Supplies(spareWheels: 0, spareAxles: 0, spareTongues: 0),
            milesTraveled: 100
        )
        var breakdownLog: [String] = []
        breakdown.wagonBreakdown(log: &breakdownLog)
        guard case .wagonBreakdown(_, repaired: false) = breakdown.latestVisualEvent else {
            return XCTFail("expected an unrepaired breakdown")
        }
        XCTAssertTrue(breakdownLog[0].contains("repairs cost"))

        let illParty = Party(members: [
            PartyMember(name: "Ada", ailment: .cholera, daysIll: 4),
        ])
        let snake = Simulation(seed: 1, party: illParty, supplies: Supplies())
        var snakeLog: [String] = []
        snake.snakeBite(log: &snakeLog)
        XCTAssertEqual(snake.latestVisualEvent, .snakebite(.missed))
        XCTAssertEqual(snakeLog, ["A rattler circles the camp, but no one is struck."])

        let trade = Simulation(seed: 1, supplies: Supplies(cash: 0))
        var tradeLog: [String] = []
        trade.regionalTrade(log: &tradeLog)
        XCTAssertEqual(trade.latestVisualEvent, .regionalTrade)

        let weather = Simulation(seed: 1, supplies: Supplies())
        var weatherLog: [String] = []
        weather.weatherTurnsBad(log: &weatherLog)
        XCTAssertEqual(weather.latestVisualEvent, .weatherWorsening)
    }

    func testAmbientMomentMappingMatchesExistingVignetteOrder() {
        XCTAssertEqual(
            Simulation.ambientMoment(terrain: .prairie, weather: .clear, index: 0),
            .prairieGrass
        )
        XCTAssertEqual(
            Simulation.ambientMoment(terrain: .mountains, weather: .overcast, index: 0),
            .fallingStone
        )
        XCTAssertEqual(
            Simulation.ambientMoment(terrain: .river, weather: .clear, index: 1),
            .longShadows
        )
        XCTAssertEqual(
            Simulation.ambientMoment(terrain: .plains, weather: .overcast, index: 1),
            .lowClouds
        )
        XCTAssertEqual(
            Simulation.ambientMoment(terrain: .prairie, weather: .storm, index: 0),
            .lightning
        )
    }

    func testLatestVisualEventClearsAtTheStartOfAQuietTick() {
        var observedQuietTick = false

        for seed in UInt64(0)..<200 {
            let sim = Simulation(seed: seed, supplies: Supplies())
            var setupLog: [String] = []
            sim.regionalTrade(log: &setupLog)
            XCTAssertEqual(sim.latestVisualEvent, .regionalTrade)

            let log = sim.tick()
            if log.isEmpty {
                observedQuietTick = true
                XCTAssertNil(sim.latestVisualEvent)
                break
            }
        }

        XCTAssertTrue(observedQuietTick, "expected at least one deterministic quiet seed")
    }

    func testTypedVisualEventsStayAlignedWithTheFinalDisplayedMessage() {
        var checkedEvents = 0

        for seed in UInt64(0)..<80 {
            let sim = Simulation(seed: seed)
            while !sim.isFinished, sim.day < 80 {
                let log = sim.tick()
                guard let visualEvent = sim.latestVisualEvent else { continue }
                guard let displayedMessage = log.last else {
                    return XCTFail("a visual event must have a displayed message")
                }
                XCTAssertTrue(
                    visualEventMatchesDisplayedMessage(visualEvent, displayedMessage),
                    "\(visualEvent) does not match: \(displayedMessage)"
                )
                checkedEvents += 1
            }
        }

        XCTAssertGreaterThan(checkedEvents, 100)
    }

    func testRiverCrossingIsNotOverwrittenByASecondDailyEvent() {
        var observedCrossing = false
        for seed in UInt64(0)..<300 {
            let sim = Simulation(seed: seed, supplies: Supplies(), milesTraveled: 1889)
            let log = sim.tick()
            guard log.contains("You arrive at the Fort Walla Walla crossing."),
                  let event = sim.latestVisualEvent else { continue }
            guard case .riverCrossing = event else {
                return XCTFail("river art was overwritten by \(event)")
            }
            observedCrossing = true
        }

        XCTAssertTrue(observedCrossing, "expected at least one rendered crossing")
    }

    func testTerminalOutcomeClearsEarlierRiverVisualEvent() {
        var observedTerminalRiverLoss = false

        for seed in UInt64(0)..<300 {
            let party = Party(members: [PartyMember(name: "Ada")])
            let sim = Simulation(
                seed: seed,
                party: party,
                supplies: Supplies(),
                milesTraveled: 1889
            )
            let log = sim.tick()
            guard sim.outcome == .partyPerished(cause: "drowning") else { continue }

            observedTerminalRiverLoss = true
            XCTAssertNil(sim.latestVisualEvent)
            XCTAssertEqual(
                log.last,
                "The trail has taken everyone. The wagons sit still on the prairie."
            )
            break
        }

        XCTAssertTrue(observedTerminalRiverLoss, "expected a deterministic terminal river loss")
    }

    private func visualEventMatchesDisplayedMessage(_ event: VisualEvent, _ message: String) -> Bool {
        switch event {
        case .illness(let name, let ailment):
            return message == "\(name) has come down with \(ailment.rawValue)."
        case .hunt(.success(let meat)):
            return message == "A hunt succeeds. You dress \(meat) lbs of meat and press on."
        case .hunt(.noAmmunition):
            return message == "Buffalo graze in the distance, but you have no shot to spare."
        case .trailOpportunity(.food(let pounds)):
            return message == "An abandoned cache yields \(pounds) lbs of usable food."
        case .trailOpportunity(.spareWheel):
            return message == "A discarded wagon leaves behind one sound spare wheel."
        case .trailOpportunity(.spareAxle):
            return message == "You salvage a sound axle from a discarded wagon."
        case .trailOpportunity(.clothing):
            return message == "A folded wool coat is found beside an old campsite."
        case .wolves(let lost):
            return lost
                ? message == "Wolves harry the herd at dusk. You lose an ox."
                : message == "Wolves circle the camp, but you've nothing left to lose."
        case .wagonBreakdown(let part, let repaired):
            if !repaired { return message.hasPrefix("With no matching spare, repairs cost ") }
            return switch part {
            case .wheel: message == "A wheel cracks. You fit a spare and keep moving."
            case .axle: message == "The axle groans and splits. A spare saves the day."
            case .tongue: message == "The tongue splinters on a rock. You swap in the spare."
            }
        case .snakebite(.struck(let name)):
            return message == "A rattler strikes at \(name)'s boot. The wound swells."
        case .snakebite(.missed):
            return message == "A rattler circles the camp, but no one is struck."
        case .spring:
            return message == "You find a cold spring. Everyone drinks their fill and feels stronger."
        case .regionalTrade:
            return message.contains("trade") || message.contains("trader")
                || message.contains("Shoshone") || message.contains("Cayuse")
        case .weatherWorsening:
            return message.hasPrefix("A squall line builds") || message.hasPrefix("The weather worsens")
        case .ambient(let moment):
            return message == ambientMessage(for: moment)
        case .riverCrossing(_, .success):
            return message == "The wagons ford the crossing. Everyone makes it across."
        case .riverCrossing(_, .suppliesLost(let pounds)):
            return message == "The water is high. \(pounds) lbs of supplies wash away."
        case .riverCrossing(_, .travelerLost(let name)):
            return message == "The wagon tips in the current. \(name) is lost."
        case .riverCrossing(_, .impassable):
            return message == "The river is impassable. You wait a day on the bank."
        }
    }

    private func ambientMessage(for moment: AmbientMoment) -> String {
        switch moment {
        case .prairieGrass: "Wagon ruts disappear beneath the tall prairie grass."
        case .buffaloHerd: "A buffalo herd darkens the northern horizon."
        case .cottonwoodLeaves: "Cottonwood leaves turn silver along the riverbank."
        case .fallingStone: "Loose stone rattles down the mountain slope."
        case .longShadows: "Long shadows stretch east across the trail."
        case .lowClouds: "Low gray clouds flatten the distant horizon."
        case .rainTracks: "Fresh wagon tracks slowly fill with rainwater."
        case .lightning: "Lightning shows the trail ahead for an instant."
        case .snowRuts: "Snow softens the ruts left by the wagons ahead."
        case .heatShimmer: "Heat shimmers above the dry and empty trail."
        case .frostGrass: "A hard frost rims the grass beside the wagon."
        }
    }
}
