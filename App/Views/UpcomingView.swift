import SwiftUI

struct UpcomingView: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var events: CalendarEventsManager
    @EnvironmentObject private var router: AppRouter
    @AppStorage(SettingsKeys.showEventsInApp, store: SharedConfig.defaults) private var showEvents = true
    @State private var range = 7

    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<range).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }

    var body: some View {
        List {
            ForEach(days, id: \.self) { day in
                let items = store.occurrences(on: day)
                let evs = showEvents ? events.events(on: day) : []
                Section {
                    if items.isEmpty && evs.isEmpty {
                        Text("Trống").foregroundStyle(.tertiary)
                    }
                    ForEach(evs) { EventRow(event: $0) }
                    ForEach(items) { TaskRow(occurrence: $0) }
                } header: {
                    HStack {
                        Text(VN.relativeDay(day))
                        if Calendar.current.isDateInToday(day) || Calendar.current.isDateInTomorrow(day) {
                            Text(VN.dayTitle(day)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { router.newTask(on: day) } label: { Image(systemName: "plus") }
                    }
                    .textCase(nil)
                    .font(.headline)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Sắp tới")
        .toolbar {
            Picker("Khoảng", selection: $range) {
                Text("7 ngày").tag(7)
                Text("14 ngày").tag(14)
                Text("30 ngày").tag(30)
            }
            .pickerStyle(.segmented)
        }
    }
}
