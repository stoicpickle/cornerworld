import Darwin
import FarmCore
import Foundation

private let arguments = CommandLine.arguments

private func printHelp() {
    print("""
    Cornerworld Farm CLI — run one deterministic farm year.

    Usage:
      cornerworld-farm-cli [--seed NUMBER] [--plan PLAN] [--pause SECONDS] [--fast]
      cornerworld-farm-cli --version

    Options:
      --seed NUMBER    Reproduce a year from a decimal or 0x-prefixed hexadecimal seed.
      --plan PLAN      Plant wheat, beans, or fallow (default: wheat).
      --pause SECONDS  Set the delay between simulated weeks (default: 0.12).
      --fast           Run with a minimal delay.
      --version        Print the Cornerworld release version.
      --help, -h       Show this help.
    """)
}

private func fail(_ message: String) -> Never {
    fputs("cornerworld-farm-cli: \(message)\n", stderr)
    exit(2)
}

private func parseSeed(_ text: String) -> UInt64? {
    if text.hasPrefix("0x") || text.hasPrefix("0X") {
        let digits = text.dropFirst(2)
        guard !digits.isEmpty else { return nil }
        return UInt64(digits, radix: 16)
    }
    return UInt64(text, radix: 10)
}

private func displaySeed(_ seed: UInt64) -> String {
    "0x" + String(seed, radix: 16, uppercase: true)
}

private func parsePlan(_ text: String) -> FarmPlan? {
    switch text.lowercased() {
    case "wheat": .wheat
    case "beans": .beans
    case "fallow": .fallow
    default: nil
    }
}

private func label<T: RawRepresentable>(_ value: T) -> String where T.RawValue == String {
    value.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
}

private var seed = UInt64.random(in: UInt64.min...UInt64.max)
private var plan = FarmPlan.wheat
private var pauseSeconds = 0.12

private var index = 1
while index < arguments.count {
    switch arguments[index] {
    case "--seed":
        index += 1
        guard index < arguments.count, let parsed = parseSeed(arguments[index]) else {
            fail("--seed requires a decimal or 0x-prefixed hexadecimal value")
        }
        seed = parsed
    case "--plan":
        index += 1
        guard index < arguments.count, let parsed = parsePlan(arguments[index]) else {
            fail("--plan requires wheat, beans, or fallow")
        }
        plan = parsed
    case "--pause":
        index += 1
        guard index < arguments.count,
              let parsed = Double(arguments[index]),
              parsed.isFinite,
              parsed >= 0 else {
            fail("--pause requires a nonnegative number")
        }
        pauseSeconds = parsed
    case "--fast":
        pauseSeconds = 0.001
    case "--version":
        print("Cornerworld 1.1.0")
        exit(EXIT_SUCCESS)
    case "--help", "-h":
        printHelp()
        exit(EXIT_SUCCESS)
    default:
        fail("unknown option '\(arguments[index])'; use --help")
    }
    index += 1
}

private let isInteractive = isatty(STDOUT_FILENO) != 0

private func clearScreen() {
    guard isInteractive else { return }
    print("\u{001B}[2J\u{001B}[H", terminator: "")
}

private func progressBar(value: Int, maximum: Int = 100, width: Int = 24) -> String {
    let bounded = min(max(value, 0), maximum)
    let filled = Int((Double(bounded) / Double(maximum) * Double(width)).rounded())
    return String(repeating: "#", count: filled)
        + String(repeating: "·", count: width - filled)
}

private func statusLine(_ name: String, _ value: Int) -> String {
    "\(name) \(value)"
}

private func outcomeExplanation(_ outcome: FarmOutcome) -> String {
    switch outcome {
    case .stable:
        "The farm enters spring with enough stores, sound buildings, and room to choose its next crop."
    case .strained:
        "The farm made it through winter, but thin stores or worn buildings will make next year harder."
    case .debt:
        "Winter costs exceeded the farm's reserves. Recovery will require a different plan next year."
    }
}

private func signed(_ value: Int) -> String {
    value >= 0 ? "+\(value)" : "\(value)"
}

private func harvestExplanation(_ report: HarvestReport?) -> String {
    guard let report else { return "No crop was harvested." }
    return "Base \(report.baseYield) + growth \(report.growthContribution) + soil \(report.soilContribution) + moisture \(report.moistureContribution) - damage \(report.damagePenalty) = \(report.totalYield); stores \(signed(report.foodGained)), cash \(signed(report.cashGained)), soil \(signed(report.soilChange))."
}

private func render(simulation: FarmSimulation, log: [String]) {
    let state = simulation.state
    let weather = state.currentWeather.map(label) ?? "Waiting"
    let crop = label(state.cropStage)

    clearScreen()
    print("  CORNERWORLD — FARM  •  seed \(displaySeed(state.seed))  •  \(label(state.plan))")
    print("  \(String(repeating: "─", count: 62))")
    print("  Year 1  •  \(label(state.season)) week \(state.weekOfSeason)/13  •  week \(state.week)/52")
    print("  Field [\(progressBar(value: state.cropGrowth))] \(crop)  •  \(weather)")
    print("  \(statusLine("Soil", state.soilQuality))  •  \(statusLine("Moisture", state.moisture))  •  \(statusLine("Stores", state.storedFood))")
    print("  Cash $\(state.cash)  •  Condition \(state.buildingCondition)")
    print("  \(String(repeating: "─", count: 62))")
    if log.isEmpty {
        print("  · The farm settles into the week.")
    } else {
        for line in log.prefix(5) {
            print("  · \(line)")
        }
    }
}

var simulation = FarmSimulation(seed: seed, plan: plan)

while !simulation.state.isFinished {
    let log = simulation.tick()
    render(simulation: simulation, log: log)
    Thread.sleep(forTimeInterval: pauseSeconds)
}

let finalState = simulation.state
guard let finalOutcome = finalState.outcome else {
    fail("farm year ended without an outcome")
}

clearScreen()
print("""
  ┌────────────────────────────────────────────────────────────┐
  │                  The farm year has ended                  │
  └────────────────────────────────────────────────────────────┘
  Seed: \(displaySeed(finalState.seed))  •  Plan: \(label(finalState.plan))
  Final soil \(finalState.soilQuality)  •  Stores \(finalState.storedFood)  •  Cash $\(finalState.cash)  •  Condition \(finalState.buildingCondition)

  Harvest: \(finalState.harvestReport?.summary ?? "No crop was harvested.")
  Why: \(harvestExplanation(finalState.harvestReport))
  Outcome: \(label(finalOutcome))
  \(outcomeExplanation(finalOutcome))
""")
