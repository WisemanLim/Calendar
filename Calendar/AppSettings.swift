import Foundation
import Combine

/// 앱 설정 — UserDefaults 영속. 일반 캘린더 앱 설정 준용.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults: UserDefaults
    private enum Key {
        static let plannerMode = "settings.plannerMode"
        static let notifications = "settings.notificationsEnabled"
        static let onboarding = "settings.onboardingCompleted"
        static let enabledCalendarIDs = "settings.enabledCalendarIDs"
    }

    @Published var plannerMode: PlannerMode {
        didSet { defaults.set(plannerMode.rawValue, forKey: Key.plannerMode) }
    }
    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Key.notifications) }
    }
    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: Key.onboarding) }
    }
    /// 표시할 캘린더 소스(EKCalendar.calendarIdentifier) 화이트리스트. 빈 배열 = 전체.
    @Published var enabledCalendarIDs: [String] {
        didSet { defaults.set(enabledCalendarIDs, forKey: Key.enabledCalendarIDs) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let rawMode = defaults.string(forKey: Key.plannerMode) ?? PlannerMode.todo.rawValue
        self.plannerMode = PlannerMode(rawValue: rawMode) ?? .todo
        self.notificationsEnabled = defaults.bool(forKey: Key.notifications)
        self.onboardingCompleted = defaults.bool(forKey: Key.onboarding)
        self.enabledCalendarIDs = defaults.stringArray(forKey: Key.enabledCalendarIDs) ?? []
    }

    /// 온보딩을 노출할지. DEBUG 빌드에서는 매번, 릴리스에서는 최초 1회.
    var shouldShowOnboarding: Bool {
        #if DEBUG
        return true
        #else
        return !onboardingCompleted
        #endif
    }
}
