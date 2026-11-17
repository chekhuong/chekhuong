import WidgetKit
import SwiftUI
import AppIntents

struct TodayTasksWidget: Widget {
    let kind = "TodayTasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoProvider()) { entry in
            TodayTasksWidgetView(entry: entry)
                .widgetURL(URL(string: "todolock://today"))
        }
        .configurationDisplayName("Việc hôm nay")
        .description("Danh sách việc cần làm hôm nay. Bấm ✓ để đánh dấu xong.")
        .supportedFamilies([
            .accessoryRectangular, .accessoryCircular, .accessoryInline,
            .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge,
        ])
    }
}

struct TodayTasksWidgetView: View {
    let entry: TodoEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularProgressView(entry: entry)
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        case .accessoryInline:
            InlineView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            RectangularTasksView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        case .systemSmall:
            TaskListWidget(entry: entry, maxItems: 4, compact: true)
                .containerBackground(.background, for: .widget)
        case .systemMedium:
            MediumTasksView(entry: entry)
                .containerBackground(.background, for: .widget)
        default:
            TaskListWidget(entry: entry, maxItems: family == .systemExtraLarge ? 12 : 10, compact: false)
                .containerBackground(.background, for: .widget)
        }
    }
}

// MARK: - Màn hình khóa

struct CircularProgressView: View {
    let entry: TodoEntry

    var body: some View {
        Gauge(value: Double(entry.doneToday), in: 0...Double(max(entry.totalToday, 1))) {
            Image(systemName: "checklist")
        } currentValueLabel: {
            if entry.totalToday > 0 && entry.pending.isEmpty {
                Image(systemName: "checkmark")
            } else {
                Text("\(entry.pending.count)")
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }
}

struct InlineView: View {
    let entry: TodoEntry

    var body: some View {
        if let first = entry.pending.first {
            let timeText = first.time.map { VN.time($0) + " " } ?? ""
            Label("\(entry.pending.count) việc · \(timeText)\(first.task.title)", systemImage: "checklist")
        } else if entry.totalToday > 0 {
            Label("Xong hết việc hôm nay 🎉", systemImage: "checkmark.circle")
        } else {
            Label("Không có việc nào hôm nay", systemImage: "checklist")
        }
    }
}

struct RectangularTasksView: View {
    let entry: TodoEntry

    var body: some View {
        let pending = entry.pending
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                Text(pending.isEmpty ? "Hôm nay" : "\(pending.count) việc cần làm")
                Spacer(minLength: 0)
                if entry.totalToday > 0 {
                    Text("\(entry.doneToday)/\(entry.totalToday)")
                }
            }
            .font(.system(size: 12, weight: .bold))
            .widgetAccentable()

            if pending.isEmpty {
                Text(entry.totalToday > 0 ? "Xong hết rồi! 🎉" : "Thảnh thơi ☕️")
                    .font(.system(size: 14, weight: .medium))
            } else {
                ForEach(pending.prefix(2)) { occ in
                    HStack(spacing: 4) {
                        Image(systemName: occ.isOverdue ? "exclamationmark.circle" : "circle")
                            .font(.system(size: 10))
                        Text(occ.task.title)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if let t = occ.time {
                            Text(VN.time(t)).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                }
                if pending.count > 2 {
                    Text("+\(pending.count - 2) việc nữa")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Màn hình chính (tương tác)

struct WidgetTaskRow: View {
    let occ: TaskOccurrence
    var compact: Bool

    var body: some View {
        HStack(spacing: 6) {
            Button(intent: ToggleTaskIntent(taskID: occ.task.id.uuidString, dayKey: occ.dayKey)) {
                Image(systemName: occ.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(compact ? .body : .title3)
                    .foregroundStyle(occ.isCompleted ? occ.task.color.color : Color.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 0) {
                Text(occ.task.title)
                    .font(compact ? .caption : .subheadline)
                    .strikethrough(occ.isCompleted)
                    .foregroundStyle(occ.isCompleted ? Color.secondary : Color.primary)
                    .lineLimit(1)
                if !compact, let t = occ.time {
                    Text(VN.time(t)).font(.caption2).foregroundStyle(.secondary)
                } else if occ.isOverdue {
                    Text("Quá hạn").font(.caption2).foregroundStyle(.red)
                }
            }
            Spacer(minLength: 0)
            if compact, let t = occ.time {
                Text(VN.time(t)).font(.caption2).foregroundStyle(.secondary)
            }
            RoundedRectangle(cornerRadius: 1.5)
                .fill(occ.task.color.color)
                .frame(width: 3, height: compact ? 14 : 22)
        }
    }
}

struct WidgetHeader: View {
    let entry: TodoEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(VN.weekdayName(entry.date))
                .font(.headline)
                .foregroundStyle(.tint)
            Text("\(Calendar.current.component(.day, from: entry.date))/\(Calendar.current.component(.month, from: entry.date))")
                .font(.headline)
            Spacer()
            if entry.totalToday > 0 {
                Text("\(entry.doneToday)/\(entry.totalToday)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct TaskListWidget: View {
    let entry: TodoEntry
    let maxItems: Int
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 8) {
            if compact {
                HStack {
                    Text("Hôm nay").font(.caption.bold()).foregroundStyle(.tint)
                    Spacer()
                    Text("\(entry.pending.count)").font(.title3.bold())
                }
            } else {
                WidgetHeader(entry: entry)
                if entry.totalToday > 0 {
                    ProgressView(value: Double(entry.doneToday), total: Double(entry.totalToday))
                }
                if !entry.events.isEmpty {
                    ForEach(entry.events.prefix(3)) { ev in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 1.5).fill(ev.color).frame(width: 3, height: 16)
                            Text(ev.title).font(.caption).lineLimit(1)
                            Spacer()
                            Text(ev.timeText).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                }
            }

            if entry.tasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "sparkles").font(.title2).foregroundStyle(.tint)
                        Text("Không có việc nào").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.tasks.prefix(maxItems)) { WidgetTaskRow(occ: $0, compact: compact) }
                if entry.tasks.count > maxItems {
                    Text("+\(entry.tasks.count - maxItems) việc nữa")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct MediumTasksView: View {
    let entry: TodoEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(VN.weekdayName(entry.date))
                    .font(.caption.bold())
                    .foregroundStyle(.tint)
                Text("\(Calendar.current.component(.day, from: entry.date))")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("Tháng \(Calendar.current.component(.month, from: entry.date))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if entry.totalToday > 0 {
                    Gauge(value: Double(entry.doneToday), in: 0...Double(entry.totalToday)) {
                        EmptyView()
                    } currentValueLabel: {
                        Text("\(entry.doneToday)/\(entry.totalToday)")
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(.accentColor)
                    .scaleEffect(0.8)
                }
            }
            .frame(width: 80, alignment: .leading)

            TaskListWidget(entry: entry, maxItems: 4, compact: true)
        }
    }
}
