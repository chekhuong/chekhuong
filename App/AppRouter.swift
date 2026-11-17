import SwiftUI

enum SidebarItem: Hashable {
    case today, upcoming, calendar, all, completed, settings
}

struct EditorContext: Identifiable {
    let id = UUID()
    var task: TaskItem
    var isNew: Bool
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selection: SidebarItem? = .today
    @Published var editor: EditorContext?

    func newTask(on day: Date = Date()) {
        let cal = Calendar.current
        let now = Date()
        // Mặc định: giờ tròn tiếp theo
        let nextHour = (cal.component(.hour, from: now) + 1) % 24
        let date = cal.date(bySettingHour: nextHour, minute: 0, second: 0, of: day) ?? day
        editor = EditorContext(task: TaskItem(title: "", date: date), isNew: true)
    }

    func edit(_ task: TaskItem) {
        editor = EditorContext(task: task, isNew: false)
    }

    /// todolock://today · todolock://new · todolock://calendar · todolock://task/<uuid>
    func handle(url: URL, store: TaskStore) {
        guard url.scheme == "todolock" else { return }
        switch url.host {
        case "new":
            selection = .today
            newTask()
        case "calendar":
            selection = .calendar
        case "upcoming":
            selection = .upcoming
        case "task":
            selection = .today
            if let idString = url.pathComponents.dropFirst().first,
               let id = UUID(uuidString: idString),
               let task = store.task(id: id) {
                edit(task)
            }
        default:
            selection = .today
        }
    }
}
