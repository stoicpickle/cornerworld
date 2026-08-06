import Foundation

public enum CanopyClockMode: Int, CaseIterable, Equatable, Sendable {
    case gentle
    case active
    case wild
    case paused

    public static let defaultMode: Self = .gentle

    public var title: String {
        switch self {
        case .gentle: "Gentle"
        case .active: "Active"
        case .wild: "Wild"
        case .paused: "Paused"
        }
    }

    public var menuTitle: String {
        switch self {
        case .gentle: "Gentle — 15 sec/growth"
        case .active: "Active — 8 sec/growth"
        case .wild: "Wild — 3 sec/growth"
        case .paused: "Paused"
        }
    }

    public var interval: TimeInterval? {
        switch self {
        case .gentle: 15
        case .active: 8
        case .wild: 3
        case .paused: nil
        }
    }
}

public struct CanopyClockSchedule: Equatable, Sendable {
    public static let acceleratedDelay: TimeInterval = 0.06
    public static let minimumEventDisplay: TimeInterval = 8
    public let accelerated: Bool

    public init(accelerated: Bool) {
        self.accelerated = accelerated
    }

    public func delay(for mode: CanopyClockMode, showingVisualEvent: Bool) -> TimeInterval? {
        guard let interval = mode.interval else { return nil }
        if accelerated { return Self.acceleratedDelay }
        return showingVisualEvent ? max(interval, Self.minimumEventDisplay) : interval
    }

    public func tolerance(for delay: TimeInterval) -> TimeInterval {
        accelerated ? 0 : delay * 0.1
    }
}
