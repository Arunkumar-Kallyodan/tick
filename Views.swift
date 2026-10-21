import SwiftUI
import AppKit

/// Set by the snapshot tool: NSViewRepresentable blur can't be rendered offscreen.
var snapshotMode = false

// MARK: - Small shared pieces

struct VisualEffect: NSViewRepresentable {
    var opacity: Double

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) { v.alphaValue = opacity }
}

struct ProgressBar: View {
    @Binding var task: TaskItem

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(task.done ? Palette.green : task.priority.color)
                    .frame(width: max(0, geo.size.width * task.progress))
            }
            .frame(height: 5)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let raw = Double(v.location.x / max(geo.size.width, 1))
                task.setProgress((raw * 20).rounded() / 20)   // snap to 5%
            })
        }
        .frame(height: 12)
    }
}

struct Chip: View {
    let text: String
    let color: Color
    var icon: String?

    var body: some View {
        HStack(spacing: 3) {
            if let icon = icon { Image(systemName: icon) }
            if !text.isEmpty { Text(text) }
        }
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(color.opacity(0.16)))
    }
}

private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// A scroll view that is only as tall as its content, up to `maxHeight`.
struct FittedScroll<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder var content: Content
    @State private var height: CGFloat = 40

    var body: some View {
        ScrollView(showsIndicators: false) {
            content.background(GeometryReader { g in
                Color.clear.preference(key: HeightKey.self, value: g.size.height)
            })
        }
        .frame(height: min(height, maxHeight))
        .onPreferenceChange(HeightKey.self) { if $0 > 0 { height = $0 } }
    }
}

// MARK: - Notes editor

/// Multi-line notes box with a placeholder, used in the task list and the morning review.
struct NotesEditor: View {
    @Binding var text: String
    var height: CGFloat = 70

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 12, design: .rounded))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            if text.isEmpty {
                Text("What's done? What's pending?")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.25)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Task row

struct TaskRow: View {
    @Binding var task: TaskItem
    let onDelete: () -> Void
    @State private var hover = false
    @State private var showDate = false
    @State private var showPriority = false
    @State private var showNotes: Bool
    @State private var showSteps: Bool
    @State private var confirmDelete: Bool
    @State private var confirmDone: Bool
    @State private var newStep = ""

    /// The `…Open` / `confirming` arguments only exist so the snapshot tool can render those states.
    init(task: Binding<TaskItem>, notesOpen: Bool = false, stepsOpen: Bool = false,
         confirming: Bool = false, confirmingDone: Bool = false, onDelete: @escaping () -> Void) {
        _task = task
        self.onDelete = onDelete
        _showNotes = State(initialValue: notesOpen)
        _showSteps = State(initialValue: stepsOpen)
        _confirmDelete = State(initialValue: confirming)
        _confirmDone = State(initialValue: confirmingDone)
    }

    private var hasNotes: Bool { !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                // Finishing a task that is not at 100% asks first. Reopening a done one does not.
                if !task.done && task.progress < 1 {
                    withAnimation(.easeInOut(duration: 0.15)) { confirmDone = true; confirmDelete = false }
                } else {
                    task.toggleDone()
                }
            } label: {
                Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(task.done ? Palette.green : task.priority.color)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                TextField("Task", text: $task.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .strikethrough(task.done)
                    .foregroundColor(task.done ? .secondary : .primary)

                chips

                HStack(spacing: 6) {
                    ProgressBar(task: $task)
                    Text("\(Int((task.progress * 100).rounded()))%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }

                if showSteps { stepsEditor }

                if showNotes {
                    NotesEditor(text: $task.notes)
                        .padding(.top, 2)
                } else if hasNotes {
                    // Collapsed: a short preview so you can see status at a glance.
                    Text(task.notes)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { showNotes = true } }
                }

                if confirmDone && !task.done { doneBar }
                if confirmDelete { confirmBar }
            }

            Button { withAnimation(.easeInOut(duration: 0.15)) { confirmDelete = true; confirmDone = false } } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(hover ? 1 : 0.3)
            .help("Delete task")
        }
        .padding(.vertical, 7)
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .background(
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(confirmDelete ? Palette.red.opacity(0.10) : Color.white.opacity(hover ? 0.10 : 0.06))
                RoundedRectangle(cornerRadius: 2)
                    .fill(task.done ? Palette.green.opacity(0.6) : task.priority.color)
                    .frame(width: 3)
                    .padding(.vertical, 6)
                    .padding(.leading, 3)
            }
        )
        .opacity(task.done && !confirmDelete ? 0.6 : 1)
        .onHover { hover = $0 }
    }

    // Priority, due date, notes and checklist toggles.
    private var chips: some View {
        HStack(spacing: 6) {
            // Dropdown with the three priorities (a native Menu would override the chip colours).
            Button { showPriority.toggle() } label: {
                HStack(spacing: 2) {
                    Chip(text: task.priority.short, color: task.priority.color, icon: "flag.fill")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(task.priority.color.opacity(0.8))
                }
            }
            .buttonStyle(.plain)
            .help("Change priority")
            .popover(isPresented: $showPriority, arrowEdge: .bottom) { priorityPopover }

            Button { showDate.toggle() } label: {
                if let info = dueInfo(task) {
                    Chip(text: info.text, color: info.color, icon: "calendar")
                } else {
                    Chip(text: "Due date", color: .secondary, icon: "calendar")
                        .opacity(0.7)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDate, arrowEdge: .bottom) { datePopover }

            Button { withAnimation(.easeInOut(duration: 0.15)) { showNotes.toggle() } } label: {
                Chip(text: "Notes", color: hasNotes ? Palette.slate : .secondary,
                     icon: hasNotes ? "note.text" : "note.text.badge.plus")
                    .opacity(hasNotes || showNotes ? 1 : 0.7)
            }
            .buttonStyle(.plain)
            .help(showNotes ? "Hide notes" : "Add or view notes")

            Button { withAnimation(.easeInOut(duration: 0.15)) { showSteps.toggle() } } label: {
                if task.subtasks.isEmpty {
                    Chip(text: "", color: .secondary, icon: "checklist").opacity(showSteps ? 1 : 0.7)
                } else {
                    Chip(text: "\(task.doneSubtasks)/\(task.subtasks.count)",
                         color: task.doneSubtasks == task.subtasks.count ? Palette.green : Palette.slate,
                         icon: "checklist")
                }
            }
            .buttonStyle(.plain)
            .help(showSteps ? "Hide checklist" : "Add or view checklist")

            Spacer(minLength: 0)
        }
    }

    // Checklist: ticking items moves the progress bar.
    private var stepsEditor: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach($task.subtasks) { $sub in
                HStack(spacing: 6) {
                    Button { task.toggleSubtask(sub.id) } label: {
                        Image(systemName: sub.done ? "checkmark.square.fill" : "square")
                            .font(.system(size: 13))
                            .foregroundColor(sub.done ? Palette.green : .secondary)
                    }
                    .buttonStyle(.plain)
                    TextField("Step", text: $sub.title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .rounded))
                        .strikethrough(sub.done)
                        .foregroundColor(sub.done ? .secondary : .primary)
                    Button { task.removeSubtask(sub.id) } label: {
                        Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                    .frame(width: 13)
                TextField("Add a step and press Return", text: $newStep)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .rounded))
                    .onSubmit {
                        task.addSubtask(newStep)
                        newStep = ""
                    }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.22)))
        .padding(.top, 2)
    }

    // Asks before marking a task done when it is not at 100% yet.
    private var doneBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundColor(Palette.green)
            Text("Only \(Int((task.progress * 100).rounded()))% done. Finish it?")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button("Not yet") { withAnimation(.easeInOut(duration: 0.15)) { confirmDone = false } }
                .buttonStyle(.plain)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
            Button {
                confirmDone = false
                task.toggleDone()
            } label: {
                Text("Done")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(Palette.green))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.green.opacity(0.14)))
        .padding(.top, 2)
    }

    // Asks before deleting.
    private var confirmBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "trash.fill").font(.system(size: 11)).foregroundColor(Palette.red)
            Text("Delete this task?")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            Spacer(minLength: 4)
            Button("Cancel") { withAnimation(.easeInOut(duration: 0.15)) { confirmDelete = false } }
                .buttonStyle(.plain)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
            Button(action: onDelete) {
                Text("Delete")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(Palette.red))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.red.opacity(0.14)))
        .padding(.top, 2)
    }

    private var priorityPopover: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Priority.allCases, id: \.self) { p in
                Button {
                    task.priority = p
                    showPriority = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.fill").foregroundColor(p.color).frame(width: 14)
                        Text("\(p.short) · \(p.name)").font(.system(size: 12, design: .rounded))
                        Spacer(minLength: 12)
                        if p == task.priority {
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(p.color)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .frame(width: 150)
    }

    private var datePopover: some View {
        VStack(spacing: 8) {
            DatePicker("", selection: Binding(get: { task.due ?? Date() }, set: { task.due = $0 }),
                       displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
            HStack {
                Button("Today") { task.due = Date(); showDate = false }
                Button("Tomorrow") {
                    task.due = Calendar.current.date(byAdding: .day, value: 1, to: Date())
                    showDate = false
                }
                Spacer()
                Button("Clear") { task.due = nil; showDate = false }
            }
        }
        .padding(12)
        .frame(width: 240)
    }
}

struct SectionHeader: View {
    let priority: Priority
    let count: Int
    var chevron: String?

    var body: some View {
        HStack(spacing: 6) {
            if let chevron = chevron {
                Image(systemName: chevron)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 10)
            }
            Circle().fill(priority.color).frame(width: 7, height: 7)
            Text("\(priority.short) · \(priority.name)".uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(priority.color)
            Spacer()
        }
        .padding(.top, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Settings strip

struct SettingsView: View {
    @ObservedObject var settings: Settings
    var visitNow: (VisitKind) -> Void
    var testNudge: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "circle.lefthalf.filled").foregroundColor(.secondary)
                Slider(value: $settings.opacity, in: 0.2...1)
                Text("\(Int(settings.opacity * 100))%")
                    .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                    .frame(width: 34, alignment: .trailing)
            }
            HStack(spacing: 6) {
                Text("Tick lives in").font(.system(size: 11))
                Picker("", selection: $settings.corner) {
                    ForEach(Corner.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .frame(width: 120)
                Spacer()
            }
            HStack(spacing: 6) {
                Text("Morning visit from").font(.system(size: 11))
                Picker("", selection: $settings.visitHour) {
                    ForEach(Settings.windowStart..<Settings.windowEnd, id: \.self) { Text(hourLabel($0)).tag($0) }
                }
                .labelsHidden()
                .frame(width: 80)
                Spacer()
                Button("Visit now") { visitNow(.morning) }.font(.system(size: 11))
            }
            HStack(spacing: 6) {
                Toggle("Wrap-up from", isOn: $settings.wrapUp)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                Picker("", selection: $settings.wrapHour) {
                    ForEach(Settings.wrapStart...Settings.wrapLast, id: \.self) { Text(hourLabel($0)).tag($0) }
                }
                .labelsHidden()
                .frame(width: 80)
                .disabled(!settings.wrapUp)
                Spacer()
                Button("Wrap up now") { visitNow(.evening) }.font(.system(size: 11))
            }
            HStack(spacing: 6) {
                Toggle("Remind me about due and overdue tasks", isOn: $settings.nudges)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                Spacer()
                Button("Test") { testNudge() }.font(.system(size: 11))
            }
            Toggle("Tell me to go to bed after 10 PM", isOn: $settings.bedtime)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06)))
    }
}

// MARK: - Task list panel (opens when Tick is clicked)

struct ContentView: View {
    @ObservedObject var store: Store
    @ObservedObject var settings: Settings
    var visitNow: (VisitKind) -> Void
    var testNudge: () -> Void
    var onClose: () -> Void

    @State private var newTitle = ""
    @State private var newPriority = Priority.medium
    @State private var showSettings = false
    @State private var showArchive: Bool
    @AppStorage("lowExpanded") private var lowExpanded = false

    /// `archiveOpen` only exists so the snapshot tool can render the archive.
    init(store: Store, settings: Settings, visitNow: @escaping (VisitKind) -> Void,
         testNudge: @escaping () -> Void, archiveOpen: Bool = false, onClose: @escaping () -> Void) {
        self.store = store
        self.settings = settings
        self.visitNow = visitNow
        self.testNudge = testNudge
        self.onClose = onClose
        _showArchive = State(initialValue: archiveOpen)
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            if showSettings {
                SettingsView(settings: settings, visitNow: { kind in
                    visitNow(kind)
                    showSettings = false
                }, testNudge: {
                    testNudge()
                    showSettings = false
                })
            }
            if !showArchive { addBar }
            if showArchive { archiveList } else { list }
        }
        .padding(14)
        .background(
            ZStack {
                if snapshotMode {
                    Color(white: 0.13)
                } else {
                    VisualEffect(opacity: settings.opacity)
                    Color.black.opacity(0.30 * settings.opacity)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(showArchive ? "Archive" : "Tasks").font(.system(size: 16, weight: .bold, design: .rounded))
            let open = store.openCount
            Text("\(open) open · \(store.archived.count) archived")
                .font(.system(size: 11, design: .rounded)).foregroundColor(.secondary)
            Spacer()
            iconButton(showSettings ? "gearshape.fill" : "gearshape", help: "Settings") { showSettings.toggle() }
            iconButton(showArchive ? "archivebox.fill" : "archivebox",
                       help: showArchive ? "Back to open tasks" : "Show archived (finished) tasks") {
                withAnimation(.easeInOut(duration: 0.15)) { showArchive.toggle() }
            }
            iconButton("xmark.circle", help: "Close", action: onClose)
        }
    }

    private func iconButton(_ name: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: name) }
            .buttonStyle(.plain).foregroundColor(.secondary).help(help)
    }

    private var addBar: some View {
        HStack(spacing: 6) {
            TextField("Add a task and press Return", text: $newTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addTask)
            Picker("", selection: $newPriority) {
                ForEach(Priority.allCases, id: \.self) { Text($0.short).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 110)
        }
    }

    private var list: some View {
        let high = store.tasks(for: .high)
        let medium = store.tasks(for: .medium)
        let low = store.tasks(for: .low)
        return ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 6) {
                if high.isEmpty && medium.isEmpty && low.isEmpty {
                    Text("Nothing here. Add a task above.")
                        .font(.system(size: 12)).foregroundColor(.secondary).padding(.top, 20)
                }
                section(.high, high)
                section(.medium, medium)
                if !low.isEmpty {
                    Button { withAnimation(.easeInOut(duration: 0.2)) { lowExpanded.toggle() } } label: {
                        SectionHeader(priority: .low, count: low.filter { !$0.done }.count,
                                      chevron: lowExpanded ? "chevron.down" : "chevron.right")
                    }
                    .buttonStyle(.plain)
                    if lowExpanded { rows(low) }
                }
            }
        }
    }

    /// Finished tasks grouped by the day they were completed.
    private var archiveList: some View {
        let groups = archiveGroups()
        return ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 6) {
                if groups.isEmpty {
                    Text("Nothing archived yet. Finished tasks show up here.")
                        .font(.system(size: 12)).foregroundColor(.secondary).padding(.top, 20)
                }
                ForEach(groups, id: \.title) { g in
                    Text(g.title.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                    rows(g.tasks)
                }
            }
        }
    }

    private func archiveGroups() -> [(title: String, tasks: [TaskItem])] {
        let cal = Calendar.current
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        var result: [(title: String, tasks: [TaskItem])] = []
        for t in store.archived {
            let title: String
            if let c = t.completedAt {
                title = cal.isDateInToday(c) ? "Today" : cal.isDateInYesterday(c) ? "Yesterday" : f.string(from: c)
            } else {
                title = "Earlier"
            }
            if let i = result.firstIndex(where: { $0.title == title }) {
                result[i].tasks.append(t)
            } else {
                result.append((title, [t]))
            }
        }
        return result
    }

    @ViewBuilder private func section(_ p: Priority, _ items: [TaskItem]) -> some View {
        if !items.isEmpty {
            SectionHeader(priority: p, count: items.filter { !$0.done }.count)
            rows(items)
        }
    }

    private func rows(_ items: [TaskItem]) -> some View {
        ForEach(items) { t in
            TaskRow(task: store.binding(t.id)) { store.delete(t.id) }
        }
    }

    private func addTask() {
        store.add(newTitle, priority: newPriority)
        newTitle = ""
    }
}

// MARK: - Character ("Tick", a little checklist buddy)

struct Smile: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                       control: CGPoint(x: r.midX, y: r.minY + 2 * r.height))
        return p
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct CharacterView: View {
    var pose: Pose
    var facing: CGFloat            // -1 left, 0 front, 1 right
    var fixedTime: Double?         // used by snapshots

    private let bodyTop = Color(red: 0.40, green: 0.82, blue: 0.78)
    private let bodyBottom = Color(red: 0.30, green: 0.46, blue: 0.86)
    private let limb = Color(red: 0.24, green: 0.36, blue: 0.72)
    private let ink = Color(white: 0.12)

    var body: some View {
        if let t = fixedTime {
            figure(t: t)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
                figure(t: ctx.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func figure(t: Double) -> some View {
        let walking = pose == .walking
        let cheer = pose == .cheer
        let wave = pose == .wave
        let sleepy = pose == .sleepy
        let relaxed = pose == .relaxed
        let alert = pose == .alert
        let s = sin(t * 9)

        let bob: Double = walking ? -abs(sin(t * 9)) * 6
            : cheer ? -abs(sin(t * 7)) * 12
            : alert ? -abs(sin(t * 12)) * 5
            : sleepy ? sin(t * 1.1) * 2.5
            : relaxed ? sin(t * 2.2) * 2
            : sin(t * 2) * 1.5
        let legSwing = walking ? s * 30 : 0
        let leftArm: Double = walking ? -s * 32
            : cheer ? 150 + sin(t * 10) * 14
            : relaxed ? 14 + sin(t * 2.2) * 8
            : sleepy ? 4
            : alert ? 8
            : 8 + sin(t * 2) * 3
        let rightArm: Double = walking ? s * 32
            : cheer ? -150 - sin(t * 10) * 14
            : wave ? -140 + sin(t * 9) * 22
            : alert ? -145 + sin(t * 14) * 20
            : relaxed ? -14 - sin(t * 2.2 + 1) * 8
            : sleepy ? -4
            : -8 - sin(t * 2) * 3
        let wobble = sleepy ? 16.0 : sin(t * 3) * 7
        let sway = relaxed ? sin(t * 1.6) * 4 : 0
        let lightColor = alert ? Palette.red : Palette.amber
        let lightOpacity = alert ? 0.55 + 0.45 * abs(sin(t * 8)) : sleepy ? 0.35 : 1.0

        return ZStack {
            // ground shadow
            Ellipse().fill(Color.black.opacity(0.28))
                .frame(width: 70 + bob * 0.8, height: 10)
                .position(x: 60, y: 136)

            // legs
            ForEach([0, 1], id: \.self) { i in
                Capsule().fill(limb).frame(width: 13, height: 24)
                    .rotationEffect(.degrees(i == 0 ? legSwing : -legSwing), anchor: .top)
                    .position(x: i == 0 ? 46 : 74, y: 118 + bob * 0.3)
            }

            Group {
                // arms
                Capsule().fill(limb).frame(width: 11, height: 34)
                    .rotationEffect(.degrees(leftArm), anchor: .top)
                    .position(x: 22, y: 78)
                Capsule().fill(limb).frame(width: 11, height: 34)
                    .rotationEffect(.degrees(rightArm), anchor: .top)
                    .position(x: 98, y: 78)

                // antenna
                Capsule().fill(limb).frame(width: 4, height: 18)
                    .rotationEffect(.degrees(wobble), anchor: .bottom)
                    .position(x: 60, y: 34)
                Circle().fill(lightColor).frame(width: 12, height: 12)
                    .shadow(color: lightColor.opacity(0.8 * lightOpacity), radius: 6)
                    .opacity(lightOpacity)
                    .offset(x: CGFloat(wobble) * 0.45)
                    .position(x: 60, y: 22)

                // body
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(LinearGradient(colors: [bodyTop, bodyBottom], startPoint: .top, endPoint: .bottom))
                    .frame(width: 74, height: 82)
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5)
                    )
                    .position(x: 60, y: 82)

                eyes(t: t, sleepy: sleepy, relaxed: relaxed, alert: alert)
                Circle().fill(Color(red: 1, green: 0.55, blue: 0.6).opacity(0.55))
                    .frame(width: 9, height: 9).position(x: 37, y: 80)
                Circle().fill(Color(red: 1, green: 0.55, blue: 0.6).opacity(0.55))
                    .frame(width: 9, height: 9).position(x: 83, y: 80)
                mouth(t: t, happy: cheer || wave || relaxed, sleepy: sleepy, alert: alert)

                // clipboard badge on the belly
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 22, height: 26)
                    .overlay(
                        VStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { k in
                                HStack(spacing: 2) {
                                    Image(systemName: k == 2 ? "square" : "checkmark.square.fill")
                                        .font(.system(size: 5))
                                        .foregroundColor(k == 2 ? .gray : Palette.green)
                                    Capsule().fill(Color.gray.opacity(0.5)).frame(width: 8, height: 2)
                                }
                            }
                        }
                    )
                    .position(x: 60, y: 103)
            }
            .offset(y: bob)
            .rotationEffect(.degrees(walking ? Double(facing) * 4 : sway), anchor: .bottom)

            extras(t: t, sleepy: sleepy, relaxed: relaxed, alert: alert)
        }
        .frame(width: 120, height: 144)
    }

    private func eyes(t: Double, sleepy: Bool, relaxed: Bool, alert: Bool) -> some View {
        let blink = (t.truncatingRemainder(dividingBy: 4)) < 0.14
        let pupil: CGFloat = alert ? 7 : 9
        return ForEach([0, 1], id: \.self) { i in
            let x: CGFloat = i == 0 ? 47 : 73
            if sleepy {
                // closed eyes: a downward curve
                Smile().stroke(ink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 14, height: 4).position(x: x, y: 68)
            } else if relaxed {
                // happy eyes: an upward curve
                Smile().stroke(ink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 14, height: 5).rotationEffect(.degrees(180)).position(x: x, y: 70)
            } else {
                Circle().fill(Color.white).frame(width: 18, height: 18)
                    .overlay(
                        Circle().fill(ink).frame(width: pupil, height: pupil)
                            .offset(x: facing * 3, y: 1)
                    )
                    .scaleEffect(x: alert ? 1.15 : 1, y: blink ? 0.1 : (alert ? 1.15 : 1))
                    .position(x: x, y: 68)
            }
        }
    }

    @ViewBuilder
    private func mouth(t: Double, happy: Bool, sleepy: Bool, alert: Bool) -> some View {
        if happy {
            Smile().fill(ink).frame(width: 20, height: 9).position(x: 60, y: 82)
        } else if alert {
            Ellipse().fill(ink).frame(width: 8, height: 10).position(x: 60, y: 83)
        } else if sleepy {
            Ellipse().fill(ink).frame(width: 6, height: 4 + CGFloat(abs(sin(t * 1.1))) * 3)
                .position(x: 60, y: 82)
        } else {
            Smile().stroke(ink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 18, height: 6).position(x: 60, y: 81)
        }
    }

    // Floating "z"s, music notes and "!" around the character.
    @ViewBuilder
    private func extras(t: Double, sleepy: Bool, relaxed: Bool, alert: Bool) -> some View {
        if sleepy {
            ForEach(0..<3, id: \.self) { k in
                let p = (t * 0.45 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                Text("z")
                    .font(.system(size: 9 + p * 9, weight: .bold, design: .rounded))
                    .foregroundColor(Color.white.opacity(1 - p))
                    .position(x: 88 + p * 14, y: 34 - p * 26)
            }
        } else if relaxed {
            let p = (t * 0.5).truncatingRemainder(dividingBy: 1)
            Text("♪")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Palette.slate.opacity(1 - p))
                .position(x: 96 + sin(p * 6) * 5, y: 38 - p * 26)
        } else if alert {
            Text("!")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(Palette.red)
                .scaleEffect(1 + 0.15 * abs(sin(t * 8)))
                .position(x: 94, y: 22)
        }
    }
}

// MARK: - Speech bubble (visits)

struct SpeechBubble<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(white: 0.12))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                )
            Triangle()
                .fill(Color(white: 0.12))
                .frame(width: 22, height: 11)
                .overlay(Triangle().stroke(Color.white.opacity(0.14), lineWidth: 1))
                .padding(.top, -1)
        }
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
    }
}

// MARK: - Visit screens

func firstName() -> String {
    NSFullUserName().split(separator: " ").first.map(String.init) ?? ""
}

func greeting() -> String {
    let h = Calendar.current.component(.hour, from: Date())
    let base = h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening"
    let name = firstName()
    return name.isEmpty ? base : "\(base), \(name)"
}

/// One task at a time, with large progress buttons: this is what keeps the bubble uncluttered.
struct ReviewCard: View {
    @Binding var task: TaskItem
    private let options: [(String, Double)] = [("0%", 0), ("25%", 0.25), ("50%", 0.5), ("75%", 0.75)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Chip(text: task.priority.short, color: task.priority.color, icon: "flag.fill")
                if let info = dueInfo(task) { Chip(text: info.text, color: info.color, icon: "calendar") }
                Spacer()
            }
            Text(task.title.isEmpty ? "Untitled" : task.title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.0) { label, value in
                        pill(label, selected: !task.done && abs(task.progress - value) < 0.01,
                             color: task.priority.color) { task.setProgress(value) }
                    }
                }
                pill("Done", selected: task.done, color: Palette.green, icon: "checkmark") { task.setProgress(1) }
            }

            if !task.subtasks.isEmpty {
                FittedScroll(maxHeight: 92) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(task.subtasks) { s in
                            Button { task.toggleSubtask(s.id) } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: s.done ? "checkmark.square.fill" : "square")
                                        .foregroundColor(s.done ? Palette.green : .secondary)
                                    Text(s.title)
                                        .font(.system(size: 13, design: .rounded))
                                        .strikethrough(s.done)
                                        .foregroundColor(s.done ? .secondary : .primary)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            NotesEditor(text: $task.notes, height: task.subtasks.isEmpty ? 64 : 50)
        }
        .padding(16)
        .background(
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06))
                RoundedRectangle(cornerRadius: 2).fill(task.priority.color)
                    .frame(width: 3).padding(.vertical, 12).padding(.leading, 4)
            }
        )
    }

    private func pill(_ text: String, selected: Bool, color: Color, icon: String? = nil,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon { Image(systemName: icon).font(.system(size: 11, weight: .bold)) }
                Text(text)
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 9).fill(selected ? color : Color.white.opacity(0.08)))
            .foregroundColor(selected ? .black : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct VisitView: View {
    @ObservedObject var model: VisitModel
    @ObservedObject var store: Store

    @State private var newTitle = ""
    @State private var newPriority = Priority.high

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if model.showsBubble {
                SpeechBubble { bubbleContent }
                    .frame(width: 400)
                    .transition(.scale(scale: 0.9, anchor: .bottom).combined(with: .opacity))
            }
            CharacterView(pose: model.pose, facing: model.facing)
                .padding(.top, -2)
        }
        .frame(width: VisitMetrics.size.width, height: VisitMetrics.size.height, alignment: .bottom)
        .environment(\.colorScheme, .dark)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: model.stage)
    }

    @ViewBuilder private var bubbleContent: some View {
        switch model.stage {
        case .recap: recap
        case .review: review
        case .plan: plan
        case .summary: summary
        case .farewell: farewell
        default: EmptyView()
        }
    }

    private func nextButton(_ title: String) -> some View {
        Button { model.next() } label: {
            Label(title, systemImage: "arrow.right")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .buttonStyle(.borderedProminent).tint(Palette.slate)
        .keyboardShortcut(.defaultAction)
    }

    private var backButton: some View {
        Button { model.back() } label: { Image(systemName: "chevron.left") }
            .buttonStyle(.bordered)
    }

    private func doneRow(_ t: TaskItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(Palette.green)
            Text(t.title).font(.system(size: 14, design: .rounded)).lineLimit(1)
            Spacer(minLength: 4)
            Chip(text: t.priority.short, color: t.priority.color)
        }
        .padding(.vertical, 9).padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06)))
    }

    // Morning, step 0: what you finished last time.
    private var recap: some View {
        let done = model.recapIDs.compactMap { id in store.tasks.first(where: { $0.id == id }) }
        let cal = Calendar.current
        let when: String = {
            guard let d = model.recapDay else { return "last time" }
            if cal.isDateInYesterday(d) { return "yesterday" }
            let f = DateFormatter()
            f.dateFormat = "EEEE"
            return "on " + f.string(from: d)
        }()
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting() + "!")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text("You finished \(plural(done.count, "task")) \(when). Nice work!")
                    .font(.system(size: 12, design: .rounded)).foregroundColor(.secondary)
            }
            FittedScroll(maxHeight: 230) {
                VStack(spacing: 8) {
                    ForEach(done) { doneRow($0) }
                }
            }
            HStack {
                Button("Later") { model.onLater() }.buttonStyle(.plain).foregroundColor(.secondary)
                Spacer()
                nextButton(model.reviewIDs.isEmpty ? "Add today's tasks" : "Check open tasks")
            }
        }
    }

    // Step 1: reconfirm what was left open, one task per card.
    private var review: some View {
        let ids = model.reviewIDs
        let i = min(model.index, max(ids.count - 1, 0))
        let last = i >= ids.count - 1
        let evening = model.kind == .evening
        let title: String = {
            if evening { return i == 0 ? "Let's wrap up\(firstName().isEmpty ? "" : ", " + firstName())!" : "And this one?" }
            if i == 0 { return model.recapIDs.isEmpty ? greeting() + "!" : "Your open tasks" }
            return "How about this one?"
        }()
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(evening ? "Where did it end up today?" : "How far along is it?")
                        .font(.system(size: 12, design: .rounded)).foregroundColor(.secondary)
                }
                Spacer()
                Text("\(i + 1) of \(ids.count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
            }

            if ids.indices.contains(i) {
                ReviewCard(task: store.binding(ids[i]))
                    .id(ids[i])
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .opacity))
            }

            HStack(spacing: 5) {
                ForEach(ids.indices, id: \.self) { k in
                    Capsule().fill(k == i ? Palette.slate : Color.white.opacity(0.15))
                        .frame(width: k == i ? 16 : 6, height: 6)
                }
                Spacer()
            }

            HStack {
                Button("Later") { model.onLater() }.buttonStyle(.plain).foregroundColor(.secondary)
                Spacer()
                if model.canGoBack { backButton }
                nextButton(last ? (evening ? "Wrap up" : "Add today's tasks") : "Next")
            }
        }
        .animation(.easeInOut(duration: 0.22), value: model.index)
    }

    // Morning, step 2: add today's todos.
    private var plan: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("What's on today's list?")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text("Type a task and press Return. Add as many as you like.")
                    .font(.system(size: 12, design: .rounded)).foregroundColor(.secondary)
            }
            HStack(spacing: 8) {
                TextField("New task", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Picker("", selection: $newPriority) {
                    ForEach(Priority.allCases, id: \.self) { Text($0.short).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 120)
            }
            if !model.addedIDs.isEmpty {
                FittedScroll(maxHeight: 170) {
                    VStack(spacing: 8) {
                        ForEach(model.addedIDs, id: \.self) { id in
                            if let t = store.tasks.first(where: { $0.id == id }) {
                                HStack(spacing: 8) {
                                    Chip(text: t.priority.short, color: t.priority.color)
                                    Text(t.title).font(.system(size: 14, design: .rounded)).lineLimit(1)
                                    Spacer()
                                    Button {
                                        store.delete(id)
                                        model.addedIDs.removeAll { $0 == id }
                                    } label: {
                                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                                    }
                                    .buttonStyle(.plain).foregroundColor(.secondary)
                                }
                                .padding(.vertical, 9).padding(.horizontal, 12)
                                .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06)))
                            }
                        }
                    }
                }
            }
            HStack {
                if model.canGoBack { backButton }
                Spacer()
                Button { model.onFinish() } label: {
                    Label(model.addedIDs.isEmpty ? "Nothing new" : "All set", systemImage: "checkmark")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.borderedProminent).tint(Palette.green)
            }
        }
    }

    // Evening: what got done today, and what moves to tomorrow.
    private var summary: some View {
        let done = store.completed(on: Date())
        let open = store.openCount
        let urgent = store.urgentTasks.count
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Today's wrap-up")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text("\(plural(done.count, "task")) finished · \(open) still open")
                    .font(.system(size: 12, design: .rounded)).foregroundColor(.secondary)
            }
            if done.isEmpty {
                Text("Nothing ticked off today. That's okay, tomorrow is a fresh start.")
                    .font(.system(size: 13, design: .rounded)).foregroundColor(.secondary)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06)))
            } else {
                FittedScroll(maxHeight: 200) {
                    VStack(spacing: 8) {
                        ForEach(done) { doneRow($0) }
                    }
                }
            }
            if urgent > 0 {
                Toggle("Move \(plural(urgent, "due or overdue task")) to tomorrow", isOn: $model.carryOver)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12, design: .rounded))
            }
            HStack {
                if model.canGoBack { backButton }
                Spacer()
                Button { model.onFinish() } label: {
                    Label("Done for today", systemImage: "moon.stars.fill")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.borderedProminent).tint(Palette.green)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    @ViewBuilder private var farewell: some View {
        if model.kind == .morning {
            let open = store.openTasks
            let p1 = open.filter { $0.priority == .high }.count
            VStack(spacing: 4) {
                Text("Great, let's go!")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text(open.isEmpty ? "A clear list. Enjoy it!"
                     : "\(open.count) open" + (p1 > 0 ? " · \(p1) high priority" : ""))
                    .font(.system(size: 12, design: .rounded)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        } else {
            let done = store.completed(on: Date()).count
            VStack(spacing: 4) {
                Text("See you tomorrow!")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text(model.carried > 0 ? "Moved \(plural(model.carried, "task")) to tomorrow."
                     : "\(plural(done, "task")) finished today. Rest well!")
                    .font(.system(size: 12, design: .rounded)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func add() {
        if let id = store.add(newTitle, priority: newPriority) { model.addedIDs.append(id) }
        newTitle = ""
    }
}

// MARK: - Corner mascot (always on screen; click to open the list)

enum MascotMetrics {
    static let scale: CGFloat = 0.62
    static let size = CGSize(width: 90, height: 106)
    static let margin: CGFloat = 10
}

/// The click-through overlay that hosts Tick's speech bubble and the confetti.
enum OverlayMetrics {
    static let size = CGSize(width: 340, height: 270)
}

struct MascotView: View {
    @ObservedObject var store: Store
    @ObservedObject var ui: UIState
    var corner: Corner

    private var pose: Pose {
        if ui.celebrating { return .cheer }
        if ui.alerting { return .alert }
        if ui.mascotHover { return .wave }
        if ui.sleepy { return .sleepy }
        if store.openCount == 0 { return .relaxed }
        return .idle
    }

    var body: some View {
        let open = store.openCount
        ZStack(alignment: corner.isRight ? .topTrailing : .topLeading) {
            CharacterView(pose: pose, facing: corner.isRight ? -1 : 1)
                .scaleEffect(MascotMetrics.scale)
                .frame(width: MascotMetrics.size.width, height: MascotMetrics.size.height)
            if open > 0 {
                Text("\(open)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(Capsule().fill(store.hasUrgent ? Palette.red : Palette.slate))
                    .overlay(Capsule().strokeBorder(Color.black.opacity(0.25), lineWidth: 1))
                    .padding(corner.isRight ? .trailing : .leading, 6)
                    .padding(.top, 14)
            }
        }
        .frame(width: MascotMetrics.size.width, height: MascotMetrics.size.height)
        .contentShape(Rectangle())
        .environment(\.colorScheme, .dark)
    }
}

/// The small speech bubble next to Tick: hover message, due-date nudges, celebrations.
struct MascotBubble: View {
    let message: BubbleMessage
    let corner: Corner

    var body: some View {
        VStack(alignment: corner.isRight ? .trailing : .leading, spacing: 0) {
            if corner.isTop { tail(up: true) }
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Circle().fill(message.accent).frame(width: 7, height: 7)
                    Text(message.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let sub = message.subtitle {
                    Text(sub)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let warning = message.warning {
                    Chip(text: warning, color: Palette.red, icon: "exclamationmark.circle.fill")
                        .padding(.top, 2)
                }
            }
            .padding(12)
            .frame(width: 250, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(white: 0.12))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(message.accent.opacity(0.45), lineWidth: 1))
            )
            if !corner.isTop { tail(up: false) }
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .environment(\.colorScheme, .dark)
    }

    /// Points at the middle of the mascot.
    private func tail(up: Bool) -> some View {
        Triangle()
            .fill(Color(white: 0.12))
            .frame(width: 20, height: 10)
            .rotationEffect(.degrees(up ? 180 : 0))
            .padding(corner.isRight ? .trailing : .leading, MascotMetrics.size.width / 2 - 10)
            .padding(up ? .bottom : .top, -1)
    }
}

/// A short burst of confetti from Tick when a task is finished.
struct ConfettiView: View {
    var start: Date?
    var corner: Corner
    var fixedTime: Double?          // used by snapshots

    private let colors: [Color] = [Palette.red, Palette.amber, Palette.slate, Palette.green, Palette.yellow, .white]

    var body: some View {
        if let f = fixedTime {
            burst(t: f)
        } else if let s = start {
            TimelineView(.animation) { ctx in burst(t: ctx.date.timeIntervalSince(s)) }
        }
    }

    @ViewBuilder
    private func burst(t: Double) -> some View {
        if t >= 0 && t < 2.7 {
            ZStack {
                ForEach(0..<44, id: \.self) { i in particle(i, t) }
            }
            .frame(width: OverlayMetrics.size.width, height: OverlayMetrics.size.height)
        }
    }

    private func particle(_ i: Int, _ t: Double) -> some View {
        func r(_ salt: Double) -> Double {
            let v = sin(Double(i) * 12.9898 + salt * 78.233) * 43758.5453
            return v - v.rounded(.down)
        }
        let inward: Double = corner.isRight ? -1 : 1
        let up: Double = corner.isTop ? 1 : -1
        let vx = inward * (r(1) * 210 - 25)
        let vy = up * (90 + r(2) * 240)
        let px = corner.isRight ? OverlayMetrics.size.width - MascotMetrics.size.width / 2
                                : MascotMetrics.size.width / 2
        let py = corner.isTop ? MascotMetrics.size.height / 2
                              : OverlayMetrics.size.height - MascotMetrics.size.height / 2
        let x = px + vx * t
        let y = py + vy * t + 0.5 * 420 * t * t
        let fade = max(0, min(1, (2.6 - t) / 0.8))
        return Rectangle()
            .fill(colors[i % colors.count])
            .frame(width: 6, height: 10)
            .rotationEffect(.degrees(r(3) * 360 + t * (r(4) * 700 - 350)))
            .opacity(fade)
            .position(x: x, y: y)
    }
}

struct MascotOverlayView: View {
    @ObservedObject var store: Store
    @ObservedObject var ui: UIState
    var corner: Corner
    var forcedMessage: BubbleMessage?     // used by snapshots
    var confettiTime: Double?             // used by snapshots

    /// Hover wins over a pending nudge or celebration; nothing shows while the list is open.
    private var message: BubbleMessage? {
        if let m = forcedMessage { return m }
        if ui.listOpen { return nil }
        if ui.mascotHover { return store.hoverMessage() }
        return ui.bubble
    }

    private var alignment: Alignment {
        switch corner {
        case .bottomRight: return .bottomTrailing
        case .bottomLeft: return .bottomLeading
        case .topRight: return .topTrailing
        case .topLeft: return .topLeading
        }
    }

    var body: some View {
        ZStack(alignment: alignment) {
            Color.clear
            ConfettiView(start: ui.confettiStart, corner: corner, fixedTime: confettiTime)
            if let m = message {
                MascotBubble(message: m, corner: corner)
                    .padding(corner.isTop ? .top : .bottom, MascotMetrics.size.height + 4)
                    .transition(.scale(scale: 0.9, anchor: corner.isRight ? .bottomTrailing : .bottomLeading)
                        .combined(with: .opacity))
            }
        }
        .frame(width: OverlayMetrics.size.width, height: OverlayMetrics.size.height)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: message?.id)
    }
}
