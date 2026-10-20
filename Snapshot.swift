import SwiftUI
import AppKit

/// Renders the UI to PNGs so the visuals can be checked without screen-recording permission.
/// Usage: Tick --snapshot /output/dir
func runSnapshots() {
    snapshotMode = true
    _ = NSApplication.shared

    let args = CommandLine.arguments
    let outDir = URL(fileURLWithPath: args[(args.firstIndex(of: "--snapshot") ?? 0) + 1])
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

    // Scratch store: never touches real data.
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("tick-snap-\(UUID().uuidString).json")
    let store = Store(file: tmp)
    let cal = Calendar.current
    func day(_ n: Int) -> Date? { cal.date(byAdding: .day, value: n, to: Date()) }
    let yesterday = cal.date(byAdding: .day, value: -1, to: Date())
    store.tasks = [
        TaskItem(title: "Fix batch FAT failure in jms bucket", done: false, priority: .high, due: day(-1), progress: 0.5,
                 notes: "Done: reproduced locally, found stale autoFVT copy.\nPending: re-run jms bucket, update PR."),
        TaskItem(title: "Review Liberty CVE PR", done: false, priority: .high, due: day(0), progress: 1.0 / 3,
                 subtasks: [Subtask(title: "Read the diff", done: true),
                            Subtask(title: "Check bnd.bnd change", done: false),
                            Subtask(title: "Approve or comment", done: false)]),
        TaskItem(title: "Prepare sprint demo", done: false, priority: .medium, due: day(2), progress: 0),
        TaskItem(title: "Update onboarding doc", done: false, priority: .medium, due: day(7), progress: 0.75),
        TaskItem(title: "Clean up old branches", done: false, priority: .low, due: nil, progress: 0),
        TaskItem(title: "Reply to design review", done: true, priority: .medium, due: day(-2), progress: 1,
                 completedAt: yesterday),
        TaskItem(title: "Merge CVE fix PR", done: true, priority: .high, due: day(-1), progress: 1,
                 completedAt: yesterday),
    ]
    let settings = Settings()

    func backdrop<V: View>(_ w: CGFloat, _ h: CGFloat, _ v: V) -> some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.25, blue: 0.45), Color(red: 0.42, green: 0.30, blue: 0.55)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            v
        }
        .frame(width: w, height: h)
    }

    func render<V: View>(_ name: String, _ size: CGSize, _ view: V) {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        let win = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        win.appearance = NSAppearance(named: .darkAqua)
        win.contentView = host
        for _ in 0..<4 {
            host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: outDir.appendingPathComponent(name + ".png"))
            print("wrote \(name).png")
        }
    }

    // Task list panel.
    render("note", CGSize(width: 400, height: 540),
           backdrop(400, 540, ContentView(store: store, settings: settings, visitNow: { _ in }, testNudge: {}, onClose: {})
                        .frame(width: 360, height: 500)))

    // Archive view.
    render("archive", CGSize(width: 400, height: 540),
           backdrop(400, 540, ContentView(store: store, settings: settings, visitNow: { _ in }, testNudge: {},
                                          archiveOpen: true, onClose: {})
                        .frame(width: 360, height: 500)))

    // Settings strip.
    render("settings", CGSize(width: 400, height: 220),
           backdrop(400, 220, SettingsView(settings: settings, visitNow: { _ in }, testNudge: {})
                        .frame(width: 332)))

    // Task rows: checklist open, delete confirmation.
    var checklistTask = store.tasks[1]
    var confirmTask = store.tasks[0]
    render("row_states", CGSize(width: 400, height: 330),
           backdrop(400, 330, VStack(spacing: 10) {
               TaskRow(task: Binding(get: { checklistTask }, set: { checklistTask = $0 }), stepsOpen: true, onDelete: {})
               TaskRow(task: Binding(get: { confirmTask }, set: { confirmTask = $0 }), confirming: true, onDelete: {})
           }.padding(.horizontal, 20)))

    // Character poses.
    let poses: [(String, Pose, CGFloat, Double)] = [
        ("char_idle", .idle, 0, 10.0), ("char_wave", .wave, -1, 10.17),
        ("char_walk", .walking, -1, 10.34), ("char_cheer", .cheer, 0, 10.2),
    ]
    render("characters", CGSize(width: 520, height: 180),
           backdrop(520, 180, HStack(spacing: 4) {
               ForEach(poses, id: \.0) { _, p, f, t in CharacterView(pose: p, facing: f, fixedTime: t) }
           }))
    let moods: [(String, Pose, CGFloat, Double)] = [
        ("sleepy", .sleepy, 0, 10.4), ("relaxed", .relaxed, 0, 10.6), ("alert", .alert, 0, 10.2),
    ]
    render("moods", CGSize(width: 400, height: 180),
           backdrop(400, 180, HStack(spacing: 4) {
               ForEach(moods, id: \.0) { _, p, f, t in CharacterView(pose: p, facing: f, fixedTime: t) }
           }))

    // Corner mascot (idle, hover wave, no tasks) with its overlay: hover message, nudge, confetti.
    let ui = UIState()
    let hoverUI = UIState(); hoverUI.mascotHover = true
    let emptyStore = Store(file: tmp.deletingLastPathComponent().appendingPathComponent("tick-empty-\(UUID().uuidString).json"))
    render("mascot", CGSize(width: 360, height: 150),
           backdrop(360, 150, HStack(spacing: 30) {
               MascotView(store: store, ui: ui, corner: .bottomRight)
               MascotView(store: store, ui: hoverUI, corner: .bottomLeft)
               MascotView(store: emptyStore, ui: UIState(), corner: .bottomLeft)
           }))

    let osize = OverlayMetrics.size
    func overlayShot(_ name: String, _ store: Store, _ ui: UIState, _ corner: Corner,
                     message: BubbleMessage? = nil, confetti: Double? = nil, pose: Pose? = nil) {
        render(name, CGSize(width: osize.width + 40, height: osize.height + 20),
               backdrop(osize.width + 40, osize.height + 20, ZStack(alignment: .bottomTrailing) {
                   MascotOverlayView(store: store, ui: ui, corner: corner, forcedMessage: message, confettiTime: confetti)
                   MascotView(store: store, ui: ui, corner: corner)
                       .frame(width: MascotMetrics.size.width, height: MascotMetrics.size.height)
               }.padding(.trailing, 10).padding(.bottom, 10)))
    }
    overlayShot("overlay_hover", store, hoverUI, .bottomRight, message: store.hoverMessage())
    let nudgeUI = UIState(); nudgeUI.alerting = true
    overlayShot("overlay_nudge", store, nudgeUI, .bottomRight, message: BubbleMessage(
        kind: .nudge, title: "Overdue: Fix batch FAT failure in jms…", subtitle: "+1 more need attention. Click me!",
        accent: Palette.red))
    let celebUI = UIState(); celebUI.celebrating = true
    overlayShot("overlay_confetti", store, celebUI, .bottomRight, message: BubbleMessage(
        kind: .celebrate, title: "Nice work!", subtitle: "5 tasks left.", accent: Palette.green), confetti: 0.7)
    overlayShot("overlay_empty_hover", emptyStore, hoverUI, .bottomRight, message: emptyStore.hoverMessage())

    // Visit stages (full size, as shown on screen).
    let vsize = VisitMetrics.size
    let ids = store.openTasks.map { $0.id }
    let recap = store.completed(on: yesterday ?? Date()).map { $0.id }
    let recapModel = VisitModel(kind: .morning, stage: .recap, facing: 0, reviewIDs: ids,
                                recapIDs: recap, recapDay: yesterday)
    render("visit_recap", vsize, backdrop(vsize.width, vsize.height, VisitView(model: recapModel, store: store)))

    let reviewModel = VisitModel(stage: .review, facing: 0, reviewIDs: ids)
    render("visit_review", vsize, backdrop(vsize.width, vsize.height, VisitView(model: reviewModel, store: store)))

    let reviewModel2 = VisitModel(stage: .review, facing: 0, reviewIDs: ids)
    reviewModel2.index = 1
    render("visit_review_checklist", vsize, backdrop(vsize.width, vsize.height, VisitView(model: reviewModel2, store: store)))

    let planModel = VisitModel(stage: .plan, facing: 0, reviewIDs: ids)
    if let a = store.add("Write unit tests for scheduler", priority: .high) { planModel.addedIDs.append(a) }
    if let b = store.add("Book dentist", priority: .low) { planModel.addedIDs.append(b) }
    render("visit_plan", vsize, backdrop(vsize.width, vsize.height, VisitView(model: planModel, store: store)))

    let summaryModel = VisitModel(kind: .evening, stage: .summary, facing: 0, reviewIDs: ids)
    render("visit_summary", vsize, backdrop(vsize.width, vsize.height, VisitView(model: summaryModel, store: store)))

    let farewellModel = VisitModel(stage: .farewell, facing: 0, reviewIDs: ids)
    render("visit_farewell", vsize, backdrop(vsize.width, vsize.height, VisitView(model: farewellModel, store: store)))

    try? FileManager.default.removeItem(at: tmp)
}
