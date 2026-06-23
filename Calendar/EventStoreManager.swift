import EventKit
import UIKit
import os.log

/// 캘린더 이벤트 표시용 값 타입. overdue/todo 여부 포함.
struct CalendarEventItem: Identifiable {
    let id: String
    let title: String
    let displayTitle: String  // "HH:mm 제목"
    let startDate: Date
    let isOverdue: Bool
    let isTodo: Bool
}

@MainActor
class EventStoreManager: NSObject, ObservableObject {
    static let shared = EventStoreManager()
    private let eventStore = EKEventStore()
    private let logger = Logger(subsystem: "com.yourcompany.Calendar", category: "EventStore")

    @Published private(set) var hasAccess: Bool = false
    @Published private(set) var events: [String: [CalendarEventItem]] = [:]
    @Published private(set) var cachedEventCounts: [String: Int] = [:]

    private override init() {
        super.init()
        if let cache = UserDefaults.standard.dictionary(forKey: "wc.eventCountCache") as? [String: Int] {
            cachedEventCounts = cache
        }
        Task {
            await requestAccess()
        }
    }

    func requestAccess() async {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .authorized, .fullAccess:
            self.hasAccess = true
            logger.debug("Calendar access already authorized")

        case .notDetermined:
            logger.debug("Requesting calendar access...")
            do {
                if #available(iOS 17.0, *) {
                    let granted = try await eventStore.requestFullAccessToEvents()
                    await MainActor.run {
                        self.hasAccess = granted
                    }
                } else {
                    let granted = try await eventStore.requestAccess(to: .event)
                    await MainActor.run {
                        self.hasAccess = granted
                    }
                }
            } catch {
                await MainActor.run {
                    self.hasAccess = false
                    self.logger.error("Error requesting calendar access: \(error.localizedDescription)")
                }
            }

        case .denied, .restricted, .writeOnly:
            await MainActor.run { self.hasAccess = false }

        @unknown default:
            await MainActor.run { self.hasAccess = false }
        }
    }

    @discardableResult
    func fetchEvents(for date: Date) -> [CalendarEventItem] {
        guard hasAccess else { return [] }

        let key = dateKey(from: date)
        if let cached = events[key] { return cached }

        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"

        let items: [CalendarEventItem] = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .compactMap { event in
                guard let t = event.title, !t.isEmpty else { return nil }
                let notes = event.notes ?? ""
                let isTodo = notes.contains("- [ ]") || notes.contains("- [x]")
                let isOverdue = isTodo && event.startDate < now && notes.contains("- [ ]")
                return CalendarEventItem(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: t,
                    displayTitle: "\(fmt.string(from: event.startDate)) \(t)",
                    startDate: event.startDate,
                    isOverdue: isOverdue,
                    isTodo: isTodo
                )
            }

        self.events[key] = items
        updateCountCache(key: key, count: items.count)
        return items
    }

    func dateKey(from date: Date) -> String { CalendarLogic.dateKey(from: date) }

    /// 이벤트 저장. 성공 시 eventIdentifier 반환, 실패 시 nil.
    @discardableResult
    func addEvent(
        title: String,
        notes: String?,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        recurrenceRules: [EKRecurrenceRule]? = nil
    ) -> String? {
        guard hasAccess else {
            logger.warning("No calendar access for write")
            return nil
        }
        let event = EKEvent(eventStore: eventStore)
        event.title = title.isEmpty ? "(제목 없음)" : title
        event.notes = notes
        event.location = location
        event.calendar = eventStore.defaultCalendarForNewEvents
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        if let rules = recurrenceRules { event.recurrenceRules = rules }
        do {
            try eventStore.save(event, span: .thisEvent)
            invalidateCache(for: startDate)
            _ = fetchEvents(for: startDate)
            return event.eventIdentifier
        } catch {
            logger.error("Failed to save event: \(error.localizedDescription)")
            return nil
        }
    }

    func invalidateCache(for date: Date) { events[dateKey(from: date)] = nil }

    private func updateCountCache(key: String, count: Int) {
        var cache = UserDefaults.standard.dictionary(forKey: "wc.eventCountCache") as? [String: Int] ?? [:]
        guard cache[key] != count else { return }
        cache[key] = count
        UserDefaults.standard.set(cache, forKey: "wc.eventCountCache")
        cachedEventCounts[key] = count
    }

    /// 달 전체 이벤트를 단일 쿼리로 불러와 일별 캐시를 채운다.
    /// 이미 캐시된 날은 건너뜀. 미니 달력 색상 즉시 표시용.
    func fetchEventsForMonth(year: Int, month: Int) {
        guard hasAccess else { return }
        var startComps = DateComponents()
        startComps.year = year; startComps.month = month; startComps.day = 1
        guard let startOfMonth = Calendar.current.date(from: startComps),
              let startOfNext = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth)
        else { return }

        let predicate = eventStore.predicateForEvents(withStart: startOfMonth, end: startOfNext, calendars: nil)
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"

        var byDay: [String: [EKEvent]] = [:]
        for event in eventStore.events(matching: predicate) {
            byDay[dateKey(from: event.startDate), default: []].append(event)
        }

        var current = startOfMonth
        while current < startOfNext {
            let key = dateKey(from: current)
            if events[key] == nil {
                events[key] = (byDay[key] ?? [])
                    .sorted { $0.startDate < $1.startDate }
                    .compactMap { event -> CalendarEventItem? in
                        guard let t = event.title, !t.isEmpty else { return nil }
                        let notes = event.notes ?? ""
                        let isTodo = notes.contains("- [ ]") || notes.contains("- [x]")
                        let isOverdue = isTodo && event.startDate < now && notes.contains("- [ ]")
                        return CalendarEventItem(
                            id: event.eventIdentifier ?? UUID().uuidString,
                            title: t,
                            displayTitle: "\(fmt.string(from: event.startDate)) \(t)",
                            startDate: event.startDate,
                            isOverdue: isOverdue,
                            isTodo: isTodo
                        )
                    }
                updateCountCache(key: key, count: events[key]?.count ?? 0)
            }
            current = Calendar.current.date(byAdding: .day, value: 1, to: current) ?? startOfNext
        }
    }

    func fetchEvent(id: String) -> EKEvent? {
        guard hasAccess else { return nil }
        return eventStore.event(withIdentifier: id)
    }

    @discardableResult
    func deleteEvent(id: String, on date: Date) -> Bool {
        guard hasAccess, let event = eventStore.event(withIdentifier: id) else { return false }
        do {
            try eventStore.remove(event, span: .thisEvent)
            invalidateCache(for: date)
            _ = fetchEvents(for: date)
            return true
        } catch {
            logger.error("Delete failed: \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    func updateEvent(id: String, title: String, notes: String?,
                     startDate: Date, endDate: Date, location: String?,
                     on date: Date) -> Bool {
        guard hasAccess, let event = eventStore.event(withIdentifier: id) else { return false }
        event.title = title.isEmpty ? "(제목 없음)" : title
        event.notes = notes
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        do {
            try eventStore.save(event, span: .thisEvent)
            invalidateCache(for: date)
            _ = fetchEvents(for: date)
            return true
        } catch {
            logger.error("Update failed: \(error.localizedDescription)")
            return false
        }
    }

    /// 제목 또는 메모에 query를 포함하는 이벤트를 검색합니다 (startDate~endDate 범위).
    func searchEvents(query: String, from startDate: Date, to endDate: Date) -> [CalendarEventItem] {
        guard hasAccess, !query.isEmpty else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let q = query.lowercased()
        return eventStore.events(matching: predicate)
            .filter { ev in
                (ev.title ?? "").lowercased().contains(q) ||
                (ev.notes ?? "").lowercased().contains(q)
            }
            .sorted { $0.startDate < $1.startDate }
            .compactMap { event -> CalendarEventItem? in
                guard let t = event.title, !t.isEmpty else { return nil }
                let notes = event.notes ?? ""
                let isTodo = notes.contains("- [ ]") || notes.contains("- [x]")
                let isOverdue = isTodo && event.startDate < now && notes.contains("- [ ]")
                return CalendarEventItem(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: t,
                    displayTitle: "\(fmt.string(from: event.startDate)) \(t)",
                    startDate: event.startDate,
                    isOverdue: isOverdue,
                    isTodo: isTodo
                )
            }
    }

    func calendarSources() -> [(id: String, title: String, source: String)] {
        guard hasAccess else { return [] }
        return eventStore.calendars(for: .event).map {
            (id: $0.calendarIdentifier, title: $0.title, source: $0.source.title)
        }
    }
}

// MARK: - EventImageStore

/// 이벤트별 사진 저장소 — Documents에 JPEG, UserDefaults로 eventID 매핑.
final class EventImageStore {
    static let shared = EventImageStore()
    private let defaults = UserDefaults.standard
    private let mapKey = "com.wisecalendar.eventImageMap"

    private var map: [String: String] {
        get { defaults.dictionary(forKey: mapKey) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: mapKey) }
    }

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    @discardableResult
    func saveImage(_ image: UIImage, for eventId: String) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return false }
        let filename = map[eventId] ?? UUID().uuidString + ".jpg"
        let url = documentsURL.appendingPathComponent(filename)
        do {
            try data.write(to: url)
            var m = map; m[eventId] = filename; map = m
            return true
        } catch { return false }
    }

    func loadImage(for eventId: String) -> UIImage? {
        guard let filename = map[eventId] else { return nil }
        let url = documentsURL.appendingPathComponent(filename)
        return (try? Data(contentsOf: url)).flatMap { UIImage(data: $0) }
    }

    func deleteImage(for eventId: String) {
        guard let filename = map[eventId] else { return }
        try? FileManager.default.removeItem(at: documentsURL.appendingPathComponent(filename))
        var m = map; m.removeValue(forKey: eventId); map = m
    }
}
