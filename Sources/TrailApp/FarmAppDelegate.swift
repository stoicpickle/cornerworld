import AppKit
import DesktopHostCore
import SpriteKit
import FarmCore

@MainActor
final class FarmAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let clockSchedule: FarmClockSchedule
    private var selectedPlan: FarmPlan
    private let initialSeed: UInt64

    private var window: CornerWindow!
    private var skView: SKView!
    private var scene: FarmScene!
    private var simulation: FarmSimulation!
    private var statusItem: NSStatusItem!
    private var appearanceObservation: NSKeyValueObservation?
    private var tickTimer: Timer?
    private var latestEvent = "The field waits for spring planting."
    private var presentationRevision = 0
    private var timeMode: FarmClockMode = .ambient

    private var runTitleItem: NSMenuItem!
    private var fieldPlanMenu: NSMenu!
    private var timeMenu: NSMenu!
    private var journalMenu: NSMenu!

    init(seed: UInt64?, plan: FarmPlan, fast: Bool) {
        initialSeed = seed ?? UInt64.random(in: 0...UInt64.max)
        selectedPlan = plan
        clockSchedule = FarmClockSchedule(accelerated: fast)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        simulation = FarmSimulation(seed: initialSeed, plan: selectedPlan)
        setupWindow()
        setupStatusItem()
        startTicking()

        let frame = window.frame
        print("Cornerworld Farm: window at (\(frame.minX), \(frame.minY)) size \(Int(frame.width))x\(Int(frame.height)); statusItem=\(statusItem != nil)")
        fflush(stdout)
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopTicking()
    }

    // MARK: - Window

    private func setupWindow() {
        let size = NSSize(width: FarmScene.logicalSize.width, height: FarmScene.logicalSize.height)
        window = CornerWindow(size: size)

        skView = DraggableWorldView(frame: NSRect(origin: .zero, size: size))
        skView.wantsLayer = true
        skView.layer?.cornerRadius = 12
        skView.layer?.masksToBounds = true
        skView.allowsTransparency = false
        skView.ignoresSiblingOrder = true
        window.contentView = skView

        scene = FarmScene(snapshot: presentationSnapshot())
        skView.presentScene(scene)
        window.orderFrontRegardless()
    }

    @objc private func toggleWindow() {
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.orderFrontRegardless()
        }
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

        runTitleItem = NSMenuItem(title: "Cornerworld — Farm", action: nil, keyEquivalent: "")
        menu.addItem(runTitleItem)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "Show / Hide world", action: #selector(toggleWindow), keyEquivalent: "w")
        toggle.target = self
        menu.addItem(toggle)

        let newFarm = NSMenuItem(title: "New farm", action: #selector(startNewFarm), keyEquivalent: "n")
        newFarm.target = self
        menu.addItem(newFarm)

        let worlds = NSMenuItem(title: "Worlds", action: nil, keyEquivalent: "")
        let worldsMenu = NSMenu(title: "Worlds")
        let currentWorld = NSMenuItem(title: "Farm — open", action: nil, keyEquivalent: "")
        currentWorld.state = .on
        worldsMenu.addItem(currentWorld)
        worldsMenu.addItem(.separator())
        let openOverland = NSMenuItem(title: "Open Overland…", action: #selector(openOverlandWorld), keyEquivalent: "")
        openOverland.target = self
        worldsMenu.addItem(openOverland)
        let anotherFarm = NSMenuItem(title: "Open another Farm…", action: #selector(openFarmWorld), keyEquivalent: "")
        anotherFarm.target = self
        worldsMenu.addItem(anotherFarm)
        let openCanopy = NSMenuItem(title: "Open Canopy…", action: #selector(openCanopyWorld), keyEquivalent: "")
        openCanopy.target = self
        worldsMenu.addItem(openCanopy)
        worlds.submenu = worldsMenu
        menu.addItem(worlds)

        let fieldPlan = NSMenuItem(title: "Start New Farm With", action: nil, keyEquivalent: "")
        fieldPlanMenu = NSMenu(title: "Start New Farm With")
        for (tag, plan) in FarmPlan.allCases.enumerated() {
            let item = NSMenuItem(
                title: "New \(planName(plan)) Farm",
                action: #selector(setFieldPlan(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = tag
            fieldPlanMenu.addItem(item)
        }
        fieldPlan.submenu = fieldPlanMenu
        menu.addItem(fieldPlan)

        let time = NSMenuItem(title: "Time", action: nil, keyEquivalent: "")
        timeMenu = NSMenu(title: "Time")
        for mode in FarmClockMode.allCases {
            let item = NSMenuItem(
                title: mode.menuTitle,
                action: #selector(setTimeMode(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = mode.rawValue
            timeMenu.addItem(item)
        }
        time.submenu = timeMenu
        menu.addItem(time)

        let journal = NSMenuItem(title: "Farm journal", action: nil, keyEquivalent: "")
        journalMenu = NSMenu(title: "Farm journal")
        journal.submenu = journalMenu
        menu.addItem(journal)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenus()
    }

    @objc private func startNewFarm() {
        beginFarm(seed: UInt64.random(in: 0...UInt64.max), plan: selectedPlan)
    }

    @objc private func openOverlandWorld() {
        if WorldLauncher.open(.overland) {
            window.orderOut(nil)
        }
    }

    @objc private func openFarmWorld() {
        if WorldLauncher.open(.farm) {
            window.orderOut(nil)
        }
    }

    @objc private func openCanopyWorld() {
        if WorldLauncher.open(.canopy) {
            window.orderOut(nil)
        }
    }

    @objc private func setFieldPlan(_ sender: NSMenuItem) {
        guard FarmPlan.allCases.indices.contains(sender.tag) else { return }
        let plan = FarmPlan.allCases[sender.tag]
        selectedPlan = plan
        beginFarm(seed: UInt64.random(in: 0...UInt64.max), plan: plan)
    }

    @objc private func setTimeMode(_ sender: NSMenuItem) {
        guard let mode = FarmClockMode(rawValue: sender.tag) else { return }
        timeMode = mode
        if mode == .paused || simulation.isFinished {
            stopTicking()
        } else {
            startTicking()
        }
        updateMenus()
        updateStatus()
    }

    private func beginFarm(seed: UInt64, plan: FarmPlan) {
        stopTicking()
        selectedPlan = plan
        simulation = FarmSimulation(seed: seed, plan: plan)
        latestEvent = "The field waits for spring planting."
        presentationRevision += 1
        scene = FarmScene(snapshot: presentationSnapshot())
        skView.presentScene(scene)
        updateMenus()
        updateStatus()
        if timeMode != .paused { startTicking() }
    }

    // MARK: - Farm loop

    private func startTicking() {
        stopTicking()
        scheduleNextTick()
    }

    private func scheduleNextTick() {
        guard !simulation.isFinished,
              let delay = clockSchedule.delay(
                  for: timeMode,
                  showingVisualEvent: simulation.latestVisualEvent != nil
              ) else { return }

        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.tick()
                self.scheduleNextTick()
            }
        }
        timer.tolerance = clockSchedule.tolerance(for: delay)
        tickTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func tick() {
        let events = simulation.tick()
        latestEvent = events.last ?? ""
        presentationRevision += 1
        scene.apply(presentationSnapshot())
        updateMenus()
        updateStatus()
        if simulation.isFinished { stopTicking() }
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func presentationSnapshot() -> FarmPresentationSnapshot {
        FarmPresentationSnapshot(
            simulation: simulation,
            latestEvent: latestEvent,
            revision: presentationRevision
        )
    }

    private func updateMenus() {
        guard runTitleItem != nil else { return }
        runTitleItem.title = "CORNERWORLD  •  FARM  •  \(timeMode.title.uppercased())  •  SEED \(seedText)"

        for (index, item) in fieldPlanMenu.items.enumerated() {
            item.state = FarmPlan.allCases[index] == simulation.plan ? .on : .off
        }
        for item in timeMenu.items {
            item.state = item.tag == timeMode.rawValue ? .on : .off
        }

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
        "0x" + String(simulation.seed, radix: 16, uppercase: true)
    }

    private func updateStatus() {
        guard let button = statusItem.button else { return }

        let accent: NSColor
        if let outcome = simulation.outcome {
            accent = outcome == .stable ? .systemGreen : (outcome == .strained ? .systemOrange : .systemRed)
        } else if simulation.moisture < 20 || simulation.buildingCondition < 50 {
            accent = .systemOrange
        } else {
            accent = .systemGreen
        }
        button.image = MenuBarPresentation.farmIcon(accent: accent)
        button.attributedTitle = MenuBarPresentation.farmTitle(
            week: simulation.week,
            cash: simulation.cash
        )
        button.setAccessibilityLabel("Cornerworld Farm status")
        button.setAccessibilityValue("Week \(simulation.week) of 52; \(simulation.cash) dollars cash; time \(timeMode.title)")
        button.toolTip = "CORNERWORLD — FARM\n\(seasonName(simulation.season)), week \(simulation.weekOfSeason)\n\(planName(simulation.plan)) field · $\(simulation.cash) cash\nTime \(timeMode.menuTitle)\nSeed \(seedText)"
    }
}

private func planName(_ plan: FarmPlan) -> String {
    switch plan {
    case .wheat: "Wheat"
    case .beans: "Beans"
    case .fallow: "Fallow"
    }
}

private func seasonName(_ season: FarmSeason) -> String {
    switch season {
    case .spring: "Spring"
    case .summer: "Summer"
    case .autumn: "Autumn"
    case .winter: "Winter"
    }
}
