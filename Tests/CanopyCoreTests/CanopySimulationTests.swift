import XCTest
@testable import CanopyCore

final class CanopySimulationTests: XCTestCase {
    func testSameSeedProducesTheSameGrowingWorld() {
        var first = CanopySimulation(seed: 1_993)
        var second = CanopySimulation(seed: 1_993)

        for _ in 0..<160 {
            first.tick()
            second.tick()
        }

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.eventLog, second.eventLog)
    }

    func testVinesGrowVerticallyWithinTheWorldBounds() {
        var simulation = CanopySimulation(seed: 42)
        let initialHeight = simulation.vines.reduce(0) { $0 + $1.height }

        for _ in 0..<200 { simulation.tick() }

        XCTAssertGreaterThan(simulation.vines.reduce(0) { $0 + $1.height }, initialHeight)
        XCTAssertLessThanOrEqual(simulation.vines.count, CanopySimulation.maximumVines)
        for vine in simulation.vines {
            XCTAssertTrue((18...302).contains(vine.baseX))
            XCTAssertTrue((0...CanopySimulation.maximumVineHeight).contains(vine.height))
        }
        XCTAssertTrue((0...100).contains(simulation.density))
    }

    func testSwingCadenceIncludesCleanPassesAndOccasionalWallImpacts() {
        var simulation = CanopySimulation(seed: 7)
        var outcomes: [CanopySwingOutcome] = []

        while outcomes.count < 12 {
            simulation.tick()
            if case .swing(let outcome)? = simulation.latestVisualEvent {
                outcomes.append(outcome)
            }
        }

        let impacts = outcomes.filter {
            if case .wallImpact = $0 { return true }
            return false
        }
        XCTAssertEqual(impacts.count, 3)
        for pair in zip(outcomes, outcomes.dropFirst()) {
            if case .wallImpact = pair.0, case .wallImpact = pair.1 {
                XCTFail("wall impacts should not happen consecutively")
            }
        }
    }

    func testEveryVisualEventIsReachableAndMatchesTheLatestMessage() {
        var observed: Set<String> = []
        for seed in UInt64(0)..<100 {
            var simulation = CanopySimulation(seed: seed)
            for _ in 0..<180 {
                let messages = simulation.tick()
                guard let event = simulation.latestVisualEvent else { continue }
                observed.insert(key(event))
                XCTAssertTrue(matches(event, message: messages.last ?? ""))
            }
        }

        XCTAssertEqual(observed, ["rain", "bloom", "bird", "clean", "impact"])
    }

    func testPruningReducesDensityAndKeepsTheWorldAlive() {
        var simulation = CanopySimulation(seed: 11)
        for _ in 0..<120 { simulation.tick() }
        let oldDensity = simulation.density

        let message = simulation.prune()

        XCTAssertLessThan(simulation.density, oldDensity)
        XCTAssertEqual(simulation.latestVisualEvent, .pruned)
        XCTAssertTrue(message.contains("pruned"))
        XCTAssertTrue(simulation.vines.allSatisfy { $0.height >= 8 })
    }

    func testEventLogKeepsOnlyRecentEntriesIncludingPruning() {
        var simulation = CanopySimulation(seed: 1_993)
        for _ in 0..<1_000 { simulation.tick() }

        XCTAssertEqual(simulation.eventLog.count, CanopySimulation.eventLogLimit)

        let pruneMessage = simulation.prune()
        XCTAssertEqual(simulation.eventLog.count, CanopySimulation.eventLogLimit)
        XCTAssertEqual(simulation.eventLog.last, pruneMessage)
    }

    func testCollisionMessageNamesTheResolvedEdge() {
        var simulation = CanopySimulation(seed: 7)

        while true {
            let messages = simulation.tick()
            if case .swing(.wallImpact(let side))? = simulation.latestVisualEvent {
                XCTAssertTrue(messages.last?.contains(side.rawValue) == true)
                break
            }
        }
    }

    func testVisualEventContractIsEquatableAndSendable() {
        func requireSendable<T: Sendable>(_: T.Type) {}
        requireSendable(CanopyVisualEvent.self)
        XCTAssertEqual(
            CanopyVisualEvent.swing(.wallImpact(side: .left)),
            .swing(.wallImpact(side: .left))
        )
    }

    private func key(_ event: CanopyVisualEvent) -> String {
        switch event {
        case .rain: "rain"
        case .bloom: "bloom"
        case .bird: "bird"
        case .swing(.clean): "clean"
        case .swing(.wallImpact): "impact"
        case .pruned: "pruned"
        }
    }

    private func matches(_ event: CanopyVisualEvent, message: String) -> Bool {
        switch event {
        case .rain: message.contains("rain")
        case .bloom: message.contains("flower")
        case .bird: message.contains("bird")
        case .swing(.clean): message.contains("whoop")
        case .swing(.wallImpact): message.contains("edge")
        case .pruned: message.contains("pruned")
        }
    }
}
