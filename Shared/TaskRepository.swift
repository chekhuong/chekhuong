import Foundation
import WidgetKit

/// Đọc / ghi danh sách công việc vào file JSON trong App Group.
enum TaskRepository {
    static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    static func load() -> [TaskItem] {
        guard let data = try? Data(contentsOf: SharedConfig.tasksURL) else { return [] }
        return (try? decode(data)) ?? []
    }

    static func decode(_ data: Data) throws -> [TaskItem] {
        try makeDecoder().decode([TaskItem].self, from: data)
    }

    static func encode(_ tasks: [TaskItem]) throws -> Data {
        try makeEncoder().encode(tasks)
    }

    static func save(_ tasks: [TaskItem]) {
        do {
            let data = try encode(tasks)
            try data.write(to: SharedConfig.tasksURL, options: .atomic)
        } catch {
            print("TodoLock: không lưu được dữ liệu: \(error)")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Bật/tắt hoàn thành (dùng cho widget tương tác).
    @discardableResult
    static func toggle(taskID: UUID, dayKey: String) -> TaskItem? {
        var tasks = load()
        guard let i = tasks.firstIndex(where: { $0.id == taskID }) else { return nil }
        tasks[i].toggle(dayKey: dayKey)
        save(tasks)
        return tasks[i]
    }

    // MARK: - Truy vấn

    static func occurrences(on day: Date, in tasks: [TaskItem]) -> [TaskOccurrence] {
        let cal = Calendar.current
        let d = cal.startOfDay(for: day)
        return sort(tasks.filter { $0.occurs(on: d) }.map { TaskOccurrence(task: $0, day: d) })
    }

    /// Việc một lần, chưa xong, có ngày trước `day`.
    static func overdue(before day: Date, in tasks: [TaskItem]) -> [TaskOccurrence] {
        let cal = Calendar.current
        let d = cal.startOfDay(for: day)
        return tasks
            .filter { !$0.isRepeating && cal.startOfDay(for: $0.date) < d && !$0.isCompleted(on: $0.date) }
            .map { TaskOccurrence(task: $0, day: cal.startOfDay(for: $0.date), isOverdue: true) }
            .sorted { $0.task.date < $1.task.date }
    }

    static func sort(_ items: [TaskOccurrence]) -> [TaskOccurrence] {
        items.sorted { a, b in
            if a.isCompleted != b.isCompleted { return !a.isCompleted }
            switch (a.time, b.time) {
            case let (ta?, tb?) where ta != tb: return ta < tb
            case (.some, .none): return true
            case (.none, .some): return false
            default: break
            }
            if a.task.priority != b.task.priority { return a.task.priority.rawValue > b.task.priority.rawValue }
            return a.task.createdAt < b.task.createdAt
        }
    }
}
