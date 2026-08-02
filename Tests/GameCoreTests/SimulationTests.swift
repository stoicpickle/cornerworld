import XCTest
@testable import GameCore

final class SimulationTests: XCTestCase {

    func testDeterministicRuns() {
        let a = Simulation(seed: 42)
        let b = Simulation(seed: 42)

        while !a.isFinished { a.tick() }
        while !b.isFinished { b.tick() }

        XCTAssertEqual(a.day, b.day)
        XCTAssertEqual(a.outcome, b.outcome)
        XCTAssertEqual(a.eventLog, b.eventLog)
    }

    func testDifferentSeedsDiffer() {
        let a = Simulation(seed: 42)
        let b = Simulation(seed: 43)

        while !a.isFinished { a.tick() }
        while !b.isFinished { b.tick() }

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
        let mountain = Simulation(seed: 1, supplies: Supplies(), milesTraveled: 900)
        var mountainLog: [String] = []
        mountain.regionalTrade(log: &mountainLog)
        XCTAssertEqual(mountain.milesTraveled, 905)
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
}
