import Foundation

public enum FarmClockMode: Int, CaseIterable, Equatable, Sendable {
    case brisk
    case ambient
    case slow
    case verySlow
    case paused

    public var title: String {
        switch self {
        case .brisk: "Brisk"
        case .ambient: "Ambient"
        case .slow: "Slow"
        case .verySlow: "Very slow"
        case .paused: "Paused"
        }
    }

    public var menuTitle: String {
        switch self {
        case .brisk: "Brisk — about 3½ min/year"
        case .ambient: "Ambient — about 10 min/year"
        case .slow: "Slow — about 26 min/year"
        case .verySlow: "Very slow — about 52 min/year"
        case .paused: "Paused"
        }
    }

    public var weekInterval: TimeInterval? {
        switch self {
        case .brisk: 4
        case .ambient: 12
        case .slow: 30
        case .verySlow: 60
        case .paused: nil
        }
    }

    public var nominalYearDuration: TimeInterval? {
        weekInterval.map { $0 * 52 }
    }
}

public struct FarmClockSchedule: Equatable, Sendable {
    public static let acceleratedDelay: TimeInterval = 0.05
    public static let minimumEventDisplay: TimeInterval = 7

    public let accelerated: Bool

    public init(accelerated: Bool) {
        self.accelerated = accelerated
    }

    public func delay(
        for mode: FarmClockMode,
        showingVisualEvent: Bool
    ) -> TimeInterval? {
        guard let interval = mode.weekInterval else { return nil }
        if accelerated { return Self.acceleratedDelay }
        return showingVisualEvent ? max(interval, Self.minimumEventDisplay) : interval
    }

    public func tolerance(for delay: TimeInterval) -> TimeInterval {
        accelerated ? 0 : delay * 0.1
    }
}
