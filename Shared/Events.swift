import Foundation
import EventKit
import UIKit

/// Bản sao gọn của một sự kiện Lịch (để lưu cache cho widget).
struct EventSnapshot: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var red: Double
    var green: Double
    var blue: Double

    func overlaps(day: Date, calendar cal: Calendar = .current) -> Bool {
        let s = cal.startOfDay(for: day)
        guard let e = cal.date(byAdding: .day, value: 1, to: s) else { return false }
        if start == end { return start >= s && start < e }
        return start < e && end > s
    }
}

enum EventFetcher {
    static var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    static func fetch(store: EKEventStore = EKEventStore(), from start: Date, days: Int) -> [EventSnapshot] {
        guard isAuthorized,
              let end = Calendar.current.date(byAdding: .day, value: days, to: start) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { ev in
            var r: CGFloat = 0.5, g: CGFloat = 0.5, b: CGFloat = 0.5, a: CGFloat = 1
            if let cg = ev.calendar?.cgColor {
                UIColor(cgColor: cg).getRed(&r, green: &g, blue: &b, alpha: &a)
            }
            let start: Date = ev.startDate ?? Date()
            let ident: String = ev.eventIdentifier ?? UUID().uuidString
            return EventSnapshot(
                id: ident + "@" + String(Int(start.timeIntervalSince1970)),
                title: ev.title ?? "(Không tên)",
                start: start,
                end: ev.endDate ?? start,
                isAllDay: ev.isAllDay,
                red: Double(r), green: Double(g), blue: Double(b)
            )
        }
        .sorted { $0.start < $1.start }
    }
}

enum EventCache {
    static func save(_ events: [EventSnapshot]) {
        if let data = try? TaskRepository.makeEncoder().encode(events) {
            try? data.write(to: SharedConfig.eventsCacheURL, options: .atomic)
        }
    }

    static func load() -> [EventSnapshot] {
        guard let data = try? Data(contentsOf: SharedConfig.eventsCacheURL) else { return [] }
        return (try? TaskRepository.makeDecoder().decode([EventSnapshot].self, from: data)) ?? []
    }

    /// Sự kiện trong ngày: đọc trực tiếp EventKit nếu được phép, nếu không thì dùng cache.
    static func events(on day: Date) -> [EventSnapshot] {
        let start = Calendar.current.startOfDay(for: day)
        if EventFetcher.isAuthorized {
            return EventFetcher.fetch(from: start, days: 1).filter { $0.overlaps(day: start) }
        }
        return load().filter { $0.overlaps(day: start) }
    }
}
