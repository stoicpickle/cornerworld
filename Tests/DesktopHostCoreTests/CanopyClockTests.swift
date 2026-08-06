import XCTest
@testable import DesktopHostCore

final class CanopyClockTests: XCTestCase {
    func testGrowthModesHaveDistinctIntervals() {
        XCTAssertEqual(CanopyClockMode.defaultMode, .gentle)
        XCTAssertEqual(CanopyClockMode.gentle.interval, 15)
        XCTAssertEqual(CanopyClockMode.active.interval, 8)
        XCTAssertEqual(CanopyClockMode.wild.interval, 3)
        XCTAssertNil(CanopyClockMode.paused.interval)
    }

    func testWildModeHoldsEventsLongEnoughToSeeAndHear() {
        let schedule = CanopyClockSchedule(accelerated: false)
        XCTAssertEqual(schedule.delay(for: .wild, showingVisualEvent: false), 3)
        XCTAssertEqual(schedule.delay(for: .wild, showingVisualEvent: true), 8)
        XCTAssertEqual(schedule.delay(for: .active, showingVisualEvent: true), 8)
    }

    func testAcceleratedModeAndTolerance() {
        let normal = CanopyClockSchedule(accelerated: false)
        let fast = CanopyClockSchedule(accelerated: true)
        XCTAssertEqual(normal.tolerance(for: 8), 0.8, accuracy: 0.000_1)
        XCTAssertEqual(fast.tolerance(for: 0.06), 0)
        XCTAssertEqual(fast.delay(for: .gentle, showingVisualEvent: true), 0.06)
        XCTAssertNil(fast.delay(for: .paused, showingVisualEvent: false))
    }
}
