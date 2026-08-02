public enum Terrain: Sendable {
    case prairie
    case plains
    case river
    case mountains
}

public struct Landmark: Sendable {
    public let name: String
    public let distance: Int
    public let terrain: Terrain
    public let requiresRiverCrossing: Bool

    public init(
        name: String,
        distance: Int,
        terrain: Terrain,
        requiresRiverCrossing: Bool = false
    ) {
        self.name = name
        self.distance = distance
        self.terrain = terrain
        self.requiresRiverCrossing = requiresRiverCrossing
    }
}

public enum Trail: Sendable {
    public static let totalMiles = 2040

    public static let landmarks: [Landmark] = [
        Landmark(name: "Independence", distance: 0, terrain: .prairie),
        Landmark(name: "Fort Kearney", distance: 320, terrain: .prairie),
        Landmark(name: "Fort Laramie", distance: 640, terrain: .plains),
        Landmark(name: "Independence Rock", distance: 820, terrain: .plains),
        Landmark(name: "South Pass", distance: 890, terrain: .mountains),
        Landmark(name: "Fort Bridger", distance: 1030, terrain: .mountains),
        Landmark(name: "Fort Hall", distance: 1320, terrain: .plains),
        Landmark(name: "Fort Boise", distance: 1610, terrain: .plains),
        Landmark(name: "Fort Walla Walla", distance: 1890, terrain: .river, requiresRiverCrossing: true),
        Landmark(name: "Oregon City", distance: 2040, terrain: .river),
    ]

    public static func landmark(at miles: Int) -> Landmark? {
        landmarks.last { $0.distance <= miles }
    }

    public static func nextLandmark(after miles: Int) -> Landmark? {
        landmarks.first { $0.distance > miles }
    }

    public static func terrain(at miles: Int) -> Terrain {
        landmark(at: miles)?.terrain ?? .prairie
    }
}
