public struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    public mutating func int(in range: ClosedRange<Int>) -> Int {
        precondition(range.lowerBound <= range.upperBound)
        let signBit = UInt(1) << (UInt.bitWidth - 1)
        let lower = UInt(bitPattern: range.lowerBound) ^ signBit
        let upper = UInt(bitPattern: range.upperBound) ^ signBit
        let span = upper &- lower &+ 1

        let offset: UInt
        if span == 0 {
            offset = UInt(truncatingIfNeeded: next())
        } else {
            let unsignedSpan = UInt64(span)
            let limit = UInt64.max - (UInt64.max % unsignedSpan)
            var value = next()
            while value >= limit {
                value = next()
            }
            offset = UInt(value % unsignedSpan)
        }
        return Int(bitPattern: (lower &+ offset) ^ signBit)
    }

    public mutating func double(in range: ClosedRange<Double>) -> Double {
        precondition(range.lowerBound <= range.upperBound)
        let unit = Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
        return range.lowerBound * (1 - unit) + range.upperBound * unit
    }

    public mutating func index(count: Int) -> Int? {
        guard count > 0 else { return nil }
        return int(in: 0...(count - 1))
    }

    public mutating func chance(_ probability: Double) -> Bool {
        precondition((0...1).contains(probability))
        return double(in: 0...1) < probability
    }
}
