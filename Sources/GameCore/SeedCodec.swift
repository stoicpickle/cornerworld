import Foundation

public enum SeedCodec {
    public static func parse(_ text: String) -> UInt64? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X") {
            return UInt64(trimmed.dropFirst(2), radix: 16)
        }
        return UInt64(trimmed, radix: 10)
    }

    public static func display(_ seed: UInt64) -> String {
        "0x" + String(seed, radix: 16, uppercase: true)
    }
}
