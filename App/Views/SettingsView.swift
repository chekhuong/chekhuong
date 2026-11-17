import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import WidgetKit

struct SettingsView: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var events: CalendarEventsManager

    @AppStorage(SettingsKeys.accent, store: SharedConfig.defaults) private var accentRaw = TaskColor.blue.rawValue
    @AppStorage(SettingsKeys.showEventsInApp, store: SharedConfig.defaults) private var showEventsInApp = true
    @AppStorage(SettingsKeys.showEventsInWidget, store: SharedConfig.defaults) private var showEventsInWidget = true
    @AppStorage(SettingsKeys.hideCompletedInWidget, store: SharedConfig.defaults) private var hideCompletedInWidget = false
    @AppStorage(SettingsKeys.defaultReminderMinutes, store: SharedConfig.defaults) private var reminderMinutes = 9 * 60

    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var exporting = false
    @State private var importing = false
    @State private var exportDoc = BackupDocument(data: Data())
    @State private var pendingImport: [TaskItem]?
    @State private var message: String?

    var body: some View {
        Form {
            Section("Giao diện") {
                ColorPalette(selection: Binding(
                    get: { TaskColor.from(accentRaw) },
                    set: { accentRaw = $0.rawValue }
                ))
            }

            Section {
                Toggle("Hiện sự kiện lịch trên widget", isOn: $showEventsInWidget)
                Toggle("Ẩn việc đã xong trên widget", isOn: $hideCompletedInWidget)
                DisclosureGroup("Cách thêm widget vào màn hình khóa") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Khóa iPad, rồi bật màn hình (đừng mở khóa hẳn).")
                        Text("2. Chạm và giữ màn hình khóa → **Tùy chỉnh** → **Màn hình khóa**.")
                        Text("3. Chạm vào vùng widget (cột bên trái khi xoay ngang, hoặc dưới đồng hồ).")
                        Text("4. Chọn **TodoLock** → kéo widget *Việc hôm nay* hoặc *Lịch trình* vào.")
                        Text("5. Bấm **Xong**. Widget trên màn hình chính có thể bấm ✓ trực tiếp.")
                    }
                    .font(.callout)
                    .padding(.vertical, 4)
                }
                if !SharedConfig.hasAppGroup {
                    Label("App Group chưa hoạt động – widget sẽ không thấy dữ liệu. Kiểm tra lại cấu hình ký ứng dụng.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }
            } header: {
                Text("Màn hình khóa & Widget")
            }

            Section("Lịch") {
                Toggle("Hiện sự kiện lịch trong app", isOn: $showEventsInApp)
                HStack {
                    Text("Truy cập Lịch")
                    Spacer()
                    Text(calendarStatusText).foregroundStyle(.secondary)
                }
                if !events.isAuthorized {
                    Button("Cho phép truy cập Lịch") {
                        Task { await events.requestAccess() }
                    }
                    if events.status == .denied || events.status == .restricted {
                        Button("Mở Cài đặt hệ thống") { openSystemSettings() }
                    }
                }
            }

            Section {
                HStack {
                    Text("Thông báo")
                    Spacer()
                    Text(notifStatusText).foregroundStyle(.secondary)
                }
                if notifStatus == .notDetermined {
                    Button("Cho phép thông báo") {
                        Task {
                            _ = await NotificationManager.shared.requestAuthorization()
                            await refreshNotifStatus()
                            NotificationManager.shared.reschedule(store.tasks)
                        }
                    }
                } else if notifStatus == .denied {
                    Button("Mở Cài đặt hệ thống") { openSystemSettings() }
                }
                DatePicker("Giờ nhắc mặc định", selection: reminderTime, displayedComponents: .hourAndMinute)
            } header: {
                Text("Nhắc nhở")
            } footer: {
                Text("Dùng cho các việc bật “Nhắc tôi” nhưng không đặt giờ.")
            }

            Section("Dữ liệu") {
                Button {
                    if let data = try? TaskRepository.encode(store.tasks) {
                        exportDoc = BackupDocument(data: data)
                        exporting = true
                    }
                } label: { Label("Sao lưu ra file…", systemImage: "square.and.arrow.up") }
                Button {
                    importing = true
                } label: { Label("Khôi phục từ file…", systemImage: "square.and.arrow.down") }
                Button {
                    WidgetCenter.shared.reloadAllTimelines()
                    message = "Đã làm mới widget."
                } label: { Label("Làm mới widget", systemImage: "arrow.clockwise") }
            }

            Section {
                LabeledContent("Phiên bản", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                LabeledContent("Số công việc", value: "\(store.tasks.count)")
            } footer: {
                Text("TodoLock – bản cá nhân. Dữ liệu chỉ lưu trên máy này, không gửi đi đâu.")
            }
        }
        .navigationTitle("Cài đặt")
        .task { await refreshNotifStatus() }
        .onChange(of: showEventsInWidget) { _, _ in WidgetCenter.shared.reloadAllTimelines() }
        .onChange(of: hideCompletedInWidget) { _, _ in WidgetCenter.shared.reloadAllTimelines() }
        .onChange(of: reminderMinutes) { _, _ in NotificationManager.shared.reschedule(store.tasks) }
        .fileExporter(isPresented: $exporting, document: exportDoc, contentType: .json,
                      defaultFilename: "TodoLock-\(DayKey.string(Date()))") { result in
            if case .success = result { message = "Đã sao lưu \(store.tasks.count) công việc." }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case let .success(url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                pendingImport = try TaskRepository.decode(data)
            } catch {
                message = "Không đọc được file: \(error.localizedDescription)"
            }
        }
        .confirmationDialog("Thay toàn bộ dữ liệu hiện tại bằng \(pendingImport?.count ?? 0) công việc từ file?",
                            isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
                            titleVisibility: .visible) {
            Button("Khôi phục", role: .destructive) {
                if let tasks = pendingImport { store.replaceAll(tasks) }
                message = "Đã khôi phục \(pendingImport?.count ?? 0) công việc."
                pendingImport = nil
            }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                reminderMinutes = (c.hour ?? 9) * 60 + (c.minute ?? 0)
            }
        )
    }

    private var calendarStatusText: String {
        switch events.status {
        case .fullAccess: return "Đã cho phép"
        case .denied: return "Bị từ chối"
        case .restricted: return "Bị hạn chế"
        case .writeOnly: return "Chỉ ghi"
        case .notDetermined: return "Chưa hỏi"
        @unknown default: return "—"
        }
    }

    private var notifStatusText: String {
        switch notifStatus {
        case .authorized, .provisional, .ephemeral: return "Đã bật"
        case .denied: return "Đã tắt"
        case .notDetermined: return "Chưa hỏi"
        @unknown default: return "—"
        }
    }

    private func refreshNotifStatus() async {
        notifStatus = await NotificationManager.shared.authorizationStatus()
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
