public struct Weather {
    public enum Kind: String {
        case clear
        case overcast
        case rain
        case storm
        case snow
        case heatwave
        case coldSnap

        public var lofiDescription: String {
            switch self {
            case .clear: "The sky is clear and still."
            case .overcast: "Low gray clouds press down on the plain."
            case .rain: "A soft rain patters against the canvas."
            case .storm: "Thunder rolls across the prairie."
            case .snow: "Snow drifts slowly over the wagon tracks."
            case .heatwave: "Heat shimmers off the dried grass."
            case .coldSnap: "A sharp wind cuts through the wagon."
            }
        }
    }

    public var kind: Kind
    public var speedFactor: Double

    public static func roll(month: Int, rng: inout SplitMix64) -> Weather {
        let roll = rng.double(in: 0...1)
        let kind: Kind
        if month <= 3 || month >= 11 {
            kind = roll < 0.4 ? .clear : (roll < 0.55 ? .overcast : (roll < 0.75 ? .rain : (roll < 0.85 ? .storm : .snow)))
        } else if month >= 6 && month <= 8 {
            kind = roll < 0.5 ? .clear : (roll < 0.7 ? .overcast : (roll < 0.85 ? .rain : (roll < 0.93 ? .storm : .heatwave)))
        } else {
            kind = roll < 0.45 ? .clear : (roll < 0.7 ? .overcast : (roll < 0.85 ? .rain : (roll < 0.95 ? .storm : .coldSnap)))
        }

        let factor: Double
        switch kind {
        case .clear: factor = 1.0
        case .overcast: factor = 0.95
        case .rain: factor = 0.85
        case .storm: factor = 0.6
        case .snow: factor = 0.4
        case .heatwave: factor = 0.8
        case .coldSnap: factor = 0.7
        }

        return Weather(kind: kind, speedFactor: factor)
    }
}
