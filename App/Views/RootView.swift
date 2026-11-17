import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var router: AppRouter
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $router.selection) {
                Section {
                    NavigationLink(value: SidebarItem.today) {
                        Label("Hôm nay", systemImage: "sun.max.fill")
                    }
                    .badge(store.pendingCount(on: Date()) + store.overdue().count)

                    NavigationLink(value: SidebarItem.upcoming) {
                        Label("Sắp tới", systemImage: "calendar.day.timeline.left")
                    }
                    NavigationLink(value: SidebarItem.calendar) {
                        Label("Lịch", systemImage: "calendar")
                    }
                    NavigationLink(value: SidebarItem.all) {
                        Label("Tất cả công việc", systemImage: "tray.full.fill")
                    }
                    .badge(store.tasks.count)
                    NavigationLink(value: SidebarItem.completed) {
                        Label("Đã hoàn thành", systemImage: "checkmark.circle.fill")
                    }
                }
                Section {
                    NavigationLink(value: SidebarItem.settings) {
                        Label("Cài đặt", systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationTitle("TodoLock")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { router.newTask() } label: {
                        Label("Việc mới", systemImage: "plus.circle.fill")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
        } detail: {
            NavigationStack {
                detail
            }
        }
        .sheet(item: $router.editor) { ctx in
            TaskEditorView(context: ctx)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch router.selection ?? .today {
        case .today:
            TodayView()
        case .upcoming:
            UpcomingView()
        case .calendar:
            CalendarScreen()
        case .all:
            AllTasksView()
        case .completed:
            CompletedView()
        case .settings:
            SettingsView()
        }
    }
}
