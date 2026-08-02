public struct Supplies {
    public var foodPounds: Int
    public var oxen: Int
    public var ammunition: Int
    public var clothingSets: Int
    public var spareWheels: Int
    public var spareAxles: Int
    public var spareTongues: Int
    public var cash: Int

    public init(
        foodPounds: Int = 850,
        oxen: Int = 5,
        ammunition: Int = 350,
        clothingSets: Int = 4,
        spareWheels: Int = 2,
        spareAxles: Int = 2,
        spareTongues: Int = 1,
        cash: Int = 160
    ) {
        self.foodPounds = foodPounds
        self.oxen = oxen
        self.ammunition = ammunition
        self.clothingSets = clothingSets
        self.spareWheels = spareWheels
        self.spareAxles = spareAxles
        self.spareTongues = spareTongues
        self.cash = cash
    }
}

public enum Ration {
    case filling
    case meager
    case bareBones

    public var poundsPerPersonPerDay: Int {
        switch self {
        case .filling: return 3
        case .meager: return 2
        case .bareBones: return 1
        }
    }

    public var name: String {
        switch self {
        case .filling: return "filling"
        case .meager: return "meager"
        case .bareBones: return "bare bones"
        }
    }
}

public enum Pace {
    case steady
    case moderate
    case slow

    public var milesPerDayBonus: Int {
        switch self {
        case .steady: return 3
        case .moderate: return 0
        case .slow: return -2
        }
    }

    public var name: String {
        switch self {
        case .steady: return "steady"
        case .moderate: return "moderate"
        case .slow: return "slow"
        }
    }
}
