import AppKit
import CanopyCore
import Foundation

/// Generates an original three-note whoop and comic impact locally. No sampled
/// or third-party character audio is bundled with Cornerworld.
@MainActor
final class CanopySoundPlayer {
    private lazy var cleanWhoop = NSSound(data: Self.waveData(kind: .clean))
    private lazy var impactWhoop = NSSound(data: Self.waveData(kind: .impact))

    func play(_ event: CanopyVisualEvent?) {
        guard case .swing(let outcome)? = event else { return }
        switch outcome {
        case .clean:
            cleanWhoop?.stop()
            cleanWhoop?.play()
        case .wallImpact:
            impactWhoop?.stop()
            impactWhoop?.play()
        }
    }

    private enum SoundKind {
        case clean
        case impact
    }

    private static func waveData(kind: SoundKind) -> Data {
        let sampleRate = 22_050
        let duration = kind == .clean ? 0.92 : 1.18
        let count = Int(Double(sampleRate) * duration)
        var noiseState: UInt32 = 0xC0A0_1993
        var samples: [Int16] = []
        samples.reserveCapacity(count)

        for index in 0..<count {
            let time = Double(index) / Double(sampleRate)
            let sample: Double
            if kind == .impact, time > 0.78 {
                let impactTime = time - 0.78
                noiseState = noiseState &* 1_664_525 &+ 1_013_904_223
                let noise = Double(Int32(bitPattern: noiseState)) / Double(Int32.max)
                let envelope = max(0, 1 - impactTime / 0.34)
                sample = (sin(2 * .pi * 105 * impactTime) * 0.68 + noise * 0.18) * envelope
            } else {
                let whoopDuration = kind == .clean ? duration : 0.72
                let progress = min(1, time / whoopDuration)
                let frequency: Double
                switch progress {
                case 0..<0.34:
                    frequency = 330 + progress / 0.34 * 250
                case 0.34..<0.68:
                    frequency = 580 + (progress - 0.34) / 0.34 * 170
                default:
                    frequency = 750 - (progress - 0.68) / 0.32 * 260
                }
                let envelope = sin(.pi * progress)
                let fundamental = sin(2 * .pi * frequency * time)
                let harmonic = sin(2 * .pi * frequency * 2.01 * time) * 0.22
                sample = (fundamental + harmonic) * envelope * 0.62
            }
            let clamped = max(-1, min(1, sample))
            samples.append(Int16(clamped * Double(Int16.max)))
        }

        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        appendUInt32(UInt32(36 + samples.count * 2), to: &data)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        appendUInt32(16, to: &data)
        appendUInt16(1, to: &data)
        appendUInt16(1, to: &data)
        appendUInt32(UInt32(sampleRate), to: &data)
        appendUInt32(UInt32(sampleRate * 2), to: &data)
        appendUInt16(2, to: &data)
        appendUInt16(16, to: &data)
        data.append(contentsOf: Array("data".utf8))
        appendUInt32(UInt32(samples.count * 2), to: &data)
        for sample in samples {
            appendUInt16(UInt16(bitPattern: sample), to: &data)
        }
        return data
    }

    private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 24) & 0xFF))
    }
}
