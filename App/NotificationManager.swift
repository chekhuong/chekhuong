import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Xoá hết và lên lịch lại toàn bộ nhắc nhở (iOS giới hạn 64 thông báo chờ).
    func reschedule(_ tasks: [TaskItem]) {
        center.removeAllPendingNotificationRequests()
        let stored = SharedConfig.defaults.object(forKey: SettingsKeys.defaultReminderMinutes) as? Int
        let defaultMinutes = stored ?? 9 * 60
        var count = 0
        for task in tasks where task.remind {
            for request in requests(for: task, defaultMinutes: defaultMinutes) {
                guard count < 60 else { return }
                center.add(request)
                count += 1
            }
        }
    }

    private func requests(for task: TaskItem, defaultMinutes: Int) -> [UNNotificationRequest] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if task.isRepeating, let end = task.repeatEnd, cal.startOfDay(for: end) < today { return [] }

        var hm = DateComponents()
        if task.hasTime {
            hm = cal.dateComponents([.hour, .minute], from: task.date)
        } else {
            hm.hour = defaultMinutes / 60
            hm.minute = defaultMinutes % 60
        }

        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = task.notes.isEmpty ? (task.hasTime ? "Đến giờ rồi ⏰" : "Việc cần làm hôm nay") : task.notes
        content.sound = .default
        content.userInfo = ["taskID": task.id.uuidString]

        func make(_ comps: DateComponents, repeats: Bool, suffix: String = "") -> UNNotificationRequest {
            UNNotificationRequest(identifier: task.id.uuidString + suffix,
                                  content: content,
                                  trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: repeats))
        }

        switch task.repeatRule {
        case .none:
            guard !task.isCompleted(on: task.date) else { return [] }
            var comps = cal.dateComponents([.year, .month, .day], from: task.date)
            comps.hour = hm.hour
            comps.minute = hm.minute
            guard let fire = cal.date(from: comps), fire > Date() else { return [] }
            return [make(comps, repeats: false)]
        case .daily:
            return [make(hm, repeats: true)]
        case .weekdays:
            return (2...6).map { wd in
                var c = hm
                c.weekday = wd
                return make(c, repeats: true, suffix: "-wd\(wd)")
            }
        case .weekly:
            var c = hm
            c.weekday = cal.component(.weekday, from: task.date)
            return [make(c, repeats: true)]
        case .monthly:
            var c = hm
            c.day = cal.component(.day, from: task.date)
            return [make(c, repeats: true)]
        case .yearly:
            var c = hm
            c.month = cal.component(.month, from: task.date)
            c.day = cal.component(.day, from: task.date)
            return [make(c, repeats: true)]
        }
    }
}
