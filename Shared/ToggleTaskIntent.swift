import AppIntents
import UserNotifications
import WidgetKit

/// Đánh dấu xong / chưa xong ngay trên widget (iOS/iPadOS 17+).
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Đánh dấu công việc"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Mã công việc")
    var taskID: String

    @Parameter(title: "Ngày")
    var dayKey: String

    init() {}

    init(taskID: String, dayKey: String) {
        self.taskID = taskID
        self.dayKey = dayKey
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: taskID),
           let task = TaskRepository.toggle(taskID: id, dayKey: dayKey),
           !task.isRepeating, task.completedDays.contains(dayKey) {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        }
        return .result()
    }
}
