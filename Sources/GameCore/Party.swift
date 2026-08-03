public struct PartyMember {
    public let name: String
    public var health: Int
    public var isAlive: Bool
    public var ailment: Ailment?
    public var daysIll: Int
    public var causeOfDeath: String?

    public init(
        name: String,
        health: Int = 100,
        isAlive: Bool = true,
        ailment: Ailment? = nil,
        daysIll: Int = 0,
        causeOfDeath: String? = nil
    ) {
        self.name = name
        self.health = health
        self.isAlive = isAlive
        self.ailment = ailment
        self.daysIll = daysIll
        self.causeOfDeath = causeOfDeath
    }

    public var isIll: Bool {
        ailment != nil
    }
}

public enum Ailment: String, Equatable, Sendable {
    case dysentery
    case cholera
    case typhoid
    case measles
    case snakebite
    case exhaustion
    case injury
}

public struct Party {
    public var members: [PartyMember]

    public init(members: [PartyMember]) {
        self.members = members
    }

    public static func defaultParty() -> Party {
        Party(members: [
            PartyMember(name: "Benjamin"),
            PartyMember(name: "Mary"),
            PartyMember(name: "Eliza"),
            PartyMember(name: "Jake"),
            PartyMember(name: "Ruth"),
        ])
    }

    public var aliveCount: Int {
        members.filter(\.isAlive).count
    }

    public var isAllDead: Bool {
        aliveCount == 0
    }

    public var averageHealth: Double {
        let alive = members.filter(\.isAlive)
        guard !alive.isEmpty else { return 0 }
        return Double(alive.map(\.health).reduce(0, +)) / Double(alive.count)
    }
}
