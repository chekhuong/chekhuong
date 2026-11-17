import SwiftUI

struct AllTasksView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "Tất cả", oneOff = "Một lần", repeating = "Lặp lại"
        var id: String { rawValue }
    }

    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var router: AppRouter
    @State private var search = ""
    @State private var filter: Filter = .all

    private var filtered: [TaskItem] {
        store.tasks
            .filter {
                switch filter {
                case .all: return true
                case .oneOff: return !$0.isRepeating
                case .repeating: return $0.isRepeating
                }
            }
            .filter {
                search.isEmpty
                    || $0.title.localizedCaseInsensitiveContains(search)
                    || $0.notes.localizedCaseInsensitiveContains(search)
            }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            ForEach(filtered) { task in
                let cal = Calendar.current
                let day = task.isRepeating ? nextOccurrence(of: task) : cal.startOfDay(for: task.date)
                TaskRow(occurrence: TaskOccurrence(task: task, day: day), showDate: true)
            }
        }
        .overlay {
            if filtered.isEmpty {
                let title: String = search.isEmpty ? "Chưa có công việc" : "Không tìm thấy"
                ContentUnavailableView(title, systemImage: search.isEmpty ? "tray" : "magnifyingglass")
            }
        }
        .searchable(text: $search, prompt: "Tìm công việc")
        .navigationTitle("Tất cả công việc")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Lọc", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }
            ToolbarItem(placement: .primaryAction) {
                Button { router.newTask() } label: { Image(systemName: "plus") }
            }
        }
    }

    private func nextOccurrence(of task: TaskItem) -> Date {
        let cal = Calendar.current
        var d = max(cal.startOfDay(for: Date()), cal.startOfDay(for: task.date))
        for _ in 0..<370 {
            if task.occurs(on: d) { return d }
            d = cal.date(byAdding: .day, value: 1, to: d) ?? d
        }
        return cal.startOfDay(for: task.date)
    }
}

struct CompletedView: View {
    @EnvironmentObject private var store: TaskStore
    @State private var confirmClear = false

    private var completedOneOffs: [TaskItem] {
        store.tasks
            .filter { !$0.isRepeating && $0.isCompleted(on: $0.date) }
            .sorted { $0.date > $1.date }
    }

    private var repeating: [TaskItem] {
        store.tasks.filter(\.isRepeating)
    }

    var body: some View {
        List {
            if !repeating.isEmpty {
                Section("Việc lặp lại – số lần đã hoàn thành") {
                    ForEach(repeating) { task in
                        let count = task.completedDays.count
                        HStack {
                            Circle().fill(task.color.color).frame(width: 10, height: 10)
                            Text(task.title)
                            Spacer()
                            Text("\(count) lần").foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
            }
            Section("Việc một lần đã xong") {
                if completedOneOffs.isEmpty {
                    Text("Chưa có").foregroundStyle(.tertiary)
                }
                ForEach(completedOneOffs) { task in
                    TaskRow(occurrence: TaskOccurrence(task: task, day: Calendar.current.startOfDay(for: task.date)),
                            showDate: true)
                }
            }
        }
        .navigationTitle("Đã hoàn thành")
        .toolbar {
            if !completedOneOffs.isEmpty {
                Button("Dọn dẹp", role: .destructive) { confirmClear = true }
            }
        }
        .confirmationDialog("Xoá tất cả việc một lần đã xong?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Xoá \(completedOneOffs.count) việc", role: .destructive) { store.clearCompletedOneOffs() }
        }
    }
}
