import AppKit
import SpriteKit
import GameCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var window: CornerWindow!
    private var skView: SKView!
    private var scene: TrailScene!
    private var simulation: Simulation!
    private var statusItem: NSStatusItem!
    private var tickTimer: Timer?
    private var latestEvent = "The wagon train sets out for Oregon."
    private var presentationRevision = 0
    private var runTitleItem: NSMenuItem!
    private var paceMenu: NSMenu!
    private var rationMenu: NSMenu!
    private var journalMenu: NSMenu!

    private var tickInterval: TimeInterval = 0.8  // real seconds per game day

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        simulation = Simulation(seed: launchSeed() ?? UInt64.random(in: 0...UInt64.max))
        if CommandLine.arguments.contains("--fast") { tickInterval = 0.04 }
        setupWindow()
        setupStatusItem()
        startTicking()

        let frame = window.frame
        print("TrailApp: window at (\(frame.minX), \(frame.minY)) size \(Int(frame.width))x\(Int(frame.height)); statusItem=\(statusItem != nil)")
        fflush(stdout)
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopTicking()
    }

    private func launchSeed() -> UInt64? {
        guard let flag = CommandLine.arguments.firstIndex(of: "--seed"),
              CommandLine.arguments.indices.contains(flag + 1) else { return nil }
        return UInt64(CommandLine.arguments[flag + 1])
    }

    // MARK: - Window

    private func setupWindow() {
        let size = NSSize(width: TrailScene.logicalSize.width, height: TrailScene.logicalSize.height)
        window = CornerWindow(size: size)

        skView = SKView(frame: NSRect(origin: .zero, size: size))
        skView.wantsLayer = true
        skView.layer?.cornerRadius = 12
        skView.layer?.masksToBounds = true
        skView.allowsTransparency = false
        skView.ignoresSiblingOrder = true
        window.contentView = skView

        scene = TrailScene(snapshot: presentationSnapshot())
        skView.presentScene(scene)
        window.orderFrontRegardless()
    }

    private func showWindow() {
        window.orderFrontRegardless()
    }

    private func hideWindow() {
        window.orderOut(nil)
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "  🛒"
            button.image = statusIcon()
            button.imagePosition = .imageLeading
        }
        statusItem.menu = buildStatusMenu()
        updateMenus()
    }

    private func statusIcon() -> NSImage {
        let size = NSSize(width: 18, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()
        let color = NSColor.controlTextColor

        // Wagon body
        let body = NSBezierPath(roundedRect: NSRect(x: 1, y: 5, width: 13, height: 6), xRadius: 1, yRadius: 1)
        color.setFill()
        body.fill()

        // Canvas
        let canvas = NSBezierPath(roundedRect: NSRect(x: 2.5, y: 10, width: 10, height: 4), xRadius: 1, yRadius: 1)
        color.withAlphaComponent(0.7).setFill()
        canvas.fill()

        // Wheels
        for x in [3.0, 11.0] {
            let wheel = NSBezierPath(ovalIn: NSRect(x: x, y: 2, width: 3.5, height: 3.5))
            color.setFill()
            wheel.fill()
        }
        image.unlockFocus()
        return image
    }

    private func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        runTitleItem = NSMenuItem(title: "Oregon Trail", action: nil, keyEquivalent: "")
        menu.addItem(runTitleItem)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "Show / Hide wagon", action: #selector(statusClicked), keyEquivalent: "w")
        toggle.target = self
        menu.addItem(toggle)

        let newRun = NSMenuItem(title: "New crossing", action: #selector(startNewRun), keyEquivalent: "n")
        newRun.target = self
        menu.addItem(newRun)

        let pace = NSMenuItem(title: "Pace", action: nil, keyEquivalent: "")
        paceMenu = NSMenu(title: "Pace")
        for (tag, title) in ["Steady", "Moderate", "Slow"].enumerated() {
            let item = NSMenuItem(title: title, action: #selector(setPace(_:)), keyEquivalent: "")
            item.target = self
            item.tag = tag
            paceMenu.addItem(item)
        }
        pace.submenu = paceMenu
        menu.addItem(pace)

        let rations = NSMenuItem(title: "Rations", action: nil, keyEquivalent: "")
        rationMenu = NSMenu(title: "Rations")
        for (tag, title) in ["Filling", "Meager", "Bare bones"].enumerated() {
            let item = NSMenuItem(title: title, action: #selector(setRations(_:)), keyEquivalent: "")
            item.target = self
            item.tag = tag
            rationMenu.addItem(item)
        }
        rations.submenu = rationMenu
        menu.addItem(rations)

        let journal = NSMenuItem(title: "Trail journal", action: nil, keyEquivalent: "")
        journalMenu = NSMenu(title: "Trail journal")
        journal.submenu = journalMenu
        menu.addItem(journal)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenus()
    }

    @objc private func statusClicked() {
        if window.isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    @objc private func startNewRun() {
        stopTicking()
        simulation = Simulation(seed: UInt64.random(in: 0...UInt64.max))
        latestEvent = "The wagon train sets out for Oregon."
        presentationRevision += 1
        scene = TrailScene(snapshot: presentationSnapshot())
        skView.presentScene(scene)
        updateMenus()
        updateStatus()
        startTicking()
    }

    @objc private func setPace(_ sender: NSMenuItem) {
        simulation.pace = switch sender.tag {
        case 0: .steady
        case 2: .slow
        default: .moderate
        }
        latestEvent = "Pace set to \(simulation.pace.name)."
        refreshPresentation()
    }

    @objc private func setRations(_ sender: NSMenuItem) {
        simulation.ration = switch sender.tag {
        case 1: .meager
        case 2: .bareBones
        default: .filling
        }
        latestEvent = "Rations set to \(simulation.ration.name)."
        refreshPresentation()
    }

    // MARK: - Game loop

    private func startTicking() {
        stopTicking()
        let interval = tickInterval
        tickTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
    }

    private func tick() {
        let events = simulation.tick()
        // A quiet day should look quiet instead of repeating yesterday's news.
        // TrailScene supplies the neutral fallback for an empty message.
        latestEvent = events.last ?? ""
        presentationRevision += 1
        scene.apply(presentationSnapshot())
        updateMenus()
        updateStatus()
        if simulation.isFinished {
            stopTicking()
        }
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func presentationSnapshot() -> TrailPresentationSnapshot {
        TrailPresentationSnapshot(
            simulation: simulation,
            latestEvent: latestEvent,
            revision: presentationRevision
        )
    }

    private func refreshPresentation() {
        presentationRevision += 1
        scene.apply(presentationSnapshot())
        updateMenus()
        updateStatus()
    }

    private func updateMenus() {
        guard runTitleItem != nil else { return }
        runTitleItem.title = "OREGON TRAIL  •  SEED \(seedText)"

        let paceTag = switch simulation.pace {
        case .steady: 0
        case .moderate: 1
        case .slow: 2
        }
        for item in paceMenu.items { item.state = item.tag == paceTag ? .on : .off }

        let rationTag = switch simulation.ration {
        case .filling: 0
        case .meager: 1
        case .bareBones: 2
        }
        for item in rationMenu.items { item.state = item.tag == rationTag ? .on : .off }

        journalMenu.removeAllItems()
        let recent = simulation.eventLog.suffix(6)
        if recent.isEmpty {
            journalMenu.addItem(NSMenuItem(title: "No entries yet", action: nil, keyEquivalent: ""))
        } else {
            for entry in recent.reversed() {
                journalMenu.addItem(NSMenuItem(title: entry, action: nil, keyEquivalent: ""))
            }
        }
    }

    private var seedText: String {
        String(simulation.seed, radix: 16, uppercase: true)
    }

    private func updateStatus() {
        guard let button = statusItem.button else { return }

        let miles = simulation.milesTraveled
        let alive = simulation.party.aliveCount
        let total = simulation.party.members.count

        var color = NSColor.controlTextColor
        if simulation.isFinished {
            color = simulation.outcome == .reachedOregon ? NSColor.systemGreen : NSColor.systemRed
        } else if alive < total {
            color = NSColor.systemOrange
        } else if simulation.party.averageHealth < 60 {
            color = NSColor.systemOrange
        }

        let dot = "●"
        let title = NSMutableAttributedString(string: "\(dot) \(miles) mi · \(alive)/\(total)")
        title.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: (dot as NSString).length))
        title.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: NSRange(location: (dot as NSString).length, length: title.length - (dot as NSString).length))

        button.attributedTitle = title
        button.toolTip = "Seed \(seedText)\n\(simulation.dateString)\n\(miles) miles traveled\n\(alive) of \(total) party members alive\n\(simulation.distanceRemaining) miles to Oregon"
    }
}
