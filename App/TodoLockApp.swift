import SwiftUI
import UserNotifications

@main
struct TodoLockApp: App {
    @StateObject private var store = TaskStore()
    @StateObject private var events = CalendarEventsManager()
    @StateObject private var router = AppRouter()
    @AppStorage(SettingsKeys.accent, store: SharedConfig.defaults) private var accentRaw = TaskColor.blue.rawValue
    @Environment(\.scenePhase) private var scenePhase

    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(events)
                .environmentObject(router)
                .tint(TaskColor.from(accentRaw).color)
                .onOpenURL { router.handle(url: $0, store: store) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.reload()
                events.refresh()
            }
        }
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
