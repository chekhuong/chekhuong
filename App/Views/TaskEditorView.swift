import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TaskStore

    @State private var task: TaskItem
    @State private var hasEnd: Bool
    @State private var confirmDelete = false
    @FocusState private var titleFocused: Bool
    private let isNew: Bool

    init(context: EditorContext) {
        _task = State(initialValue: context.task)
        _hasEnd = State(initialValue: context.task.repeatEnd != nil)
        isNew = context.isNew
    }

    private var canSave: Bool {
        !task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tên công việc", text: $task.title, axis: .vertical)
                        .font(.title3)
                        .focused($titleFocused)
                    TextField("Ghi chú", text: $task.notes, axis: .vertical)
                        .lineLimit(2...8)
                }

                Section("Thời gian") {
                    DatePicker("Ngày", selection: $task.date, displayedComponents: .date)
                    Toggle("Có giờ cụ thể", isOn: $task.hasTime.animation())
                    if task.hasTime {
                        DatePicker("Giờ", selection: $task.date, displayedComponents: .hourAndMinute)
                    }
                    Picker("Lặp lại", selection: $task.repeatRule.animation()) {
                        ForEach(RepeatRule.allCases) { Text($0.title).tag($0) }
                    }
                    if task.isRepeating {
                        Toggle("Có ngày kết thúc", isOn: $hasEnd.animation())
                        if hasEnd {
                            DatePicker("Kết thúc", selection: endBinding, in: task.date..., displayedComponents: .date)
                        }
                    }
                }

                Section {
                    Toggle(isOn: $task.remind) {
                        Label("Nhắc tôi", systemImage: "bell.badge")
                    }
                } footer: {
                    if task.remind && !task.hasTime {
                        Text("Việc không có giờ sẽ được nhắc vào giờ mặc định trong Cài đặt.")
                    }
                }

                Section("Phân loại") {
                    Picker("Độ ưu tiên", selection: $task.priority) {
                        ForEach(TaskPriority.allCases) { p in
                            Text(p == .none ? p.title : "\(p.marks) \(p.title)").tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                    ColorPalette(selection: $task.color)
                }

                Section {
                    Toggle(isOn: $task.showOnLockScreen) {
                        Label("Hiện trên màn hình khóa & widget", systemImage: "lock.iphone")
                    }
                }

                if !isNew {
                    Section {
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("Xoá công việc", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Việc mới" : "Sửa công việc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Thêm" : "Lưu", action: save)
                        .disabled(!canSave)
                        .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .confirmationDialog("Xoá công việc này?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Xoá", role: .destructive) {
                    store.delete(id: task.id)
                    dismiss()
                }
            }
            .onAppear { if isNew { titleFocused = true } }
        }
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { task.repeatEnd ?? task.date },
            set: { task.repeatEnd = $0 }
        )
    }

    private func save() {
        var t = task
        t.title = t.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isRepeating || !hasEnd { t.repeatEnd = nil }
        if !t.hasTime {
            t.date = Calendar.current.startOfDay(for: t.date)
        } else {
            let cal = Calendar.current
            let hm = cal.dateComponents([.hour, .minute], from: t.date)
            t.date = cal.date(bySettingHour: hm.hour ?? 0, minute: hm.minute ?? 0, second: 0, of: t.date) ?? t.date
        }
        store.upsert(t)
        if t.remind {
            Task { _ = await NotificationManager.shared.requestAuthorization() }
        }
        dismiss()
    }
}

struct ColorPalette: View {
    @Binding var selection: TaskColor

    var body: some View {
        HStack(spacing: 10) {
            ForEach(TaskColor.allCases) { c in
                Circle()
                    .fill(c.color)
                    .frame(width: 28, height: 28)
                    .overlay {
                        if c == selection {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .onTapGesture { selection = c }
                    .accessibilityLabel(c.rawValue)
            }
        }
        .padding(.vertical, 4)
    }
}
