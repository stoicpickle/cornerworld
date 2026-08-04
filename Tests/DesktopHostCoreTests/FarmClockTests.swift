import XCTest
@testable import DesktopHostCore

final class FarmClockTests: XCTestCase {
    func testModesExposeDistinctHumanScaleYearDurations() throws {
        XCTAssertEqual(FarmClockMode.brisk.nominalYearDuration, 208)
        XCTAssertEqual(FarmClockMode.ambient.nominalYearDuration, 624)
        XCTAssertEqual(FarmClockMode.slow.nominalYearDuration, 1_560)
        XCTAssertEqual(FarmClockMode.verySlow.nominalYearDuration, 3_120)
        XCTAssertNil(FarmClockMode.paused.nominalYearDuration)

        XCTAssertEqual(FarmClockMode.allCases.count, 5)
        XCTAssertTrue(FarmClockMode.ambient.menuTitle.contains("10 min/year"))
        XCTAssertTrue(FarmClockMode.verySlow.menuTitle.contains("52 min/year"))
    }

    func testBriskModeHoldsVisualEventsLongEnoughToRead() {
        let schedule = FarmClockSchedule(accelerated: false)

        XCTAssertEqual(
            schedule.delay(for: .brisk, showingVisualEvent: false),
            4
        )
        XCTAssertEqual(
            schedule.delay(for: .brisk, showingVisualEvent: true),
            FarmClockSchedule.minimumEventDisplay
        )
        XCTAssertEqual(
            schedule.delay(for: .ambient, showingVisualEvent: true),
            12
        )
    }

    func testPausedModeNeverSchedulesAndAcceleratedModeStaysFast() {
        let normal = FarmClockSchedule(accelerated: false)
        let accelerated = FarmClockSchedule(accelerated: true)

        XCTAssertNil(normal.delay(for: .paused, showingVisualEvent: false))
        XCTAssertNil(accelerated.delay(for: .paused, showingVisualEvent: true))
        XCTAssertEqual(
            accelerated.delay(for: .verySlow, showingVisualEvent: true),
            FarmClockSchedule.acceleratedDelay
        )
    }

    func testNormalTimerToleranceIsTenPercentAndFastModeHasNone() {
        let normal = FarmClockSchedule(accelerated: false)
        let accelerated = FarmClockSchedule(accelerated: true)

        XCTAssertEqual(normal.tolerance(for: 12), 1.2, accuracy: 0.000_1)
        XCTAssertEqual(accelerated.tolerance(for: 0.05), 0)
    }
}
