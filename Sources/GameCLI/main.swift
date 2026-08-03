import Foundation
import Darwin
import GameCore

let args = CommandLine.arguments

func printHelp() {
    print("""
    Cornerworld CLI — run the Overland simulation in a terminal.

    Usage:
      cornerworld-cli [--seed NUMBER] [--pause SECONDS] [--fast]
      cornerworld-cli --version

    Options:
      --seed NUMBER    Reproduce a deterministic journey.
      --pause SECONDS  Set the delay between simulated days (default: 0.35).
      --fast           Run with a minimal delay.
      --version        Print the Cornerworld release version.
    """)
}

var seed: UInt64 = UInt64.random(in: 0...UInt64.max)
var pauseSeconds: Double = 0.35

var i = 1
while i < args.count {
    switch args[i] {
    case "--seed":
        i += 1
        guard i < args.count, let parsed = SeedCodec.parse(args[i]) else {
            fputs("cornerworld-cli: --seed requires a decimal or 0x-prefixed hexadecimal value\n", stderr)
            exit(2)
        }
        seed = parsed
    case "--fast":
        pauseSeconds = 0.001
    case "--pause":
        i += 1
        guard i < args.count, let parsed = Double(args[i]), parsed >= 0 else {
            fputs("cornerworld-cli: --pause requires a nonnegative number\n", stderr)
            exit(2)
        }
        pauseSeconds = parsed
    case "--version":
        print("Cornerworld 1.1.0")
        exit(EXIT_SUCCESS)
    case "--help", "-h":
        printHelp()
        exit(EXIT_SUCCESS)
    default:
        fputs("cornerworld-cli: unknown option '\(args[i])'; use --help\n", stderr)
        exit(2)
    }
    i += 1
}

func clearScreen() {
    print("\u{001B}[2J\u{001B}[H")
}

let sim = Simulation(seed: seed)

clearScreen()
print("""
  ┌──────────────────────────────────────────────┐
  │      CORNERWORLD — OVERLAND                   │
  └──────────────────────────────────────────────┘
  seed \(SeedCodec.display(seed))
""")

while !sim.isFinished {
    let dayLines = sim.tick()

    clearScreen()

    // Header
    print("  \(sim.dateString)  •  day \(sim.day)")
    print("  \(String(repeating: "─", count: 50))")

    // Trail progress bar
    let width = 50
    let progress = Double(sim.milesTraveled) / Double(Trail.totalMiles)
    let filled = Int((Double(width) * progress).rounded())
    let bar = String(repeating: "░", count: filled) + String(repeating: " ", count: width - filled)
    print("  [\(bar)] \(sim.milesTraveled)/\(Trail.totalMiles) mi")

    // Landmark + weather
    let landmark = sim.currentLandmark?.name ?? "The Trail"
    print("  \(sim.currentWeather.kind.rawValue.capitalized)  •  near \(landmark)  •  \(sim.distanceRemaining) mi to Oregon")

    // Party status
    var statuses: [String] = []
    for member in sim.party.members {
        let icon = member.isAlive ? "●" : "✕"
        let health = member.isAlive ? "\(member.health)%" : "dead"
        statuses.append("\(icon)\(member.name) \(health)")
    }
    print("  Party: " + statuses.joined(separator: "  "))

    // Supplies
    print("  Food \(sim.supplies.foodPounds) lb  •  Oxen \(sim.supplies.oxen)  •  Ammo \(sim.supplies.ammunition)  •  $\(sim.supplies.cash)")

    // Today's journal
    print("  \(String(repeating: "─", count: 50))")
    if dayLines.isEmpty {
        print("  \(sim.currentWeather.kind.lofiDescription)")
    } else {
        for line in dayLines.prefix(6) {
            print("  · \(line)")
        }
    }

    Thread.sleep(forTimeInterval: pauseSeconds)
}

// Final outcome
clearScreen()
print("""
  ┌──────────────────────────────────────────────┐
  │        The journey has ended                │
  └──────────────────────────────────────────────┘
  \(sim.dateString)  •  day \(sim.day)
  Miles traveled: \(sim.milesTraveled) / \(Trail.totalMiles)

  \(sim.outcome == .reachedOregon
      ? "You made it to Oregon. \(sim.party.aliveCount) souls survived."
      : "No one made it. The prairie keeps its dead.")
""")
