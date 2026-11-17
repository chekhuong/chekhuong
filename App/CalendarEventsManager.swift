import Foundation
import EventKit
import WidgetKit

@MainActor
final class CalendarEventsManager: ObservableObject {
    @Published private(set) var status: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published private(set) var events: [EventSnapshot] = []

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?

    init() {
        refresh()
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    var isAuthorized: Bool { status == .fullAccess }

    func requestAccess() async {
        _ = try? await store.requestFullAccessToEvents()
        refresh()
    }

    func refresh() {
        status = EKEventStore.authorizationStatus(for: .event)
        guard isAuthorized else {
            events = []
            return
        }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -60, to: today) ?? today
        events = EventFetcher.fetch(store: store, from: start, days: 425)

        // Cache 14 ngày tới cho widget
        let cacheEnd = cal.date(byAdding: .day, value: 14, to: today) ?? today
        EventCache.save(events.filter { $0.end >= today && $0.start < cacheEnd })
        WidgetCenter.shared.reloadAllTimelines()
    }

    func events(on day: Date) -> [EventSnapshot] {
        events.filter { $0.overlaps(day: day) }
    }
}
