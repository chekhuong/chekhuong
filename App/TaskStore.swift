import Foundation
import SwiftUI

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []

    init() {
        tasks = TaskRepository.load()
        if tasks.isEmpty && !SharedConfig.defaults.bool(forKey: "didSeed") {
            seed()
        }
        NotificationManager.shared.reschedule(tasks)
    }

    func reload() {
        let fresh = TaskRepository.load()
        if fresh != tasks { tasks = fresh }
    }

    func task(id: UUID) -> TaskItem? { tasks.first { $0.id == id } }

    func upsert(_ task: TaskItem) {
        if let i = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[i] = task
        } else {
            tasks.append(task)
        }
        persist()
    }

    func add(title: String, on day: Date) {
        let parsed = QuickAddParser.parse(title, day: day)
        guard !parsed.title.isEmpty else { return }
        var t = TaskItem(title: parsed.title, date: parsed.date)
        t.hasTime = parsed.hasTime
        upsert(t)
    }

    func delete(id: UUID) {
        tasks.removeAll { $0.id == id }
        persist()
    }

    func toggle(_ occ: TaskOccurrence) {
        guard let i = tasks.firstIndex(where: { $0.id == occ.task.id }) else { return }
        withAnimation(.snappy) {
            tasks[i].toggle(dayKey: occ.dayKey)
        }
        persist()
    }

    /// Dời việc một lần sang ngày khác (giữ nguyên giờ).
    func move(_ task: TaskItem, to day: Date) {
        guard var t = self.task(id: task.id) else { return }
        let cal = Calendar.current
        let hm = cal.dateComponents([.hour, .minute], from: t.date)
        t.date = cal.date(bySettingHour: hm.hour ?? 0, minute: hm.minute ?? 0, second: 0, of: day) ?? day
        t.completedDays = []
        upsert(t)
    }

    func clearCompletedOneOffs() {
        tasks.removeAll { !$0.isRepeating && $0.isCompleted(on: $0.date) }
        persist()
    }

    func replaceAll(_ newTasks: [TaskItem]) {
        tasks = newTasks
        persist()
    }

    // MARK: - Truy vấn

    func occurrences(on day: Date) -> [TaskOccurrence] {
        TaskRepository.occurrences(on: day, in: tasks)
    }

    func overdue() -> [TaskOccurrence] {
        TaskRepository.overdue(before: Date(), in: tasks)
    }

    func pendingCount(on day: Date) -> Int {
        occurrences(on: day).filter { !$0.isCompleted }.count
    }

    // MARK: -

    private func persist() {
        TaskRepository.save(tasks)
        NotificationManager.shared.reschedule(tasks)
    }

    private func seed() {
        SharedConfig.defaults.set(true, forKey: "didSeed")
        let cal = Calendar.current
        let today = Date()
        var a = TaskItem(title: "Chào mừng đến TodoLock 👋", date: today)
        a.notes = "Chạm vào vòng tròn để đánh dấu xong. Vuốt sang trái để xoá."
        a.color = .indigo
        var b = TaskItem(title: "Thêm widget vào màn hình khóa iPad", date: today)
        b.notes = "Giữ màn hình khóa → Tùy chỉnh → Màn hình khóa → chạm vùng widget → chọn TodoLock."
        b.priority = .high
        b.color = .orange
        var c = TaskItem(title: "Uống nước", date: cal.date(bySettingHour: 9, minute: 0, second: 0, of: today) ?? today)
        c.hasTime = true
        c.repeatRule = .daily
        c.color = .teal
        tasks = [a, b, c]
        TaskRepository.save(tasks)
    }
}

/// Phân tích nhanh: "9:30 Họp nhóm", "Họp nhóm 14h", "Gọi mẹ 20h15".
enum QuickAddParser {
    struct Result { var title: String; var date: Date; var hasTime: Bool }

    static func parse(_ raw: String, day: Date) -> Result {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let cal = Calendar.current
        let base = cal.startOfDay(for: day)
        let pattern = #"(?<![\d])([01]?\d|2[0-3])(?:[:h](\d{2})|h)(?![\d])"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let hRange = Range(m.range(at: 1), in: text),
              let whole = Range(m.range, in: text),
              let hour = Int(text[hRange]) else {
            return Result(title: text, date: base, hasTime: false)
        }
        var minute = 0
        if let mRange = Range(m.range(at: 2), in: text), let mm = Int(text[mRange]), mm < 60 { minute = mm }
        var title = text
        title.removeSubrange(whole)
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { return Result(title: text, date: base, hasTime: false) }
        let date = cal.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        return Result(title: title, date: date, hasTime: true)
    }
}
