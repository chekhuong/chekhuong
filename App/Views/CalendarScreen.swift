import SwiftUI

struct CalendarScreen: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var month = Date()
    @State private var selected = Calendar.current.startOfDay(for: Date())

    var body: some View {
        Group {
            if sizeClass == .regular {
                HStack(spacing: 0) {
                    MonthGrid(month: $month, selected: $selected)
                        .padding()
                        .frame(maxWidth: 480)
                    Divider()
                    selectedList
                }
            } else {
                VStack(spacing: 0) {
                    MonthGrid(month: $month, selected: $selected)
                        .padding(.horizontal)
                    Divider()
                    selectedList
                }
            }
        }
        .navigationTitle("Lịch")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { router.newTask(on: selected) } label: { Image(systemName: "plus") }
            }
        }
    }

    private var selectedList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(VN.relativeDay(selected) + (Calendar.current.isDateInToday(selected) ? " · " + VN.dayTitle(selected) : ""))
                .font(.title3.bold())
                .padding([.horizontal, .top])
            DayTasksList(day: selected)
        }
    }
}

struct MonthGrid: View {
    @Binding var month: Date
    @Binding var selected: Date

    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var events: CalendarEventsManager
    @AppStorage(SettingsKeys.showEventsInApp, store: SharedConfig.defaults) private var showEvents = true

    private let cal = VN.calendar
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdayHeaders = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(VN.monthTitle(month)).font(.title2.bold())
                Spacer()
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                Button("Hôm nay") {
                    month = Date()
                    selected = cal.startOfDay(for: Date())
                }
                .buttonStyle(.bordered)
                Button { shift(1) } label: { Image(systemName: "chevron.right") }
            }
            .font(.title3)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdayHeaders, id: \.self) { h in
                    Text(h)
                        .font(.caption.bold())
                        .foregroundStyle(h == "CN" ? Color.red : Color.secondary)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        DayCell(day: day,
                                isSelected: cal.isDate(day, inSameDayAs: selected),
                                colors: dotColors(for: day))
                            .onTapGesture { selected = day }
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 30).onEnded { v in
                    if v.translation.width < -50 { shift(1) }
                    if v.translation.width > 50 { shift(-1) }
                }
            )
            Spacer(minLength: 0)
        }
    }

    private func shift(_ n: Int) {
        withAnimation(.snappy) {
            month = cal.date(byAdding: .month, value: n, to: month) ?? month
        }
    }

    private var cells: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: month),
              let count = cal.range(of: .day, in: .month, for: month)?.count else { return [] }
        let first = interval.start
        let offset = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: offset)
        for i in 0..<count {
            result.append(cal.date(byAdding: .day, value: i, to: first))
        }
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    private func dotColors(for day: Date) -> [Color] {
        var colors = store.occurrences(on: day).prefix(3).map { $0.isCompleted ? Color.gray.opacity(0.4) : $0.task.color.color }
        if showEvents && colors.count < 4 && !events.events(on: day).isEmpty {
            colors.append(.secondary)
        }
        return Array(colors.prefix(4))
    }
}

private struct DayCell: View {
    let day: Date
    let isSelected: Bool
    let colors: [Color]

    var body: some View {
        let isToday = Calendar.current.isDateInToday(day)
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.body.weight(isToday ? .bold : .regular))
                .frame(width: 34, height: 34)
                .background {
                    Circle().fill(isSelected ? Color.accentColor : (isToday ? Color.accentColor.opacity(0.15) : .clear))
                }
                .foregroundStyle(isSelected ? .white : (isToday ? Color.accentColor : .primary))
            HStack(spacing: 3) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, c in
                    Circle().fill(c).frame(width: 5, height: 5)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
    }
}
