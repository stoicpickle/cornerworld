import AppKit
import CanopyCore
import DesktopHostCore
import SpriteKit

@MainActor
final class CanopyAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let initialSeed: UInt64
    private let clockSchedule: CanopyClockSchedule
    private let soundPlayer = CanopySoundPlayer()

    private var window: CornerWindow!
    private var skView: SKView!
    private var scene: CanopyScene!
    private var simulation: CanopySimulation!
    private var statusItem: NSStatusItem!
    private var appearanceObservation: NSKeyValueObservation?
    private var tickTimer: Timer?
    private var latestEvent = "The jungle waits for green."
    private var presentationRevision = 0
    private var clockMode: CanopyClockMode = .active
    private var soundEnabled = false

    private var runTitleItem: NSMenuItem!
    private var growthMenu: NSMenu!
    private var soundItem: NSMenuItem!
    private var journalMenu: NSMenu!

    init(seed: UInt64?, fast: Bool) {
        initialSeed = seed ?? UInt64.random(in: 0...UInt64.max)
        clockSchedule = CanopyClockSchedule(accelerated: fast)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        simulation = CanopySimulation(seed: initialSeed)
        setupWindow()
        setupStatusItem()
        startTicking()

        let frame = window.frame
        print("Cornerworld Canopy: window at (\(frame.minX), \(frame.minY)) size \(Int(frame.width))x\(Int(frame.height)); statusItem=\(statusItem != nil)")
        fflush(stdout)
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopTicking()
    }

    private func setupWindow() {
        let size = NSSize(width: CanopyScene.logicalSize.width, height: CanopyScene.logicalSize.height)
        window = CornerWindow(size: size)
        skView = SKView(frame: NSRect(origin: .zero, size: size))
        skView.wantsLayer = true
        skView.layer?.cornerRadius = 12
        skView.layer?.masksToBounds = true
        skView.allowsTransparency = false
        skView.ignoresSiblingOrder = true
        window.contentView = skView

        scene = CanopyScene(snapshot: presentationSnapshot())
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

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = ""
            button.imagePosition = .imageLeading
            appearanceObservation = button.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.updateStatus() }
            }
        }
        statusItem.menu = buildStatusMenu()
        updateMenus()
        updateStatus()
    }

    private func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        runTitleItem = NSMenuItem(title: "Cornerworld — Canopy", action: nil, keyEquivalent: "")
        menu.addItem(runTitleItem)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "Show / Hide world", action: #selector(toggleWindow), keyEquivalent: "w")
        toggle.target = self
        menu.addItem(toggle)

        let newCanopy = NSMenuItem(title: "New canopy", action: #selector(startNewCanopy), keyEquivalent: "n")
        newCanopy.target = self
        menu.addItem(newCanopy)

        let worlds = NSMenuItem(title: "Worlds", action: nil, keyEquivalent: "")
        let worldsMenu = NSMenu(title: "Worlds")
        let current = NSMenuItem(title: "Canopy — open", action: nil, keyEquivalent: "")
        current.state = .on
        worldsMenu.addItem(current)
        worldsMenu.addItem(.separator())
        for (title, action) in [
            ("Open Overland…", #selector(openOverlandWorld)),
            ("Open Farm…", #selector(openFarmWorld)),
            ("Open another Canopy…", #selector(openCanopyWorld)),
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            worldsMenu.addItem(item)
        }
        worlds.submenu = worldsMenu
        menu.addItem(worlds)

        let growth = NSMenuItem(title: "Growth", action: nil, keyEquivalent: "")
        growthMenu = NSMenu(title: "Growth")
        for mode in CanopyClockMode.allCases {
            let item = NSMenuItem(title: mode.menuTitle, action: #selector(setClockMode(_:)), keyEquivalent: "")
            item.target = self
            item.tag = mode.rawValue
            growthMenu.addItem(item)
        }
        growth.submenu = growthMenu
        menu.addItem(growth)

        let prune = NSMenuItem(title: "Prune vines", action: #selector(pruneVines), keyEquivalent: "p")
        prune.target = self
        menu.addItem(prune)

        soundItem = NSMenuItem(title: "Swing sound", action: #selector(toggleSound), keyEquivalent: "")
        soundItem.target = self
        menu.addItem(soundItem)

        let journal = NSMenuItem(title: "Canopy journal", action: nil, keyEquivalent: "")
        journalMenu = NSMenu(title: "Canopy journal")
        journal.submenu = journalMenu
        menu.addItem(journal)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenus()
    }

    @objc private func startNewCanopy() {
        beginCanopy(seed: UInt64.random(in: 0...UInt64.max))
    }

    @objc private func openOverlandWorld() { openWorld(.overland) }
    @objc private func openFarmWorld() { openWorld(.farm) }
    @objc private func openCanopyWorld() { openWorld(.canopy) }

    private func openWorld(_ world: DesktopWorld) {
        if WorldLauncher.open(world) { window.orderOut(nil) }
    }

    @objc private func setClockMode(_ sender: NSMenuItem) {
        guard let mode = CanopyClockMode(rawValue: sender.tag) else { return }
        clockMode = mode
        mode == .paused ? stopTicking() : startTicking()
        updateMenus()
        updateStatus()
    }

    @objc private func pruneVines() {
        latestEvent = simulation.prune()
        presentationRevision += 1
        scene.apply(presentationSnapshot())
        updateMenus()
        updateStatus()
        if clockMode != .paused { startTicking() }
    }

    @objc private func toggleSound() {
        soundEnabled.toggle()
        updateMenus()
        updateStatus()
    }

    private func beginCanopy(seed: UInt64) {
        stopTicking()
        simulation = CanopySimulation(seed: seed)
        latestEvent = "The jungle waits for green."
        presentationRevision += 1
        scene = CanopyScene(snapshot: presentationSnapshot())
        skView.presentScene(scene)
        updateMenus()
        updateStatus()
        if clockMode != .paused { startTicking() }
    }

    private func startTicking() {
        stopTicking()
        scheduleNextTick()
    }

    private func scheduleNextTick() {
        guard let delay = clockSchedule.delay(
            for: clockMode,
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
        latestEvent = simulation.tick().last ?? ""
        presentationRevision += 1
        scene.apply(presentationSnapshot())
        if soundEnabled { soundPlayer.play(simulation.latestVisualEvent) }
        updateMenus()
        updateStatus()
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func presentationSnapshot() -> CanopyPresentationSnapshot {
        CanopyPresentationSnapshot(
            simulation: simulation,
            latestEvent: latestEvent,
            revision: presentationRevision
        )
    }

    private func updateMenus() {
        guard runTitleItem != nil else { return }
        runTitleItem.title = "CORNERWORLD  •  CANOPY  •  \(clockMode.title.uppercased())  •  SEED \(seedText)"
        for item in growthMenu.items {
            item.state = item.tag == clockMode.rawValue ? .on : .off
        }
        soundItem.state = soundEnabled ? .on : .off
        soundItem.title = "Swing sound — \(soundEnabled ? "On" : "Off")"

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
        let accent: NSColor = simulation.density > 75 ? .systemGreen : colorForDensity()
        button.image = MenuBarPresentation.canopyIcon(accent: accent)
        button.attributedTitle = MenuBarPresentation.canopyTitle(
            vines: simulation.vines.count,
            density: simulation.density
        )
        button.setAccessibilityLabel("Cornerworld Canopy status")
        button.setAccessibilityValue("\(simulation.vines.count) vines; \(simulation.density) percent growth; sound \(soundEnabled ? "on" : "off")")
        button.toolTip = "CORNERWORLD — CANOPY\n\(simulation.vines.count) vines · \(simulation.density)% growth\n\(clockMode.menuTitle)\nSwing sound \(soundEnabled ? "on" : "off")\nSeed \(seedText)"
    }

    private func colorForDensity() -> NSColor {
        simulation.density < 25 ? .systemMint : .systemGreen
    }
}
