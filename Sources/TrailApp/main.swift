import AppKit
import Darwin
import GameCore

let launchArguments = Array(CommandLine.arguments.dropFirst())

func printDesktopHelp() {
    print("""
    Cornerworld — run the Overland world on your macOS desktop.

    Usage:
      cornerworld [--seed NUMBER] [--fast]
      cornerworld --version

    Options:
      --seed NUMBER  Reproduce a deterministic journey (decimal or 0x-prefixed hex).
      --fast         Advance days rapidly for development.
      --help, -h     Print this help text without launching the app.
      --version      Print the Cornerworld release version.
    """)
}

var argumentIndex = 0
while argumentIndex < launchArguments.count {
    switch launchArguments[argumentIndex] {
    case "--seed":
        argumentIndex += 1
        guard argumentIndex < launchArguments.count,
              SeedCodec.parse(launchArguments[argumentIndex]) != nil else {
            fputs("cornerworld: --seed requires a decimal or 0x-prefixed hexadecimal value\n", stderr)
            exit(2)
        }
    case "--fast":
        break
    case "--help", "-h":
        printDesktopHelp()
        exit(EXIT_SUCCESS)
    case "--version":
        print("Cornerworld 1.0.0")
        exit(EXIT_SUCCESS)
    default:
        fputs("cornerworld: unknown option '\(launchArguments[argumentIndex])'; use --help\n", stderr)
        exit(2)
    }
    argumentIndex += 1
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
