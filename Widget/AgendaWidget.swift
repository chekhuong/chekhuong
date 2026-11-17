import WidgetKit
import SwiftUI

/// Widget "Lịch trình": việc + sự kiện lịch theo thứ tự thời gian.
struct AgendaWidget: Widget {
    let kind = "AgendaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoProvider()) { entry in
            AgendaWidgetView(entry: entry)
                .widgetURL(URL(string: "todolock://calendar"))
        }
        .configurationDisplayName("Lịch trình")
        .description("Sự kiện lịch và việc cần làm tiếp theo trong ngày.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemMedium, .systemLarge])
    }
}

struct AgendaWidgetView: View {
    let entry: TodoEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Group {
                if let next = entry.nextTimed, let t = next.time {
                    Label("\(VN.time(t)) \(next.title)", systemImage: next.isEvent ? "calendar" : "checklist")
                } else {
                    Label("\(VN.weekdayShort(entry.date)) \(Calendar.current.component(.day, from: entry.date)) · \(entry.agenda.count) mục", systemImage: "calendar")
                }
            }
            .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            AgendaRectangular(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        case .systemLarge:
            AgendaLarge(entry: entry)
                .containerBackground(.background, for: .widget)
        default:
            AgendaMedium(entry: entry)
                .containerBackground(.background, for: .widget)
        }
    }
}

private struct AgendaRectangular: View {
    let entry: TodoEntry

    var body: some View {
        let items = entry.agenda
        VStack(alignment: .leading, spacing: 1) {
            if let next = entry.nextTimed ?? items.first {
                HStack(spacing: 4) {
                    Image(systemName: next.isEvent ? "calendar" : "checklist")
                    Text(next.time.map { VN.time($0) } ?? "Hôm nay")
                }
                .font(.system(size: 12, weight: .bold))
                .widgetAccentable()
                Text(next.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                let rest = items.filter { $0.id != next.id }
                if let second = rest.first {
                    Text((second.time.map { VN.time($0) + " " } ?? "") + second.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Label("Lịch trống", systemImage: "calendar")
                    .font(.system(size: 13, weight: .bold))
                    .widgetAccentable()
                Text("Không có sự kiện hay việc nào").font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AgendaRow: View {
    let item: AgendaItem

    var body: some View {
        HStack(spacing: 8) {
            Text(item.time.map { VN.time($0) } ?? (item.isEvent ? "Cả ngày" : "—"))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            RoundedRectangle(cornerRadius: 1.5).fill(item.color).frame(width: 3, height: 18)
            if case .task(let occ) = item.kind {
                Button(intent: ToggleTaskIntent(taskID: occ.task.id.uuidString, dayKey: occ.dayKey)) {
                    Image(systemName: "circle").font(.caption)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "calendar").font(.caption).foregroundStyle(.secondary)
            }
            Text(item.title).font(.subheadline).lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

private struct AgendaMedium: View {
    let entry: TodoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(entry: entry)
            let items = entry.agenda
            if items.isEmpty {
                Spacer()
                Text("Không còn gì trong hôm nay 🌿").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(items.prefix(4)) { AgendaRow(item: $0) }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct AgendaLarge: View {
    let entry: TodoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(entry: entry)
            MiniMonth(date: entry.date)
            Divider()
            let items = entry.agenda
            if items.isEmpty {
                Text("Không còn gì trong hôm nay 🌿").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(items.prefix(6)) { AgendaRow(item: $0) }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct MiniMonth: View {
    let date: Date

    var body: some View {
        let cal = VN.calendar
        let interval = cal.dateInterval(of: .month, for: date)
        let first = interval?.start ?? date
        let count = cal.range(of: .day, in: .month, for: date)?.count ?? 30
        let offset = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        let today = cal.component(.day, from: date)
        let cells: [Int?] = Array(repeating: nil, count: offset) + (1...count).map { Optional($0) }
        let headers = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]

        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                ForEach(headers, id: \.self) { h in
                    Text(h).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<((cells.count + 6) / 7), id: \.self) { row in
                GridRow {
                    ForEach(0..<7, id: \.self) { col in
                        let i = row * 7 + col
                        if i < cells.count, let d = cells[i] {
                            Text("\(d)")
                                .font(.system(size: 11, weight: d == today ? .bold : .regular))
                                .foregroundStyle(d == today ? Color.white : Color.primary)
                                .frame(width: 20, height: 18)
                                .background {
                                    if d == today { Circle().fill(Color.accentColor) }
                                }
                                .frame(maxWidth: .infinity)
                        } else {
                            Color.clear.frame(height: 18).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }
}
