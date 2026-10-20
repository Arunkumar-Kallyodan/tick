import SwiftUI
import AppKit

// MARK: - Palette

enum Palette {
    static let red    = Color(red: 0.93, green: 0.35, blue: 0.36)
    static let amber  = Color(red: 0.97, green: 0.69, blue: 0.22)
    static let slate  = Color(red: 0.45, green: 0.62, blue: 0.85)
    static let green  = Color(red: 0.31, green: 0.78, blue: 0.51)
    static let yellow = Color(red: 0.93, green: 0.82, blue: 0.30)
}

// MARK: - Task model

enum Priority: Int, Codable, CaseIterable {
    case high = 0, medium, low

    var short: String { "P\(rawValue + 1)" }

    var name: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    var color: Color {
        switch self {
        case .high: return Palette.red
        case .medium: return Palette.amber
        case .low: return Palette.slate
        }
    }
}

struct Subtask: Codable, Identifiable {
    var id = UUID()
    var title = ""
    var done = false
}

struct TaskItem: Codable, Identifiable {
    var id = UUID()
    var title = ""
    var done = false
    var priority = Priority.medium
    var due: Date?
    var progress = 0.0          // 0...1
    var created = Date()
    var notes = ""              // free text: what is done, what is pending
    var subtasks: [Subtask] = []   // checklist
    var completedAt: Date?      // when it was marked done (for the daily summaries)

    var doneSubtasks: Int { subtasks.filter { $0.done }.count }

    mutating func toggleDone() {
        if done {
            done = false
            completedAt = nil
            if progress >= 1 { progress = 0 }
        } else {
            done = true
            completedAt = Date()
            progress = 1
        }
    }

    mutating func setProgress(_ p: Double) {
        progress = min(1, max(0, p))
        let nowDone = progress >= 1
        if nowDone && !done { completedAt = Date() }
        if !nowDone { completedAt = nil }
        done = nowDone
    }

    /// Ticking a checklist item moves the progress bar to done/total.
    mutating func toggleSubtask(_ id: UUID) {
        guard let i = subtasks.firstIndex(where: { $0.id == id }) else { return }
        subtasks[i].done.toggle()
        setProgress(Double(doneSubtasks) / Double(subtasks.count))
    }

    mutating func addSubtask(_ title: String) {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        subtasks.append(Subtask(title: t))
        // A finished task gets reopened by a new unfinished item.
        if done { setProgress(Double(doneSubtasks) / Double(subtasks.count)) }
    }

    mutating func removeSubtask(_ id: UUID) {
        subtasks.removeAll { $0.id == id }
        if !subtasks.isEmpty { setProgress(Double(doneSubtasks) / Double(subtasks.count)) }
    }
}

/// Tolerant decoding: tasks saved before a field existed (e.g. `notes`) still load.
extension TaskItem {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title       = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        done        = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
        priority    = try c.decodeIfPresent(Priority.self, forKey: .priority) ?? .medium
        due         = try c.decodeIfPresent(Date.self, forKey: .due)
        progress    = try c.decodeIfPresent(Double.self, forKey: .progress) ?? 0
        created     = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        notes       = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        subtasks    = try c.decodeIfPresent([Subtask].self, forKey: .subtasks) ?? []
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
    }
}

/// Text + colour for the due-date chip. Colour encodes urgency.
func dueInfo(_ t: TaskItem) -> (text: String, color: Color)? {
    guard let due = t.due else { return nil }
    let cal = Calendar.current
    let text: String
    if cal.isDateInToday(due) { text = "Today" }
    else if cal.isDateInTomorrow(due) { text = "Tomorrow" }
    else if cal.isDateInYesterday(due) { text = "Yesterday" }
    else {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        text = f.string(from: due)
    }
    if t.done { return (text, .secondary) }
    let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
                                  to: cal.startOfDay(for: due)).day ?? 0
    switch days {
    case ..<0: return (text, Palette.red)
    case 0:    return (text, Palette.amber)
    case 1...2: return (text, Palette.yellow)
    default:   return (text, .secondary)
    }
}

func hourLabel(_ h: Int) -> String {
    let suffix = h < 12 ? "AM" : "PM"
    let hh = h % 12 == 0 ? 12 : h % 12
    return "\(hh) \(suffix)"
}

func dayKey(_ date: Date = Date()) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
}

func shortened(_ s: String, _ n: Int) -> String {
    s.count > n ? String(s.prefix(n - 1)) + "…" : s
}

func plural(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s")" }

// MARK: - Settings

enum Corner: Int, CaseIterable {
    case bottomRight = 0, bottomLeft, topRight, topLeft

    var label: String {
        switch self {
        case .bottomRight: return "Bottom right"
        case .bottomLeft: return "Bottom left"
        case .topRight: return "Top right"
        case .topLeft: return "Top left"
        }
    }
    var isRight: Bool { self == .bottomRight || self == .topRight }
    var isTop: Bool { self == .topRight || self == .topLeft }
}

final class Settings: ObservableObject {
    private let d = UserDefaults.standard

    @Published var opacity: Double { didSet { d.set(opacity, forKey: "opacity") } }
    @Published var visitHour: Int { didSet { d.set(visitHour, forKey: "visitHour") } }
    @Published var corner: Corner { didSet { d.set(corner.rawValue, forKey: "corner") } }
    @Published var wrapUp: Bool { didSet { d.set(wrapUp, forKey: "wrapUp") } }
    @Published var wrapHour: Int { didSet { d.set(wrapHour, forKey: "wrapHour") } }
    @Published var nudges: Bool { didSet { d.set(nudges, forKey: "nudges") } }

    static let windowStart = 9
    static let windowEnd = 18          // morning visits and nudges only happen before 6 PM
    static let wrapStart = 12          // earliest hour you can pick for the evening wrap-up
    static let wrapLast = 22           // latest hour you can pick (10 PM)
    static let wrapEnd = 23            // a wrap-up still starts up to 11 PM if the Mac was asleep

    init() {
        opacity   = d.object(forKey: "opacity") as? Double ?? 0.92
        visitHour = d.object(forKey: "visitHour") as? Int ?? 9
        corner    = Corner(rawValue: d.integer(forKey: "corner")) ?? .bottomRight
        wrapUp    = d.object(forKey: "wrapUp") as? Bool ?? true
        wrapHour  = d.object(forKey: "wrapHour") as? Int ?? 17
        nudges    = d.object(forKey: "nudges") as? Bool ?? true
    }
}

// MARK: - Store

final class Store: ObservableObject {
    @Published var tasks: [TaskItem] = [] {
        didSet {
            scheduleSave()
            reportCompletions(since: oldValue)
        }
    }
    /// Called when a task changes from open to done.
    var onCompleted: ((TaskItem) -> Void)?

    private let url: URL
    private var saveWork: DispatchWorkItem?

    /// `file` is only overridden by the snapshot tool so it never touches real data.
    init(file: URL? = nil) {
        if let file = file {
            url = file
        } else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("DeskTasks", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            url = dir.appendingPathComponent("tasks.json")
        }
        if let data = try? Data(contentsOf: url) {
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            tasks = (try? dec.decode([TaskItem].self, from: data)) ?? []
        }
    }

    // Saving is debounced: typing in a note rewrites the file once, not on every keystroke.
    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.writeNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    /// Writes any pending change immediately. Called when the app quits.
    func flush() {
        guard let work = saveWork else { return }
        work.cancel()
        writeNow()
    }

    private func writeNow() {
        saveWork = nil
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(tasks) { try? data.write(to: url, options: .atomic) }
    }

    private func reportCompletions(since old: [TaskItem]) {
        guard let callback = onCompleted else { return }
        let wasDone = Dictionary(old.map { ($0.id, $0.done) }, uniquingKeysWith: { a, _ in a })
        for t in tasks where t.done && wasDone[t.id] == false { callback(t) }
    }

    /// Open first, then priority, then earliest due date, then oldest.
    private func before(_ a: TaskItem, _ b: TaskItem) -> Bool {
        if a.done != b.done { return !a.done }
        if a.priority != b.priority { return a.priority.rawValue < b.priority.rawValue }
        switch (a.due, b.due) {
        case let (x?, y?): return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default: return a.created < b.created
        }
    }

    /// Open tasks of one priority. Finished tasks live in the archive.
    func tasks(for p: Priority) -> [TaskItem] {
        tasks.filter { $0.priority == p && !$0.done }.sorted(by: before)
    }

    /// Finished tasks, most recently finished first (tasks finished before dates were recorded come last).
    var archived: [TaskItem] {
        tasks.filter { $0.done }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var openCount: Int { tasks.filter { !$0.done }.count }

    /// Open tasks that are overdue or due today, most important first.
    var urgentTasks: [TaskItem] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return tasks.filter { t in
            guard !t.done, let due = t.due else { return false }
            return cal.startOfDay(for: due) <= today
        }.sorted(by: before)
    }

    /// True when an unfinished task is overdue or due today (turns the mascot badge red).
    var hasUrgent: Bool { !urgentTasks.isEmpty }

    /// Everything not finished yet, most important first.
    var openTasks: [TaskItem] {
        tasks.filter { !$0.done }.sorted(by: before)
    }

    /// Tasks completed on the given day, in the order they were finished.
    func completed(on day: Date) -> [TaskItem] {
        let cal = Calendar.current
        return tasks.filter { t in
            guard let c = t.completedAt else { return false }
            return cal.isDate(c, inSameDayAs: day)
        }.sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
    }

    /// The most recent day before today (within the last week) on which something was finished.
    func lastCompletionDay() -> Date? {
        let today = Calendar.current.startOfDay(for: Date())
        let weekAgo = today.addingTimeInterval(-7 * 86400)
        return tasks.compactMap { $0.completedAt }.filter { $0 < today && $0 > weekAgo }.max()
    }

    /// Moves every open task that is overdue or due today to tomorrow.
    func carryOver() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) else { return }
        var copy = tasks
        for i in copy.indices where !copy[i].done {
            if let due = copy[i].due, cal.startOfDay(for: due) <= today { copy[i].due = tomorrow }
        }
        tasks = copy
    }

    func binding(_ id: UUID) -> Binding<TaskItem> {
        Binding(
            get: { self.tasks.first { $0.id == id } ?? TaskItem() },
            set: { new in
                if let i = self.tasks.firstIndex(where: { $0.id == id }) { self.tasks[i] = new }
            })
    }

    @discardableResult
    func add(_ title: String, priority: Priority) -> UUID? {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        let item = TaskItem(title: t, priority: priority)
        tasks.append(item)
        return item.id
    }

    func delete(_ id: UUID) { tasks.removeAll { $0.id == id } }

    /// What Tick says when the mouse is over him.
    func hoverMessage() -> BubbleMessage {
        let open = openCount
        if open == 0 {
            return BubbleMessage(key: "hover", kind: .hover, title: "Nothing is pending right now.",
                                 subtitle: "Click me to add a task.", accent: Palette.green)
        }
        let urgent = urgentTasks.count
        return BubbleMessage(key: "hover", kind: .hover,
                             title: "You have \(plural(open, "task")) going on.",
                             subtitle: "Click me to view them.",
                             warning: urgent > 0 ? "\(urgent) due today or overdue" : nil,
                             accent: urgent > 0 ? Palette.red : Palette.slate)
    }
}

// MARK: - Mascot state

enum Pose { case walking, idle, cheer, wave, relaxed, sleepy, alert }

struct BubbleMessage: Identifiable {
    enum Kind { case hover, nudge, celebrate }

    var key = UUID().uuidString
    var kind: Kind
    var title: String
    var subtitle: String?
    var warning: String?
    var accent: Color = Palette.slate

    var id: String { key }
}

/// UI state shared between the corner mascot, its speech bubble and the list panel.
final class UIState: ObservableObject {
    @Published var listOpen = false
    @Published var mascotHover = false
    @Published var sleepy = false           // late at night
    @Published var celebrating = false      // just finished something
    @Published var alerting = false         // a due-date nudge is showing
    @Published var bubble: BubbleMessage?   // nudge / celebration message
    @Published var confettiStart: Date?
}

// MARK: - Visits (morning review, evening wrap-up)

enum VisitKind { case morning, evening }

enum VisitStage { case walkingIn, recap, review, plan, summary, farewell, walkingOut }

enum VisitMetrics {
    static let size = CGSize(width: 440, height: 640)
}

/// State shared between the visit window controller and the character/bubble views.
final class VisitModel: ObservableObject {
    let kind: VisitKind
    @Published var stage: VisitStage
    @Published var facing: CGFloat           // -1 left, 1 right, 0 facing the user
    @Published var reviewIDs: [UUID]         // open tasks to reconfirm (snapshot at arrival)
    @Published var index = 0                 // which review card is showing
    @Published var addedIDs: [UUID] = []     // tasks added during a morning visit
    @Published var carryOver = true          // evening: move due/overdue tasks to tomorrow
    @Published var carried = 0               // evening: how many tasks were moved to tomorrow
    let recapIDs: [UUID]                     // morning: tasks finished on the last active day
    let recapDay: Date?

    var onLater: () -> Void = {}
    var onFinish: () -> Void = {}

    init(kind: VisitKind = .morning, stage: VisitStage = .walkingIn, facing: CGFloat = 0,
         reviewIDs: [UUID] = [], recapIDs: [UUID] = [], recapDay: Date? = nil) {
        self.kind = kind
        self.stage = stage
        self.facing = facing
        self.reviewIDs = reviewIDs
        self.recapIDs = recapIDs
        self.recapDay = recapDay
    }

    /// The screen after the last review card.
    var afterReview: VisitStage { kind == .morning ? .plan : .summary }

    /// Where the visit starts once Tick reaches the middle of the screen.
    var firstStage: VisitStage {
        if kind == .morning && !recapIDs.isEmpty { return .recap }
        return reviewIDs.isEmpty ? afterReview : .review
    }

    func next() {
        switch stage {
        case .recap:
            index = 0
            stage = reviewIDs.isEmpty ? afterReview : .review
        case .review:
            if index + 1 < reviewIDs.count { index += 1 } else { stage = afterReview }
        default: break
        }
    }

    var canGoBack: Bool {
        switch stage {
        case .review: return index > 0 || !recapIDs.isEmpty
        case .plan, .summary: return !reviewIDs.isEmpty || !recapIDs.isEmpty
        default: return false
        }
    }

    func back() {
        switch stage {
        case .review:
            if index > 0 { index -= 1 } else if !recapIDs.isEmpty { stage = .recap }
        case .plan, .summary:
            if !reviewIDs.isEmpty {
                index = reviewIDs.count - 1
                stage = .review
            } else if !recapIDs.isEmpty {
                stage = .recap
            }
        default: break
        }
    }

    var pose: Pose {
        switch stage {
        case .walkingIn, .walkingOut: return .walking
        case .recap, .review, .plan, .summary: return .idle
        case .farewell: return .cheer
        }
    }

    var showsBubble: Bool {
        switch stage {
        case .walkingIn, .walkingOut: return false
        default: return true
        }
    }
}

/// Triggers one morning visit per day (from the configured hour, before 6 PM) and one evening
/// wrap-up (from the wrap-up hour, up to 10 PM or a bit later if the Mac was asleep). If the Mac
/// was asleep or the app closed, the visit happens as soon as the app is next running in its window.
final class VisitScheduler {
    private let settings: Settings
    private let d = UserDefaults.standard
    private var snoozeUntil = Date.distantPast
    private var timer: Timer?
    private var currentKind = VisitKind.morning
    private(set) var visiting = false
    var onVisit: ((VisitKind) -> Void)?

    init(settings: Settings) { self.settings = settings }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.tick() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.tick() }
        tick()
    }

    func tick() {
        guard !visiting, Date() >= snoozeUntil else { return }
        let h = Calendar.current.component(.hour, from: Date())
        if settings.wrapUp, h >= settings.wrapHour, h < Settings.wrapEnd {
            // In the wrap-up window the evening visit replaces a missed morning one.
            if d.string(forKey: "lastWrapDay") != dayKey() { begin(.evening) }
        } else if h >= settings.visitHour, h < Settings.windowEnd, d.string(forKey: "lastVisitDay") != dayKey() {
            begin(.morning)
        }
    }

    func visitNow(_ kind: VisitKind) { begin(kind) }

    private func begin(_ kind: VisitKind) {
        guard !visiting else { return }
        visiting = true
        currentKind = kind
        onVisit?(kind)
    }

    /// The visit was completed: no more visits of this kind today.
    func complete() {
        d.set(dayKey(), forKey: currentKind == .morning ? "lastVisitDay" : "lastWrapDay")
        if currentKind == .evening { d.set(dayKey(), forKey: "lastVisitDay") }
        visiting = false
    }

    func snooze() {
        snoozeUntil = Date().addingTimeInterval(30 * 60)
        visiting = false
    }
}

// MARK: - Due-date nudges

/// Every couple of hours during the day, Tick reminds you about tasks that are overdue or due today.
final class NudgeScheduler {
    static let interval: TimeInterval = 2 * 3600

    private let settings: Settings
    private let store: Store
    private let d = UserDefaults.standard
    private var timer: Timer?
    var isBusy: () -> Bool = { false }
    var onNudge: ((BubbleMessage) -> Void)?

    init(settings: Settings, store: Store) {
        self.settings = settings
        self.store = store
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.tick() }
    }

    /// Called after a visit, which already covered the open tasks.
    func reset() { d.set(Date().timeIntervalSince1970, forKey: "lastNudge") }

    func tick() {
        guard settings.nudges, !isBusy() else { return }
        let h = Calendar.current.component(.hour, from: Date())
        guard h >= Settings.windowStart, h < Settings.windowEnd else { return }
        // Wait for today's morning visit so Tick does not repeat himself.
        guard d.string(forKey: "lastVisitDay") == dayKey() else { return }
        guard Date().timeIntervalSince1970 - d.double(forKey: "lastNudge") >= Self.interval else { return }
        guard let msg = message() else { return }
        reset()
        onNudge?(msg)
    }

    /// The reminder for the most important overdue / due-today task, or nil if there is none.
    private func message() -> BubbleMessage? {
        let urgent = store.urgentTasks
        guard let first = urgent.first, let due = first.due else { return nil }
        let overdue = Calendar.current.startOfDay(for: due) < Calendar.current.startOfDay(for: Date())
        return BubbleMessage(
            kind: .nudge,
            title: (overdue ? "Overdue: " : "Due today: ") + shortened(first.title, 34),
            subtitle: urgent.count > 1 ? "+\(urgent.count - 1) more need attention. Click me!"
                                       : "Click me to open the list.",
            accent: overdue ? Palette.red : Palette.amber)
    }

    /// Shows a reminder right now to preview it. Uses a sample when nothing is due.
    func test() {
        onNudge?(message() ?? BubbleMessage(
            kind: .nudge,
            title: "Due today: Sample task",
            subtitle: "Nothing is due right now, so this is a preview. Click me!",
            accent: Palette.amber))
    }
}
