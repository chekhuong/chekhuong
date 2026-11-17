import Foundation

/// Cấu hình dùng chung giữa app và widget (qua App Group).
enum SharedConfig {
    static let appGroupID: String =
        (Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String) ?? "group.com.chekhuong.todolock"

    /// Thư mục dùng chung. Nếu App Group chưa được cấp quyền thì quay về thư mục Documents
    /// (app vẫn chạy được, nhưng widget sẽ không thấy dữ liệu).
    static let containerURL: URL = {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return url
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()

    static var hasAppGroup: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
    }

    static let tasksURL = containerURL.appendingPathComponent("tasks.json")
    static let eventsCacheURL = containerURL.appendingPathComponent("events-cache.json")

    static let defaults: UserDefaults = UserDefaults(suiteName: appGroupID) ?? .standard
}

enum SettingsKeys {
    static let accent = "accentColor"
    static let showEventsInWidget = "showEventsInWidget"
    static let hideCompletedInWidget = "hideCompletedInWidget"
    static let showEventsInApp = "showEventsInApp"
    static let defaultReminderMinutes = "defaultReminderMinutes" // phút tính từ 0:00
}

extension UserDefaults {
    func bool(forKey key: String, default value: Bool) -> Bool {
        object(forKey: key) == nil ? value : bool(forKey: key)
    }
}
