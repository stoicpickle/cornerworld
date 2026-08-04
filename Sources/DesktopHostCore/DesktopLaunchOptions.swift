import FarmCore
import GameCore

public enum DesktopWorld: String, Equatable, Sendable {
    case overland
    case farm
    case canopy
}

public enum DesktopLaunchCommand: Equatable, Sendable {
    case run
    case help
    case version
    case captureFarmFixtures(directory: String)
    case captureCanopyFixtures(directory: String)
    case captureMenuBarFixtures(directory: String)
}

public enum DesktopLaunchError: Error, Equatable, Sendable, CustomStringConvertible {
    case missingWorld
    case invalidWorld(String)
    case missingSeed
    case invalidSeed(String)
    case missingPlan
    case invalidPlan(String)
    case missingFixtureDirectory
    case missingCanopyFixtureDirectory
    case missingMenuBarFixtureDirectory
    case fixtureCaptureMustBeStandalone
    case planRequiresFarm
    case unknownOption(String)

    public var description: String {
        switch self {
        case .missingWorld:
            "--world requires overland, farm, or canopy"
        case .invalidWorld(let value):
            "--world requires overland, farm, or canopy, not '\(value)'"
        case .missingSeed:
            "--seed requires a decimal or 0x-prefixed hexadecimal value"
        case .invalidSeed(let value):
            "--seed requires a decimal or 0x-prefixed hexadecimal value, not '\(value)'"
        case .missingPlan:
            "--plan requires wheat, beans, or fallow"
        case .invalidPlan(let value):
            "--plan requires wheat, beans, or fallow, not '\(value)'"
        case .missingFixtureDirectory:
            "--capture-farm-fixtures requires an output directory"
        case .missingCanopyFixtureDirectory:
            "--capture-canopy-fixtures requires an output directory"
        case .missingMenuBarFixtureDirectory:
            "--capture-menu-bar-fixtures requires an output directory"
        case .fixtureCaptureMustBeStandalone:
            "fixture capture cannot be combined with another capture option or with world run options"
        case .planRequiresFarm:
            "--plan is only available with --world farm"
        case .unknownOption(let option):
            "unknown option '\(option)'; use --help"
        }
    }
}

public struct DesktopLaunchOptions: Equatable, Sendable {
    public private(set) var world: DesktopWorld
    public private(set) var seed: UInt64?
    public private(set) var farmPlan: FarmPlan
    public private(set) var fast: Bool
    public private(set) var command: DesktopLaunchCommand

    public init(arguments: [String]) throws {
        world = .overland
        seed = nil
        farmPlan = .wheat
        fast = false
        command = .run

        var suppliedPlan = false
        var suppliedRunOption = false
        var suppliedFixtureCapture = false
        var index = 0
        while index < arguments.count {
            switch arguments[index] {
            case "--world":
                index += 1
                guard index < arguments.count else { throw DesktopLaunchError.missingWorld }
                let value = arguments[index].lowercased()
                guard let parsed = DesktopWorld(rawValue: value) else {
                    throw DesktopLaunchError.invalidWorld(arguments[index])
                }
                world = parsed
                suppliedRunOption = true
            case "--seed":
                index += 1
                guard index < arguments.count else { throw DesktopLaunchError.missingSeed }
                guard let parsed = SeedCodec.parse(arguments[index]) else {
                    throw DesktopLaunchError.invalidSeed(arguments[index])
                }
                seed = parsed
                suppliedRunOption = true
            case "--plan":
                index += 1
                guard index < arguments.count else { throw DesktopLaunchError.missingPlan }
                guard let parsed = FarmPlan(rawValue: arguments[index].lowercased()) else {
                    throw DesktopLaunchError.invalidPlan(arguments[index])
                }
                farmPlan = parsed
                suppliedPlan = true
                suppliedRunOption = true
            case "--fast":
                fast = true
                suppliedRunOption = true
            case "--capture-farm-fixtures":
                guard !suppliedFixtureCapture else {
                    throw DesktopLaunchError.fixtureCaptureMustBeStandalone
                }
                index += 1
                guard index < arguments.count,
                      !arguments[index].isEmpty,
                      !arguments[index].hasPrefix("--") else {
                    throw DesktopLaunchError.missingFixtureDirectory
                }
                command = .captureFarmFixtures(directory: arguments[index])
                suppliedFixtureCapture = true
            case "--capture-canopy-fixtures":
                guard !suppliedFixtureCapture else {
                    throw DesktopLaunchError.fixtureCaptureMustBeStandalone
                }
                index += 1
                guard index < arguments.count,
                      !arguments[index].isEmpty,
                      !arguments[index].hasPrefix("--") else {
                    throw DesktopLaunchError.missingCanopyFixtureDirectory
                }
                command = .captureCanopyFixtures(directory: arguments[index])
                suppliedFixtureCapture = true
            case "--capture-menu-bar-fixtures":
                guard !suppliedFixtureCapture else {
                    throw DesktopLaunchError.fixtureCaptureMustBeStandalone
                }
                index += 1
                guard index < arguments.count,
                      !arguments[index].isEmpty,
                      !arguments[index].hasPrefix("--") else {
                    throw DesktopLaunchError.missingMenuBarFixtureDirectory
                }
                command = .captureMenuBarFixtures(directory: arguments[index])
                suppliedFixtureCapture = true
            case "--help", "-h":
                command = .help
                return
            case "--version":
                command = .version
                return
            default:
                throw DesktopLaunchError.unknownOption(arguments[index])
            }
            index += 1
        }

        if suppliedFixtureCapture, suppliedRunOption {
            throw DesktopLaunchError.fixtureCaptureMustBeStandalone
        }
        if suppliedPlan, world != .farm, command == .run {
            throw DesktopLaunchError.planRequiresFarm
        }
    }
}
