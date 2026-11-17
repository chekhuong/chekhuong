import WidgetKit
import SwiftUI

/// Một mục hiển thị (việc cần làm hoặc sự kiện lịch).
struct AgendaItem: Identifiable, Hashable {
    enum Kind: Hashable { case task(TaskOccurrence), event(EventSnapshot) }
    let kind: Kind

    var id: String {
        switch kind {
        case .task(let o): return "t-" + o.id
        case .event(let e): return "e-" + e.id
        }
    }
    var title: String {
        switch kind {
        case .task(let o): return o.task.title
        case .event(let e): return e.title
        }
    }
    var time: Date? {
        switch kind {
        case .task(let o): return o.time
        case .event(let e): return e.isAllDay ? nil : e.start
        }
    }
    var endTime: Date? {
        if case .event(let e) = kind, !e.isAllDay { return e.end }
        return time
    }
    var color: Color {
        switch kind {
        case .task(let o): return o.task.color.color
        case .event(let e): return e.color
        }
    }
    var isDone: Bool {
        if case .task(let o) = kind { return o.isCompleted }
        return false
    }
    var isEvent: Bool {
        if case .event = kind { return true }
        return false
    }
}

struct TodoEntry: TimelineEntry {
    let date: Date
    let tasks: [TaskOccurrence]      // gồm cả việc quá hạn ở đầu
    let events: [EventSnapshot]
    let totalToday: Int
    let doneToday: Int

    var pending: [TaskOccurrence] { tasks.filter { !$0.isCompleted } }

    /// Việc + sự kiện, sắp theo giờ; sự kiện đã qua bị ẩn.
    var agenda: [AgendaItem] {
        let evs = events
            .filter { $0.isAllDay || $0.end > date }
            .map { AgendaItem(kind: .event($0)) }
        let ts = tasks.filter { !$0.isCompleted }.map { AgendaItem(kind: .task($0)) }
        return (evs + ts).sorted { a, b in
            switch (a.time, b.time) {
            case let (x?, y?): return x < y
            case (nil, _?): return true   // cả ngày / không giờ lên đầu
            case (_?, nil): return false
            default: return a.isEvent && !b.isEvent
            }
        }
    }

    /// Mục kế tiếp có giờ (để hiện "Tiếp theo").
    var nextTimed: AgendaItem? {
        agenda.first { ($0.time ?? .distantPast) >= date.addingTimeInterval(-15 * 60) && $0.time != nil }
    }

    static var sample: TodoEntry {
        let today = Calendar.current.startOfDay(for: Date())
        func t(_ title: String, _ h: Int?, _ c: TaskColor, done: Bool = false) -> TaskOccurrence {
            var item = TaskItem(title: title, date: today)
            if let h { item.date = Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: today) ?? today; item.hasTime = true }
            item.color = c
            if done { item.completedDays = [DayKey.string(today)] }
            return TaskOccurrence(task: item, day: today)
        }
        let tasks = [t("Họp nhóm", 9, .blue), t("Đi chợ", nil, .green), t("Tập thể dục", 18, .orange), t("Đọc sách", nil, .purple, done: true)]
        return TodoEntry(date: Date(), tasks: tasks, events: [], totalToday: 4, doneToday: 1)
    }
}

struct TodoProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (TodoEntry) -> Void) {
        if context.isPreview && TaskRepository.load().isEmpty {
            completion(.sample)
        } else {
            completion(Self.makeEntry(for: Date()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoEntry>) -> Void) {
        let cal = Calendar.current
        let now = Date()
        let midnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now) ?? now)

        var dates: [Date] = [now]
        let first = Self.makeEntry(for: now)
        // Cập nhật lại sau mỗi mốc giờ trong ngày để mục "tiếp theo" luôn đúng.
        for item in first.agenda {
            if let end = item.endTime, end > now, end < midnight { dates.append(end.addingTimeInterval(60)) }
        }
        dates.append(midnight)

        let entries = Array(Set(dates)).sorted().prefix(30).map { Self.makeEntry(for: $0) }
        let refresh = min(midnight, now.addingTimeInterval(60 * 60))
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    static func makeEntry(for date: Date) -> TodoEntry {
        let defaults = SharedConfig.defaults
        let showEvents = defaults.bool(forKey: SettingsKeys.showEventsInWidget, default: true)
        let hideDone = defaults.bool(forKey: SettingsKeys.hideCompletedInWidget, default: false)

        let all = TaskRepository.load().filter(\.showOnLockScreen)
        let today = TaskRepository.occurrences(on: date, in: all)
        let overdue = TaskRepository.overdue(before: date, in: all)
        var list = overdue + today
        if hideDone { list = list.filter { !$0.isCompleted } }

        return TodoEntry(
            date: date,
            tasks: list,
            events: showEvents ? EventCache.events(on: date) : [],
            totalToday: today.count,
            doneToday: today.filter(\.isCompleted).count
        )
    }
}
