import SwiftUI
import AppKit
import ServiceManagement
import Combine

// MARK: - Panels

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Lets the very first click act on the view even though the panel never activates the app.
final class FirstClickHostingView<V: View>: NSHostingView<V> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - Visit controller (character walks in, asks, walks out)

final class VisitController {
    private let store: Store
    private let scheduler: VisitScheduler
    private var panel: FloatingPanel?
    private var model: VisitModel?
    private var tween: Timer?
    private var fromRight = true
    var onBegin: () -> Void = {}
    var onEnd: () -> Void = {}

    init(store: Store, scheduler: VisitScheduler) {
        self.store = store
        self.scheduler = scheduler
    }

    private var screenFrame: NSRect { (NSScreen.main ?? NSScreen.screens[0]).visibleFrame }

    /// Panel origin for a given horizontal character centre (the character stands at the panel's bottom centre).
    private func origin(centerX: CGFloat, y: CGFloat) -> NSPoint {
        NSPoint(x: centerX - VisitMetrics.size.width / 2, y: y)
    }

    private var cornerOrigin: NSPoint {
        let f = screenFrame
        return origin(centerX: fromRight ? f.maxX + 90 : f.minX - 90, y: f.minY + 4)
    }

    private var centerOrigin: NSPoint {
        let f = screenFrame
        let y = min(f.midY - 200, f.maxY - VisitMetrics.size.height - 10)
        return origin(centerX: f.midX, y: max(f.minY + 20, y))
    }

    func begin(_ kind: VisitKind) {
        fromRight = Bool.random()
        var recapIDs: [UUID] = []
        var recapDay: Date?
        if kind == .morning, let day = store.lastCompletionDay() {
            recapIDs = store.completed(on: day).map { $0.id }
            recapDay = day
        }
        let model = VisitModel(kind: kind, stage: .walkingIn, facing: fromRight ? -1 : 1,
                               reviewIDs: store.openTasks.map { $0.id },
                               recapIDs: recapIDs, recapDay: recapDay)
        model.onLater = { [weak self] in self?.leave(snooze: true) }
        model.onFinish = { [weak self] in self?.farewell() }
        self.model = model
        onBegin()

        let panel = FloatingPanel(
            contentRect: NSRect(origin: cornerOrigin, size: VisitMetrics.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces]
        panel.ignoresMouseEvents = true            // clicks pass through while walking
        let host = FirstClickHostingView(rootView: VisitView(model: model, store: store))
        host.sizingOptions = []
        panel.contentView = host
        panel.orderFrontRegardless()
        self.panel = panel

        walk(to: centerOrigin, duration: 4.5) { [weak self] in
            guard let self = self, let model = self.model else { return }
            model.facing = 0
            model.stage = model.firstStage
            self.panel?.ignoresMouseEvents = false
            NSApp.activate(ignoringOtherApps: true)
            self.panel?.makeKey()
        }
    }

    private func farewell() {
        guard let model = model else { return }
        if model.kind == .evening && model.carryOver {
            let n = store.urgentTasks.count
            if n > 0 { store.carryOver() }
            model.carried = n
        }
        model.stage = .farewell
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in self?.leave(snooze: false) }
    }

    private func leave(snooze: Bool) {
        guard let model = model, let panel = panel else { return }
        panel.ignoresMouseEvents = true
        model.facing = fromRight ? 1 : -1
        model.stage = .walkingOut
        walk(to: cornerOrigin, duration: 3.5) { [weak self] in
            panel.orderOut(nil)
            self?.panel = nil
            self?.model = nil
            if snooze { self?.scheduler.snooze() } else { self?.scheduler.complete() }
            self?.onEnd()
        }
    }

    /// Moves the panel in a straight line with a gentle ease in/out.
    private func walk(to target: NSPoint, duration: Double, completion: @escaping () -> Void) {
        guard let panel = panel else { return }
        tween?.invalidate()
        let start = panel.frame.origin
        let t0 = Date()
        tween = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            let raw = min(1, Date().timeIntervalSince(t0) / duration)
            let e = CGFloat(0.5 - 0.5 * cos(Double.pi * raw))
            panel.setFrameOrigin(NSPoint(x: start.x + (target.x - start.x) * e,
                                         y: start.y + (target.y - start.y) * e))
            if raw >= 1 {
                timer.invalidate()
                self?.tween = nil
                completion()
            }
        }
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = Store()
    let settings = Settings()
    let ui = UIState()
    lazy var scheduler = VisitScheduler(settings: settings)
    lazy var visit = VisitController(store: store, scheduler: scheduler)
    lazy var nudges = NudgeScheduler(settings: settings, store: store)
    lazy var bedtime = BedtimeScheduler(settings: settings, store: store)
    var mascot: FloatingPanel!
    var overlay: FloatingPanel!
    var listPanel: FloatingPanel!
    var moodTimer: Timer?
    var sigterm: DispatchSourceSignal?
    var bubbleToken = 0
    var celebrateToken = 0
    var statusItem: NSStatusItem!
    var loginItem: NSMenuItem!
    var hoverTimer: Timer?
    var cornerObserver: Any?

    private let listSize = NSSize(width: 360, height: 500)

    private var screenFrame: NSRect { (NSScreen.main ?? NSScreen.screens[0]).visibleFrame }

    /// A menu-bar-only app has no main menu, so Cmd+V/C/X/A/Z would not reach text fields.
    /// This invisible Edit menu supplies those shortcuts.
    private func setupEditMenu() {
        let main = NSMenu()
        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        NSApp.mainMenu = main
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        setupEditMenu()
        setupOverlay()
        setupMascot()
        setupListPanel()
        setupStatusItem()

        // SwiftUI .onHover is unreliable for a non-activating panel in a background app,
        // so poll the cursor position for the mascot's wave.
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self = self, self.mascot.isVisible else { return }
            let inside = self.mascot.frame.contains(NSEvent.mouseLocation)
            if self.ui.mascotHover != inside { self.ui.mascotHover = inside }
        }

        // Move the mascot when the corner setting changes.
        cornerObserver = settings.$corner.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.placeMascot(); self?.placeOverlay(); self?.placeList() }
        }

        visit.onBegin = { [weak self] in
            self?.closeList()
            self?.clearBubble()
            self?.mascot.orderOut(nil)
            self?.overlay.orderOut(nil)
        }
        visit.onEnd = { [weak self] in
            self?.overlay.orderFrontRegardless()
            self?.mascot.orderFrontRegardless()
            self?.nudges.reset()
        }
        scheduler.onVisit = { [weak self] kind in self?.visit.begin(kind) }
        scheduler.start()

        // Due-date nudges.
        nudges.isBusy = { [weak self] in
            guard let self = self else { return true }
            return self.scheduler.visiting || self.ui.listOpen
        }
        nudges.onNudge = { [weak self] msg in self?.showNudge(msg) }
        nudges.start()

        // Bedtime reminder: sleepy Tick tells you to stop if you are still working after 10 PM.
        bedtime.isBusy = { [weak self] in
            guard let self = self else { return true }
            return self.scheduler.visiting || self.ui.listOpen
        }
        bedtime.onRemind = { [weak self] msg in self?.showBedtime(msg) }
        bedtime.start()

        // Celebrate finished tasks.
        store.onCompleted = { [weak self] _ in self?.celebrate() }

        // Sleepy late at night / very early.
        updateMood()
        moodTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.updateMood() }

        // Make sure a pending debounced save is written when the app is stopped.
        signal(SIGTERM, SIG_IGN)
        let src = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        src.setEventHandler { [weak self] in self?.store.flush(); NSApp.terminate(nil) }
        src.resume()
        sigterm = src

        // Enable launch at login on first run.
        if !UserDefaults.standard.bool(forKey: "didSetupLogin") {
            UserDefaults.standard.set(true, forKey: "didSetupLogin")
            try? SMAppService.mainApp.register()
        }
        refreshLoginItem()
    }

    func applicationWillTerminate(_ n: Notification) { store.flush() }

    // MARK: Mood, nudges, celebrations

    private func updateMood() {
        let sleepy = BedtimeScheduler.isNight()
        if ui.sleepy != sleepy { ui.sleepy = sleepy }
    }

    private func clearBubble() {
        bubbleToken += 1
        ui.bubble = nil
        ui.alerting = false
    }

    private func showBubble(_ msg: BubbleMessage, alert: Bool, seconds: Double) {
        bubbleToken += 1
        let token = bubbleToken
        ui.bubble = msg
        ui.alerting = alert
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self = self, self.bubbleToken == token else { return }
            self.ui.bubble = nil
            self.ui.alerting = false
        }
    }

    private func showNudge(_ msg: BubbleMessage) {
        guard !scheduler.visiting else { return }
        mascot.orderFrontRegardless()
        showBubble(msg, alert: true, seconds: 8)
    }

    /// Stays in the sleepy pose (no alarmed look) and the bubble lasts a bit longer.
    private func showBedtime(_ msg: BubbleMessage) {
        guard !scheduler.visiting else { return }
        mascot.orderFrontRegardless()
        showBubble(msg, alert: false, seconds: 10)
    }

    private func celebrate() {
        guard !scheduler.visiting else { return }
        celebrateToken += 1
        let token = celebrateToken
        ui.confettiStart = Date()
        ui.celebrating = true
        showBubble(BubbleMessage(kind: .celebrate, title: "Nice work!",
                                 subtitle: "\(plural(store.openCount, "task")) left.",
                                 accent: Palette.green), alert: false, seconds: 2.7)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) { [weak self] in
            guard let self = self, self.celebrateToken == token else { return }
            self.ui.celebrating = false
        }
    }

    // MARK: Mascot

    private func setupOverlay() {
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: OverlayMetrics.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces]
        panel.ignoresMouseEvents = true            // purely visual; clicks go through to whatever is below
        overlay = panel
        placeOverlay()
        panel.orderFrontRegardless()
    }

    private func placeOverlay() {
        let f = screenFrame
        let m = MascotMetrics.margin
        let c = settings.corner
        let x = c.isRight ? f.maxX - OverlayMetrics.size.width - m : f.minX + m
        let y = c.isTop ? f.maxY - OverlayMetrics.size.height - m : f.minY + m
        overlay.setFrameOrigin(NSPoint(x: x, y: y))
        overlay.contentView = NSHostingView(rootView:
            MascotOverlayView(store: store, ui: ui, corner: c))
    }

    private func setupMascot() {
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: MascotMetrics.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        // On every Space, but not over full-screen apps (no .fullScreenAuxiliary).
        panel.collectionBehavior = [.canJoinAllSpaces]

        mascot = panel
        placeMascot()
        panel.orderFrontRegardless()
    }

    private func placeMascot() {
        let f = screenFrame
        let m = MascotMetrics.margin
        let c = settings.corner
        let x = c.isRight ? f.maxX - MascotMetrics.size.width - m : f.minX + m
        let y = c.isTop ? f.maxY - MascotMetrics.size.height - m : f.minY + m
        mascot.setFrameOrigin(NSPoint(x: x, y: y))
        // Re-create the root so the character faces into the screen.
        let root = MascotView(store: store, ui: ui, corner: c)
        let host = FirstClickHostingView(rootView: root.onTapGesture { [weak self] in
            self?.clearBubble()
            self?.toggleList()
        })
        host.sizingOptions = []
        mascot.contentView = host
    }

    // MARK: Task list

    private func setupListPanel() {
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: listSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces]

        let host = FirstClickHostingView(rootView: ContentView(
            store: store, settings: settings,
            visitNow: { [weak self] kind in self?.closeList(); self?.scheduler.visitNow(kind) },
            testNudge: { [weak self] in self?.testNudge() },
            onClose: { [weak self] in self?.closeList() }))
        host.sizingOptions = []
        panel.contentView = host
        listPanel = panel
    }

    /// Opens next to the mascot, growing away from the screen edge it sits on.
    private func placeList() {
        let f = screenFrame
        let mf = mascot.frame
        let gap: CGFloat = 8
        let c = settings.corner
        let x = c.isRight ? mf.maxX - listSize.width : mf.minX
        var y = c.isTop ? mf.minY - gap - listSize.height : mf.maxY + gap
        y = min(max(y, f.minY + 8), f.maxY - listSize.height - 8)
        listPanel.setFrame(NSRect(x: max(f.minX + 8, min(x, f.maxX - listSize.width - 8)), y: y,
                                  width: listSize.width, height: listSize.height), display: true)
    }

    private func toggleList() {
        if listPanel.isVisible { closeList() } else { openList() }
    }

    private func openList() {
        placeList()
        listPanel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        listPanel.makeKey()
        ui.listOpen = true
    }

    private func closeList() {
        listPanel.orderOut(nil)
        ui.listOpen = false
    }

    // MARK: Menu bar

    func applicationShouldHandleReopen(_ app: NSApplication, hasVisibleWindows: Bool) -> Bool {
        mascot.orderFrontRegardless()
        return true
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Tasks")
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Task List", action: #selector(openFromMenu), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Copy Standup Summary", action: #selector(copyStandup), keyEquivalent: "c").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Morning Visit Now", action: #selector(visitNow), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Evening Wrap-up Now", action: #selector(wrapNow), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Test Reminder", action: #selector(testNudgeFromMenu), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Test Bedtime Reminder", action: #selector(testBedtimeFromMenu), keyEquivalent: "").target = self
        loginItem = menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Tick", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
    }

    private func refreshLoginItem() {
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func openFromMenu() {
        mascot.orderFrontRegardless()
        openList()
    }

    @objc private func copyStandup() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(standupSummary(store.tasks), forType: .string)
        closeList()
        mascot.orderFrontRegardless()
        showBubble(BubbleMessage(kind: .celebrate, title: "Copied!",
                                 subtitle: "Standup summary is on your clipboard.",
                                 accent: Palette.green), alert: false, seconds: 3)
    }

    @objc private func visitNow() { scheduler.visitNow(.morning) }
    @objc private func wrapNow() { scheduler.visitNow(.evening) }
    @objc private func testNudgeFromMenu() { testNudge() }
    @objc private func testBedtimeFromMenu() { testBedtime() }

    private func testBedtime() {
        closeList()
        bedtime.test()
    }

    /// Previews the reminder now. The bubble stays hidden while the list is open, so close it first.
    private func testNudge() {
        closeList()
        nudges.test()
    }

    @objc private func toggleLogin() {
        let svc = SMAppService.mainApp
        if svc.status == .enabled { try? svc.unregister() } else { try? svc.register() }
        refreshLoginItem()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

// MARK: - Entry point

if CommandLine.arguments.contains("--snapshot") {
    runSnapshots()
} else {
    migrateLegacyDefaults()
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
