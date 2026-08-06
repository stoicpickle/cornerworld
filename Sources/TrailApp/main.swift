import AppKit
import DesktopHostCore
import Darwin

let launchArguments = Array(CommandLine.arguments.dropFirst())

func printDesktopHelp() {
    print("""
    Cornerworld — run a tiny living world on your macOS desktop.

    Usage:
      cornerworld [--world overland|farm|canopy] [--seed NUMBER] [--plan wheat|beans|fallow] [--fast]
      cornerworld --capture-farm-fixtures DIRECTORY
      cornerworld --capture-canopy-fixtures DIRECTORY
      cornerworld --capture-menu-bar-fixtures DIRECTORY
      cornerworld --version

    Options:
      --world WORLD   Open Overland, Farm, or Canopy (default: overland).
      --seed NUMBER   Reproduce a deterministic world (decimal or 0x-prefixed hex).
      --plan PLAN     Start Farm with wheat, beans, or fallow (Farm only; default: wheat).
      --fast          Advance time rapidly for development.
      --capture-farm-fixtures DIRECTORY
                      Write deterministic 320x200 Farm PNGs without launching a window.
      --capture-canopy-fixtures DIRECTORY
                      Write deterministic 320x200 Canopy PNGs without launching a window.
      --capture-menu-bar-fixtures DIRECTORY
                      Write isolated light/dark status-item PNGs without capturing the desktop.
      --help, -h      Print this help text without launching the app.
      --version       Print the Cornerworld release version.
    """)
}

let launchOptions: DesktopLaunchOptions
do {
    launchOptions = try DesktopLaunchOptions(arguments: launchArguments)
} catch let error as DesktopLaunchError {
    fputs("cornerworld: \(error.description)\n", stderr)
    exit(2)
} catch {
    fputs("cornerworld: \(error.localizedDescription)\n", stderr)
    exit(2)
}

switch launchOptions.command {
case .help:
    printDesktopHelp()
    exit(EXIT_SUCCESS)
case .version:
    print("Cornerworld 1.1.0")
    exit(EXIT_SUCCESS)
case .captureFarmFixtures(let directory):
    let farmFixtureDirectory = URL(
        fileURLWithPath: directory,
        relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ).standardizedFileURL
    _ = NSApplication.shared
    do {
        let fixtureURLs = try FarmFixtureCapture.writeFixtures(to: farmFixtureDirectory)
        for url in fixtureURLs {
            print(url.path)
        }
        exit(EXIT_SUCCESS)
    } catch {
        fputs("cornerworld: could not capture Farm fixtures: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
case .captureCanopyFixtures(let directory):
    let canopyFixtureDirectory = URL(
        fileURLWithPath: directory,
        relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ).standardizedFileURL
    _ = NSApplication.shared
    do {
        let fixtureURLs = try CanopyFixtureCapture.writeFixtures(to: canopyFixtureDirectory)
        for url in fixtureURLs {
            print(url.path)
        }
        exit(EXIT_SUCCESS)
    } catch {
        fputs("cornerworld: could not capture Canopy fixtures: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
case .captureMenuBarFixtures(let directory):
    let menuBarFixtureDirectory = URL(
        fileURLWithPath: directory,
        relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ).standardizedFileURL
    _ = NSApplication.shared
    do {
        let fixtureURLs = try MenuBarFixtureCapture.writeFixtures(to: menuBarFixtureDirectory)
        for url in fixtureURLs {
            print(url.path)
        }
        exit(EXIT_SUCCESS)
    } catch {
        fputs("cornerworld: could not capture menu-bar fixtures: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
case .run:
    break
}

let app = NSApplication.shared
let retainedDelegate: any NSApplicationDelegate = switch launchOptions.world {
case .overland:
    AppDelegate(fast: launchOptions.fast)
case .farm:
    FarmAppDelegate(
        seed: launchOptions.seed,
        plan: launchOptions.farmPlan,
        fast: launchOptions.fast
    )
case .canopy:
    CanopyAppDelegate(seed: launchOptions.seed, fast: launchOptions.fast)
}
app.delegate = retainedDelegate
app.setActivationPolicy(.accessory)
app.run()
