import SwiftUI

/// Danh sách công việc + sự kiện của một ngày.
struct DayTasksList: View {
    let day: Date
    var showOverdue: Bool = false

    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var events: CalendarEventsManager
    @AppStorage(SettingsKeys.showEventsInApp, store: SharedConfig.defaults) private var showEvents = true

    var body: some View {
        let items = store.occurrences(on: day)
        let pending = items.filter { !$0.isCompleted }
        let done = items.filter { $0.isCompleted }
        let overdue = showOverdue ? store.overdue() : []
        let dayEvents = showEvents ? events.events(on: day) : []

        List {
            Section {
                QuickAddField(day: day)
            } header: {
                ProgressHeader(done: done.count, total: items.count)
            }

            if !overdue.isEmpty {
                Section("Quá hạn") {
                    ForEach(overdue) { TaskRow(occurrence: $0) }
                }
            }

            if !dayEvents.isEmpty {
                Section("Sự kiện lịch") {
                    ForEach(dayEvents) { EventRow(event: $0) }
                }
            }

            Section("Cần làm") {
                if pending.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: items.isEmpty ? "sparkles" : "checkmark.seal.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.tint)
                            Text(items.isEmpty ? "Chưa có việc nào" : "Xong hết rồi! 🎉")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                } else {
                    ForEach(pending) { TaskRow(occurrence: $0) }
                }
            }

            if !done.isEmpty {
                Section("Đã xong (\(done.count))") {
                    ForEach(done) { TaskRow(occurrence: $0) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: items.map(\.id))
    }
}

struct ProgressHeader: View {
    let done: Int
    let total: Int

    var body: some View {
        if total > 0 {
            HStack(spacing: 10) {
                ProgressView(value: Double(done), total: Double(total))
                    .tint(done == total ? .green : .accentColor)
                Text("\(done)/\(total)")
                    .font(.caption.monospacedDigit())
            }
            .textCase(nil)
            .padding(.bottom, 4)
        }
    }
}

struct TodayView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var now = Date()

    var body: some View {
        DayTasksList(day: now, showOverdue: true)
            .navigationTitle("Hôm nay")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(VN.dayTitle(now)).font(.headline)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { router.newTask() } label: { Image(systemName: "plus") }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                now = Date()
            }
    }
}
