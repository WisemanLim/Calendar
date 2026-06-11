import Foundation
import UserNotifications
import os.log

/// 로컬 알림 — 권한 요청 + 일정 알림 예약. 백엔드/푸시 없음.
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    private let logger = Logger(subsystem: "com.wise.Calendar", category: "Notifications")

    @Published private(set) var authorized = false

    private init() {}

    /// 권한 요청. 설정에서 알림 ON 선택 시 호출.
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            self.authorized = granted
            logger.debug("Notification authorization: \(granted)")
        } catch {
            self.authorized = false
            logger.error("Notification auth error: \(error.localizedDescription)")
        }
    }

    /// 지정 날짜(오전 9시)에 단발 알림 예약.
    func scheduleEventReminder(title: String, on date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "일정 알림"
        content.body = title
        content.sound = .default

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = 9
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
