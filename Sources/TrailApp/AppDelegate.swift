import AppKit
import SpriteKit
import Darwin
import GameCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var window: CornerWindow!
    private var skView: SKView!
    private var scene: TrailScene!
    private var simulation: Simulation!
    private var statusItem: NSStatusItem!
    private var appearanceObservation: NSKeyValueObservation?
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
        let seed: UInt64
        switch launchSeed() {
        case .random:
            seed = UInt64.random(in: 0...UInt64.max)
        case .value(let suppliedSeed):
            seed = suppliedSeed
        case .missingSeed:
            fputs("cornerworld: --seed requires a decimal or 0x-prefixed hexadecimal value\n", stderr)
            NSApplication.shared.terminate(nil)
            return
        case .invalid(let value):
            fputs("cornerworld: invalid --seed value '\(value)'\n", stderr)
            NSApplication.shared.terminate(nil)
            return
        }
        simulation = Simulation(seed: seed)
        if CommandLine.arguments.contains("--fast") { tickInterval = 0.04 }
        setupWindow()
        setupStatusItem()
        startTicking()

        let frame = window.frame
        print("Cornerworld: window at (\(frame.minX), \(frame.minY)) size \(Int(frame.width))x\(Int(frame.height)); statusItem=\(statusItem != nil)")
        fflush(stdout)
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopTicking()
    }

    private enum LaunchSeed {
        case random
        case value(UInt64)
        case missingSeed
        case invalid(String)
    }

    private func launchSeed() -> LaunchSeed {
        guard let flag = CommandLine.arguments.firstIndex(of: "--seed") else { return .random }
        guard CommandLine.arguments.indices.contains(flag + 1) else { return .missingSeed }
        let value = CommandLine.arguments[flag + 1]
        guard let seed = SeedCodec.parse(value) else { return .invalid(value) }
        return .value(seed)
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
            button.title = ""
            button.imagePosition = .imageLeading
            appearanceObservation = button.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in
                    self?.updateStatus()
                }
            }
        }
        statusItem.menu = buildStatusMenu()
        updateMenus()
        updateStatus()
    }

    private func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        runTitleItem = NSMenuItem(title: "Cornerworld — Overland", action: nil, keyEquivalent: "")
        menu.addItem(runTitleItem)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "Show / Hide world", action: #selector(statusClicked), keyEquivalent: "w")
        toggle.target = self
        menu.addItem(toggle)

        let newRun = NSMenuItem(title: "New journey", action: #selector(startNewRun), keyEquivalent: "n")
        newRun.target = self
        menu.addItem(newRun)

        let worlds = NSMenuItem(title: "Worlds", action: nil, keyEquivalent: "")
        let worldsMenu = NSMenu(title: "Worlds")
        let currentWorld = NSMenuItem(title: "Overland — open", action: nil, keyEquivalent: "")
        currentWorld.state = .on
        worldsMenu.addItem(currentWorld)
        worldsMenu.addItem(.separator())
        let anotherOverland = NSMenuItem(title: "Open another Overland…", action: #selector(openOverlandWorld), keyEquivalent: "")
        anotherOverland.target = self
        worldsMenu.addItem(anotherOverland)
        let openFarm = NSMenuItem(title: "Open Farm…", action: #selector(openFarmWorld), keyEquivalent: "")
        openFarm.target = self
        worldsMenu.addItem(openFarm)
        let openCanopy = NSMenuItem(title: "Open Canopy…", action: #selector(openCanopyWorld), keyEquivalent: "")
        openCanopy.target = self
        worldsMenu.addItem(openCanopy)
        worlds.submenu = worldsMenu
        menu.addItem(worlds)

        let pace = NSMenuItem(title: "Pace", action: nil, keyEquivalent: "")
        paceMenu = NSMenu(title: "Pace")
        let paceOptions = [
            ("Steady", "Adds 3 miles to the terrain's daily base."),
            ("Moderate", "Uses the terrain's standard daily mileage."),
            ("Slow", "Subtracts 2 miles from the daily base."),
            ("Very slow", "Subtracts 6 miles for a genuinely gradual journey."),
        ]
        for (tag, option) in paceOptions.enumerated() {
            let (title, toolTip) = option
            let item = NSMenuItem(title: title, action: #selector(setPace(_:)), keyEquivalent: "")
            item.target = self
            item.tag = tag
            item.toolTip = toolTip
            paceMenu.addItem(item)
        }
        pace.submenu = paceMenu
        menu.addItem(pace)

        let rations = NSMenuItem(title: "Rations", action: nil, keyEquivalent: "")
        rationMenu = NSMenu(title: "Rations")
        let rationOptions = [
            ("Filling — 3 lbs/person", "Restores 2 health per day when conditions permit."),
            ("Meager — 2 lbs/person", "Maintains health but provides no daily recovery."),
            ("Bare bones — 1 lb/person", "Costs 2 health per day."),
        ]
        for (tag, option) in rationOptions.enumerated() {
            let (title, toolTip) = option
            let item = NSMenuItem(title: title, action: #selector(setRations(_:)), keyEquivalent: "")
            item.target = self
            item.tag = tag
            item.toolTip = toolTip
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

    @objc private func openOverlandWorld() {
        if WorldLauncher.open(.overland) {
            hideWindow()
        }
    }

    @objc private func openFarmWorld() {
        if WorldLauncher.open(.farm) {
            hideWindow()
        }
    }

    @objc private func openCanopyWorld() {
        if WorldLauncher.open(.canopy) {
            hideWindow()
        }
    }

    @objc private func setPace(_ sender: NSMenuItem) {
        simulation.pace = switch sender.tag {
        case 0: .steady
        case 2: .slow
        case 3: .verySlow
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
        runTitleItem.title = "CORNERWORLD  •  OVERLAND  •  SEED \(seedText)"

        let paceTag = switch simulation.pace {
        case .steady: 0
        case .moderate: 1
        case .slow: 2
        case .verySlow: 3
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
        SeedCodec.display(simulation.seed)
    }

    private func updateStatus() {
        guard let button = statusItem.button else { return }

        let miles = simulation.milesTraveled
        let alive = simulation.party.aliveCount
        let total = simulation.party.members.count

        var accent = NSColor.systemGreen
        if simulation.isFinished {
            accent = simulation.outcome == .reachedOregon ? NSColor.systemGreen : NSColor.systemRed
        } else if alive < total {
            accent = NSColor.systemOrange
        } else if simulation.party.averageHealth < 60 {
            accent = NSColor.systemOrange
        }

        button.image = MenuBarPresentation.overlandIcon(accent: accent)
        button.attributedTitle = MenuBarPresentation.overlandTitle(
            miles: miles,
            alive: alive,
            total: total,
            accent: accent
        )
        button.setAccessibilityLabel("Cornerworld Overland status")
        button.setAccessibilityValue("\(miles) miles traveled; \(alive) of \(total) travelers alive")
        button.toolTip = "CORNERWORLD — OVERLAND\n\(simulation.dateString)\n\(miles) miles traveled · \(simulation.distanceRemaining) remaining\n\(alive) of \(total) travelers alive\nSeed \(seedText)"
    }
}
