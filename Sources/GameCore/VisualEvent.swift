/// A typed, deterministic description of the latest event that has a visual
/// treatment. Presentation layers can render this without parsing event-log text.
public enum VisualEvent: Equatable, Sendable {
    case illness(memberName: String, ailment: Ailment)
    case hunt(HuntOutcome)
    case trailOpportunity(TrailOpportunityItem)
    case wolves(oxLost: Bool)
    case wagonBreakdown(part: WagonPart, repaired: Bool)
    case snakebite(SnakebiteOutcome)
    case spring
    case regionalTrade
    case weatherWorsening
    case ambient(AmbientMoment)
    case riverCrossing(landmarkName: String, outcome: RiverCrossingOutcome)
}

public enum HuntOutcome: Equatable, Sendable {
    case success(meatPounds: Int)
    case noAmmunition
}

public enum TrailOpportunityItem: Equatable, Sendable {
    case food(pounds: Int)
    case spareWheel
    case spareAxle
    case clothing
}

public enum WagonPart: Equatable, Sendable {
    case wheel
    case axle
    case tongue
}

public enum SnakebiteOutcome: Equatable, Sendable {
    case struck(memberName: String)
    case missed
}

public enum RiverCrossingOutcome: Equatable, Sendable {
    case success
    case suppliesLost(pounds: Int)
    case travelerLost(name: String)
    case impassable
}

public enum AmbientMoment: Equatable, Sendable {
    case prairieGrass
    case buffaloHerd
    case cottonwoodLeaves
    case fallingStone
    case longShadows
    case lowClouds
    case rainTracks
    case lightning
    case snowRuts
    case heatShimmer
    case frostGrass
}
