import XCTest
@testable import DesktopHostCore

final class OverlandClockTests: XCTestCase {
    func testModesExposeHumanScaleDayIntervals() {
        XCTAssertEqual(OverlandClockMode.brisk.dayInterval, 2)
        XCTAssertEqual(OverlandClockMode.ambient.dayInterval, 8)
        XCTAssertEqual(OverlandClockMode.slow.dayInterval, 20)
        XCTAssertEqual(OverlandClockMode.verySlow.dayInterval, 60)
        XCTAssertNil(OverlandClockMode.paused.dayInterval)
        XCTAssertEqual(OverlandClockMode.allCases.count, 5)
    }

    func testBriskModeHoldsVisualEventsLongEnoughToRead() {
        let schedule = OverlandClockSchedule(accelerated: false)

        XCTAssertEqual(schedule.delay(for: .brisk, showingVisualEvent: false), 2)
        XCTAssertEqual(
            schedule.delay(for: .brisk, showingVisualEvent: true),
            OverlandClockSchedule.minimumEventDisplay
        )
        XCTAssertEqual(schedule.delay(for: .ambient, showingVisualEvent: true), 8)
    }

    func testPausedModeNeverSchedulesAndAcceleratedModeStaysFast() {
        let normal = OverlandClockSchedule(accelerated: false)
        let accelerated = OverlandClockSchedule(accelerated: true)

        XCTAssertNil(normal.delay(for: .paused, showingVisualEvent: false))
        XCTAssertNil(accelerated.delay(for: .paused, showingVisualEvent: true))
        XCTAssertEqual(
            accelerated.delay(for: .verySlow, showingVisualEvent: true),
            OverlandClockSchedule.acceleratedDelay
        )
    }

    func testNormalTimerToleranceIsTenPercentAndFastModeHasNone() {
        let normal = OverlandClockSchedule(accelerated: false)
        let accelerated = OverlandClockSchedule(accelerated: true)

        XCTAssertEqual(normal.tolerance(for: 8), 0.8, accuracy: 0.000_1)
        XCTAssertEqual(accelerated.tolerance(for: 0.04), 0)
    }
}
