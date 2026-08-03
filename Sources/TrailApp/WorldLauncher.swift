import AppKit
import DesktopHostCore
import Foundation

@MainActor
enum WorldLauncher {
    private static var launchedProcesses: [Process] = []

    @discardableResult
    static func open(_ world: DesktopWorld) -> Bool {
        guard let executableURL = Bundle.main.executableURL else {
            presentLaunchError("Cornerworld could not locate its executable.")
            return false
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["--world", world.rawValue]
        process.terminationHandler = { terminatedProcess in
            Task { @MainActor in
                launchedProcesses.removeAll { $0 === terminatedProcess }
            }
        }

        do {
            try process.run()
            // Keep the Process handle alive while its independently running world is open.
            launchedProcesses.append(process)
            return true
        } catch {
            presentLaunchError("Cornerworld could not open \(world.rawValue): \(error.localizedDescription)")
            return false
        }
    }

    private static func presentLaunchError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Could not open world"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
