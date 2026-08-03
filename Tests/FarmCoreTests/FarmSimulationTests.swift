import XCTest
@testable import FarmCore

final class FarmSimulationTests: XCTestCase {
    private func finishedSimulation(
        seed: UInt64,
        plan: FarmPlan
    ) -> FarmSimulation {
        var simulation = FarmSimulation(seed: seed, plan: plan)
        for _ in 0..<52 {
            guard !simulation.isFinished else { break }
            simulation.tick()
        }
        XCTAssertTrue(simulation.isFinished, "seed: \(seed), plan: \(plan)")
        XCTAssertEqual(simulation.week, 52, "seed: \(seed), plan: \(plan)")
        return simulation
    }

    func testSameSeedAndPlanProduceTheSameYearLogAndReport() {
        let first = finishedSimulation(seed: 42, plan: .wheat)
        let second = finishedSimulation(seed: 42, plan: .wheat)

        XCTAssertEqual(first.state, second.state)
        XCTAssertEqual(first.eventLog, second.eventLog)
        XCTAssertEqual(first.harvestReport, second.harvestReport)
    }

    func testDifferentSeedsProduceDifferentYears() {
        let first = finishedSimulation(seed: 42, plan: .wheat)
        let second = finishedSimulation(seed: 43, plan: .wheat)

        XCTAssertNotEqual(first.eventLog, second.eventLog)
    }

    func testEveryPlanFinishesAfterExactlyFiftyTwoTicks() {
        for plan in FarmPlan.allCases {
            var simulation = FarmSimulation(seed: 7, plan: plan)
            var tickCount = 0

            while !simulation.isFinished, tickCount < 53 {
                simulation.tick()
                tickCount += 1
            }

            XCTAssertTrue(simulation.isFinished, "plan: \(plan)")
            XCTAssertEqual(tickCount, 52, "plan: \(plan)")
            XCTAssertEqual(simulation.week, 52, "plan: \(plan)")
            XCTAssertNotNil(simulation.outcome, "plan: \(plan)")
        }
    }

    func testFieldPlansProduceTheirPromisedTradeoffs() throws {
        let seed: UInt64 = 19
        let wheat = finishedSimulation(seed: seed, plan: .wheat)
        let beans = finishedSimulation(seed: seed, plan: .beans)
        let fallow = finishedSimulation(seed: seed, plan: .fallow)

        let wheatReport = try XCTUnwrap(wheat.harvestReport)
        let beansReport = try XCTUnwrap(beans.harvestReport)
        let fallowReport = try XCTUnwrap(fallow.harvestReport)

        XCTAssertGreaterThan(wheatReport.cashGained, beansReport.cashGained)
        XCTAssertGreaterThan(wheatReport.totalYield, beansReport.totalYield)

        XCTAssertGreaterThan(beansReport.soilChange, 0)
        XCTAssertGreaterThan(beans.soilQuality, wheat.soilQuality)

        XCTAssertEqual(fallowReport.totalYield, 0)
        XCTAssertEqual(fallowReport.foodGained, 0)
        XCTAssertEqual(fallowReport.cashGained, 0)
        XCTAssertGreaterThan(fallowReport.soilChange, beansReport.soilChange)
        XCTAssertGreaterThan(fallow.soilQuality, beans.soilQuality)
    }

    func testSameSeedGivesEveryPlanTheSameWeatherYear() {
        func weatherYear(for plan: FarmPlan) -> [FarmWeather] {
            var simulation = FarmSimulation(seed: 1_848, plan: plan)
            var weather: [FarmWeather] = []
            while !simulation.isFinished {
                simulation.tick()
                if let current = simulation.currentWeather {
                    weather.append(current)
                }
            }
            return weather
        }

        let wheat = weatherYear(for: .wheat)
        XCTAssertEqual(weatherYear(for: .beans), wheat)
        XCTAssertEqual(weatherYear(for: .fallow), wheat)
        XCTAssertEqual(wheat.count, 52)
    }

    func testWeatherCanProduceStableAndStrainedCropYears() {
        func outcomes(for plan: FarmPlan) -> Set<FarmOutcome> {
            Set((UInt64(0)..<50).compactMap { seed in
                finishedSimulation(seed: seed, plan: plan).outcome
            })
        }

        XCTAssertEqual(outcomes(for: .wheat), [.stable, .strained])
        XCTAssertEqual(outcomes(for: .beans), [.stable, .strained])
    }

    func testEveryAuthoredOutcomeIsReachable() {
        let outcomes = Set(
            FarmPlan.allCases.flatMap { plan in
                (UInt64(0)..<100).compactMap { seed in
                    finishedSimulation(seed: seed, plan: plan).outcome
                }
            }
        )

        XCTAssertEqual(outcomes, [.stable, .strained, .debt])
    }

    func testResourcesRemainWithinTheirDomainAcrossManySeeds() {
        for seed in UInt64(0)..<100 {
            for plan in FarmPlan.allCases {
                var simulation = FarmSimulation(seed: seed, plan: plan)

                while !simulation.isFinished {
                    simulation.tick()

                    XCTAssertTrue(
                        (0...100).contains(simulation.soilQuality),
                        "soil, seed: \(seed), plan: \(plan), week: \(simulation.week)"
                    )
                    XCTAssertTrue(
                        (0...100).contains(simulation.moisture),
                        "moisture, seed: \(seed), plan: \(plan), week: \(simulation.week)"
                    )
                    XCTAssertTrue(
                        (0...100).contains(simulation.buildingCondition),
                        "building, seed: \(seed), plan: \(plan), week: \(simulation.week)"
                    )
                    XCTAssertTrue(
                        (0...100).contains(simulation.cropGrowth),
                        "growth, seed: \(seed), plan: \(plan), week: \(simulation.week)"
                    )
                    XCTAssertGreaterThanOrEqual(
                        simulation.storedFood,
                        0,
                        "food, seed: \(seed), plan: \(plan), week: \(simulation.week)"
                    )
                    XCTAssertGreaterThanOrEqual(
                        simulation.cash,
                        0,
                        "cash, seed: \(seed), plan: \(plan), week: \(simulation.week)"
                    )
                }
            }
        }
    }

    func testSeasonBoundariesAndCropStagesAdvanceThroughTheYear() {
        var simulation = FarmSimulation(seed: 7, plan: .wheat)
        var observedStages = [simulation.cropStage]

        for expectedWeek in 1...52 {
            simulation.tick()
            observedStages.append(simulation.cropStage)

            XCTAssertEqual(simulation.week, expectedWeek)
            switch expectedWeek {
            case 1...13:
                XCTAssertEqual(simulation.season, .spring)
                XCTAssertEqual(simulation.weekOfSeason, expectedWeek)
            case 14...26:
                XCTAssertEqual(simulation.season, .summer)
                XCTAssertEqual(simulation.weekOfSeason, expectedWeek - 13)
            case 27...39:
                XCTAssertEqual(simulation.season, .autumn)
                XCTAssertEqual(simulation.weekOfSeason, expectedWeek - 26)
            default:
                XCTAssertEqual(simulation.season, .winter)
                XCTAssertEqual(simulation.weekOfSeason, expectedWeek - 39)
            }
        }

        for stage in [CropStage.bare, .sown, .sprouting, .growing] {
            XCTAssertTrue(observedStages.contains(stage), "missing crop stage: \(stage)")
        }
        XCTAssertTrue(observedStages.contains(.mature))
        XCTAssertTrue(observedStages.contains(.harvested))
        XCTAssertEqual(simulation.cropStage, .resting)
    }

    func testTickAfterYearFinishesIsANoOp() {
        var simulation = finishedSimulation(seed: 91, plan: .beans)
        let finishedState = simulation.state

        let messages = simulation.tick()

        XCTAssertTrue(messages.isEmpty)
        XCTAssertEqual(simulation.state, finishedState)
    }

    func testHarvestReportReconcilesItsYieldAndExplainsTheResult() throws {
        for plan in FarmPlan.allCases {
            let simulation = finishedSimulation(seed: 33, plan: plan)
            let report = try XCTUnwrap(simulation.harvestReport)
            let calculatedYield = max(
                0,
                report.baseYield
                    + report.growthContribution
                    + report.soilContribution
                    + report.moistureContribution
                    - report.damagePenalty
            )

            XCTAssertEqual(report.plan, plan)
            XCTAssertEqual(report.totalYield, calculatedYield)
            XCTAssertFalse(report.summary.isEmpty)
            XCTAssertTrue(report.summary.contains("max(0,"))
            XCTAssertTrue(
                report.summary.contains(String(report.totalYield)),
                "summary should name the resulting yield: \(report.summary)"
            )
        }
    }

    func testRepairEventsAlwaysRestoreSomethingForTheFullCost() {
        var sawRepair = false

        for seed in UInt64(0)..<100 {
            var simulation = FarmSimulation(seed: seed, plan: .fallow)
            while !simulation.isFinished {
                for message in simulation.tick() where message.contains("clear repair day") {
                    sawRepair = true
                    XCTAssertFalse(message.contains("restored 0"), "seed: \(seed)")
                    XCTAssertTrue(message.hasSuffix("for $2."), "seed: \(seed): \(message)")
                }
            }
        }

        XCTAssertTrue(sawRepair)
    }

    func testFallowFieldNeverClaimsToBeHarvested() {
        var simulation = FarmSimulation(seed: 1_848, plan: .fallow)

        while !simulation.isFinished {
            simulation.tick()
            XCTAssertNotEqual(simulation.cropStage, .harvested)
        }

        XCTAssertNotNil(simulation.harvestReport)
        XCTAssertEqual(simulation.cropStage, .resting)
    }

    func testEveryFarmVisualEventIsReachableAcrossSeededYears() {
        var observed: Set<String> = []

        for seed in UInt64(0)..<250 {
            for plan in FarmPlan.allCases {
                var simulation = FarmSimulation(seed: seed, plan: plan)
                while !simulation.isFinished {
                    simulation.tick()
                    if let event = simulation.latestVisualEvent {
                        observed.insert(eventKey(event))
                    }
                }
            }
        }

        XCTAssertEqual(observed, [
            "weeds", "crows", "deer", "neighbor", "wind",
            "repair", "harvest", "yearEnd",
        ])
    }

    func testFarmVisualEventsStayAlignedWithTheDisplayedMessage() {
        var matched: Set<String> = []

        for seed in UInt64(0)..<100 {
            for plan in FarmPlan.allCases {
                var simulation = FarmSimulation(seed: seed, plan: plan)
                while !simulation.isFinished {
                    let messages = simulation.tick()
                    guard let event = simulation.latestVisualEvent else { continue }
                    let message = messages.last ?? ""
                    XCTAssertTrue(
                        visualEvent(event, matches: message),
                        "event \(event) did not match final message: \(message)"
                    )
                    matched.insert(eventKey(event))
                }
            }
        }

        XCTAssertEqual(matched, [
            "weeds", "crows", "deer", "neighbor", "wind",
            "repair", "harvest", "yearEnd",
        ])
    }

    func testFarmVisualEventContractIsEquatableAndSendable() {
        func requireSendable<T: Sendable>(_: T.Type) {}
        requireSendable(FarmVisualEvent.self)

        XCTAssertEqual(FarmVisualEvent.weeds, .weeds)
        XCTAssertNotEqual(FarmVisualEvent.weeds, .crows)
        XCTAssertEqual(
            FarmVisualEvent.harvest(plan: .beans, totalYield: 31),
            .harvest(plan: .beans, totalYield: 31)
        )
    }

    func testFarmVisualEventClearsOnAQuietWeek() {
        var simulation = FarmSimulation(seed: 7, plan: .wheat)
        var sawEvent = false
        var sawQuietWeekAfterEvent = false

        while !simulation.isFinished {
            simulation.tick()
            if simulation.latestVisualEvent != nil {
                sawEvent = true
            } else if sawEvent {
                sawQuietWeekAfterEvent = true
                break
            }
        }

        XCTAssertTrue(sawEvent)
        XCTAssertTrue(sawQuietWeekAfterEvent)
    }

    private func eventKey(_ event: FarmVisualEvent) -> String {
        switch event {
        case .weeds: "weeds"
        case .crows: "crows"
        case .deer: "deer"
        case .neighborProvisions: "neighbor"
        case .windDamage: "wind"
        case .repairDay: "repair"
        case .harvest: "harvest"
        case .yearEnd: "yearEnd"
        }
    }

    private func visualEvent(_ event: FarmVisualEvent, matches message: String) -> Bool {
        switch event {
        case .weeds: message.contains("Weeds crowded")
        case .crows: message.contains("Crows dropped")
        case .deer: message.contains("Deer watched")
        case .neighborProvisions: message.contains("neighbor left")
        case .windDamage: message.contains("hard wind bent")
        case .repairDay: message.contains("clear repair day")
        case .harvest: message.contains("Harvest")
        case .yearEnd: message.contains("farm ends the year")
        }
    }
}
