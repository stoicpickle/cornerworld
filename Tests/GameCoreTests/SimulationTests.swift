import XCTest
@testable import GameCore

final class SimulationTests: XCTestCase {

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
                break
            }
        }

        XCTAssertTrue(observedHunt, "expected at least one deterministic hunting seed")
    }

    func testDailyEventRoutingHasIntendedWeightsAndBoundaries() {
        let cases: [(Double, Simulation.DailyEventKind)] = [
            (0.000, .illness(.dysentery)),
            (0.080, .illness(.cholera)),
            (0.120, .illness(.typhoid)),
            (0.160, .illness(.measles)),
            (0.200, .hunt),
            (0.240, .trailOpportunity),
            (0.280, .oxenWolves),
            (0.310, .wagonBreakdown),
            (0.340, .snakeBite),
            (0.370, .findSpring),
            (0.400, .regionalTrade),
            (0.430, .weatherTurnsBad),
            (0.450, .passiveVignette),
            (0.629, .passiveVignette),
            (0.630, .quiet),
            (1.000, .quiet),
        ]

        for (roll, expected) in cases {
            XCTAssertEqual(Simulation.dailyEventKind(for: roll), expected, "roll: \(roll)")
        }

        // The routing table reserves 45% mechanical, 18% passive, 37% quiet.
        XCTAssertEqual(0.450 - 0.000, 0.45, accuracy: 0.000_001)
        XCTAssertEqual(0.630 - 0.450, 0.18, accuracy: 0.000_001)
        XCTAssertEqual(1.000 - 0.630, 0.37, accuracy: 0.000_001)
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
    }

    func testBadWeatherEventStartsAStormFront() {
        let sim = Simulation(seed: 1, supplies: Supplies())
        var log: [String] = []

        sim.weatherTurnsBad(log: &log)

        XCTAssertEqual(sim.currentWeather.kind, .storm)
        XCTAssertEqual(sim.weatherFrontDaysRemainingForTesting, 2)
        XCTAssertTrue(log[0].contains("squall"))
    }
}
