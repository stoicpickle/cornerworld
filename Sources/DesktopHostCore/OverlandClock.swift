import Foundation

public enum OverlandClockMode: Int, CaseIterable, Equatable, Sendable {
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
        case .brisk: "Brisk — 2 sec/day"
        case .ambient: "Ambient — 8 sec/day"
        case .slow: "Slow — 20 sec/day"
        case .verySlow: "Very slow — 60 sec/day"
        case .paused: "Paused"
        }
    }

    public var dayInterval: TimeInterval? {
        switch self {
        case .brisk: 2
        case .ambient: 8
        case .slow: 20
        case .verySlow: 60
        case .paused: nil
        }
    }
}

public struct OverlandClockSchedule: Equatable, Sendable {
    public static let acceleratedDelay: TimeInterval = 0.04
    public static let minimumEventDisplay: TimeInterval = 8

    public let accelerated: Bool

    public init(accelerated: Bool) {
        self.accelerated = accelerated
    }

    public func delay(
        for mode: OverlandClockMode,
        showingVisualEvent: Bool
    ) -> TimeInterval? {
        guard let interval = mode.dayInterval else { return nil }
        if accelerated { return Self.acceleratedDelay }
        return showingVisualEvent ? max(interval, Self.minimumEventDisplay) : interval
    }

    public func tolerance(for delay: TimeInterval) -> TimeInterval {
        accelerated ? 0 : delay * 0.1
    }
}
