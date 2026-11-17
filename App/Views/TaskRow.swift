import SwiftUI

struct TaskRow: View {
    let occurrence: TaskOccurrence
    var showDate: Bool = false

    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var router: AppRouter

    private var task: TaskItem { occurrence.task }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                store.toggle(occurrence)
            } label: {
                Image(systemName: occurrence.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(occurrence.isCompleted ? task.color.color : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(occurrence.isCompleted ? "Bỏ đánh dấu" : "Đánh dấu xong")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if task.priority != .none {
                        Text(task.priority.marks)
                            .font(.body.bold())
                            .foregroundStyle(.red)
                    }
                    Text(task.title)
                        .font(.body)
                        .strikethrough(occurrence.isCompleted)
                        .foregroundStyle(occurrence.isCompleted ? Color.secondary : Color.primary)
                }
                metaLine
                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 2)
                .fill(task.color.color)
                .frame(width: 4)
                .padding(.vertical, 2)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { router.edit(store.task(id: task.id) ?? task) }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { store.delete(id: task.id) } label: {
                Label("Xoá", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button { store.toggle(occurrence) } label: {
                Label(occurrence.isCompleted ? "Chưa xong" : "Xong", systemImage: "checkmark")
            }
            .tint(.green)
        }
        .contextMenu {
            Button { router.edit(store.task(id: task.id) ?? task) } label: { Label("Sửa", systemImage: "pencil") }
            if !task.isRepeating {
                Button {
                    store.move(task, to: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
                } label: { Label("Dời sang ngày mai", systemImage: "arrow.turn.up.right") }
                Button { store.move(task, to: Date()) } label: { Label("Dời về hôm nay", systemImage: "sun.max") }
            }
            Divider()
            Button(role: .destructive) { store.delete(id: task.id) } label: { Label("Xoá", systemImage: "trash") }
        }
    }

    @ViewBuilder
    private var metaLine: some View {
        let parts = metaParts
        if !parts.isEmpty {
            HStack(spacing: 8) {
                ForEach(parts) { p in
                    Label(p.text, systemImage: p.icon)
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.caption)
            .foregroundStyle(occurrence.isOverdue ? Color.red : Color.secondary)
        }
    }

    private struct MetaPart: Identifiable {
        let text: String
        let icon: String
        var id: String { icon }
    }

    private var metaParts: [MetaPart] {
        var parts: [MetaPart] = []
        if showDate || occurrence.isOverdue {
            parts.append(MetaPart(text: VN.relativeDay(occurrence.day), icon: "calendar"))
        }
        if let t = occurrence.time { parts.append(MetaPart(text: VN.time(t), icon: "clock")) }
        if task.isRepeating { parts.append(MetaPart(text: task.repeatRule.title, icon: "repeat")) }
        if task.remind { parts.append(MetaPart(text: "Nhắc", icon: "bell.fill")) }
        return parts
    }
}

struct EventRow: View {
    let event: EventSnapshot

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.color)
                .frame(width: 4, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.body)
                Text(event.isAllDay ? "Cả ngày" : "\(VN.time(event.start)) – \(VN.time(event.end))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "calendar").foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct QuickAddField: View {
    let day: Date
    @EnvironmentObject private var store: TaskStore
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
            TextField("Thêm việc nhanh… (vd: 9:30 Họp nhóm)", text: $text)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(add)
            if !text.isEmpty {
                Button("Thêm", action: add).buttonStyle(.borderedProminent)
            }
        }
    }

    private func add() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.add(title: trimmed, on: day)
        text = ""
        focused = true
    }
}
