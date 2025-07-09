import EventKit
import os.log

@MainActor
class EventStoreManager: NSObject, ObservableObject {
    static let shared = EventStoreManager()
    private let eventStore = EKEventStore()
    private let logger = Logger(subsystem: "com.yourcompany.Calendar", category: "EventStore")
    
    @Published private(set) var hasAccess: Bool = false
    @Published private(set) var events: [String: [String]] = [:] // dateString: [eventStrings]
    
    private override init() {
        super.init()
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
                        if granted {
                            self.logger.debug("Calendar access granted")
                        } else {
                            self.logger.warning("Calendar access denied")
                        }
                    }
                } else {
                    // Fallback for earlier iOS versions
                    let granted = try await eventStore.requestAccess(to: .event)
                    await MainActor.run {
                        self.hasAccess = granted
                        if granted {
                            self.logger.debug("Calendar access granted")
                        } else {
                            self.logger.warning("Calendar access denied")
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.hasAccess = false
                    self.logger.error("Error requesting calendar access: \(error.localizedDescription)")
                }
            }
            
        case .denied, .restricted, .writeOnly:
            await MainActor.run {
                self.hasAccess = false
                self.logger.warning("Calendar access not available")
            }
            
        @unknown default:
            await MainActor.run {
                self.hasAccess = false
                self.logger.error("Unknown calendar authorization status")
            }
        }
    }
    
    func fetchEvents(for date: Date) -> [String] {
        guard hasAccess else {
            logger.warning("No calendar access")
            return []
        }
        
        let dateKey = dateKey(from: date)
        
        // Return cached events if available
        if let cachedEvents = events[dateKey] {
            return cachedEvents
        }
        
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            logger.error("Could not calculate end of day")
            return []
        }
        
        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )
        
        let events = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .compactMap { event in
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                let timeString = timeFormatter.string(from: event.startDate)
                if let title = event.title, !title.isEmpty {
                    return "\(timeString) \(title)"
                }
                return nil
            }
        
        // Cache the events
        Task { @MainActor in
            self.events[dateKey] = events
        }
        
        return events
    }
    
    func dateKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
