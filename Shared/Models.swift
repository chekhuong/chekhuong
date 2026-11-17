import Foundation

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekdays, weekly, monthly, yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Không lặp"
        case .daily: return "Hằng ngày"
        case .weekdays: return "Ngày thường (T2–T6)"
        case .weekly: return "Hằng tuần"
        case .monthly: return "Hằng tháng"
        case .yearly: return "Hằng năm"
        }
    }
}

enum TaskPriority: Int, Codable, CaseIterable, Identifiable {
    case none = 0, low, medium, high

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: return "Không"
        case .low: return "Thấp"
        case .medium: return "Vừa"
        case .high: return "Cao"
        }
    }

    var marks: String { String(repeating: "!", count: rawValue) }
}

enum TaskColor: String, Codable, CaseIterable, Identifiable {
    case blue, red, orange, yellow, green, teal, indigo, purple, pink, gray
    var id: String { rawValue }
}

struct TaskItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var notes: String = ""
    /// Ngày (và giờ nếu `hasTime`) của lần đầu tiên.
    var date: Date
    var hasTime: Bool = false
    var repeatRule: RepeatRule = .none
    var repeatEnd: Date? = nil
    var priority: TaskPriority = .none
    var color: TaskColor = .blue
    var remind: Bool = false
    var showOnLockScreen: Bool = true
    /// Các ngày đã hoàn thành, dạng "yyyy-MM-dd".
    var completedDays: Set<String> = []
    var createdAt: Date = Date()

    init(title: String, date: Date) {
        self.title = title
        self.date = date
    }

    // Giải mã "khoan dung" để file sao lưu cũ/thiếu trường vẫn đọc được.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        hasTime = try c.decodeIfPresent(Bool.self, forKey: .hasTime) ?? false
        repeatRule = try c.decodeIfPresent(RepeatRule.self, forKey: .repeatRule) ?? .none
        repeatEnd = try c.decodeIfPresent(Date.self, forKey: .repeatEnd)
        priority = try c.decodeIfPresent(TaskPriority.self, forKey: .priority) ?? .none
        color = try c.decodeIfPresent(TaskColor.self, forKey: .color) ?? .blue
        remind = try c.decodeIfPresent(Bool.self, forKey: .remind) ?? false
        showOnLockScreen = try c.decodeIfPresent(Bool.self, forKey: .showOnLockScreen) ?? true
        completedDays = try c.decodeIfPresent(Set<String>.self, forKey: .completedDays) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    var isRepeating: Bool { repeatRule != .none }

    func occurs(on day: Date, calendar cal: Calendar = .current) -> Bool {
        let d = cal.startOfDay(for: day)
        let base = cal.startOfDay(for: date)
        if d < base { return false }
        if isRepeating, let end = repeatEnd, d > cal.startOfDay(for: end) { return false }

        switch repeatRule {
        case .none:
            return d == base
        case .daily:
            return true
        case .weekdays:
            return !cal.isDateInWeekend(d)
        case .weekly:
            return cal.component(.weekday, from: d) == cal.component(.weekday, from: base)
        case .monthly:
            let baseDay = cal.component(.day, from: base)
            let days = cal.range(of: .day, in: .month, for: d)?.count ?? 31
            return cal.component(.day, from: d) == min(baseDay, days)
        case .yearly:
            guard cal.component(.month, from: d) == cal.component(.month, from: base) else { return false }
            let baseDay = cal.component(.day, from: base)
            let days = cal.range(of: .day, in: .month, for: d)?.count ?? 31
            return cal.component(.day, from: d) == min(baseDay, days)
        }
    }

    func isCompleted(on day: Date) -> Bool {
        completedDays.contains(DayKey.string(day))
    }

    mutating func toggle(dayKey: String) {
        if completedDays.contains(dayKey) {
            completedDays.remove(dayKey)
        } else {
            completedDays.insert(dayKey)
        }
    }

    /// Giờ của lần lặp vào ngày `day` (nếu có giờ).
    func time(on day: Date, calendar cal: Calendar = .current) -> Date? {
        guard hasTime else { return nil }
        let hm = cal.dateComponents([.hour, .minute], from: date)
        return cal.date(bySettingHour: hm.hour ?? 0, minute: hm.minute ?? 0, second: 0, of: day)
    }
}

/// Một lần xuất hiện của công việc vào một ngày cụ thể.
struct TaskOccurrence: Identifiable, Hashable {
    let task: TaskItem
    let day: Date
    var isOverdue: Bool = false

    var id: String { task.id.uuidString + "|" + dayKey }
    var dayKey: String { DayKey.string(day) }
    var isCompleted: Bool { task.isCompleted(on: day) }
    var time: Date? { task.time(on: day) }
}

enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func string(_ date: Date) -> String { formatter.string(from: date) }
    static func date(_ key: String) -> Date? { formatter.date(from: key) }
}
