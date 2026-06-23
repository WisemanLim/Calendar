import Foundation
import Combine
import SwiftUI

// MARK: - AppColorScheme

enum AppColorScheme: String, CaseIterable {
    case system, dark, light

    var icon: String {
        switch self {
        case .system: return "desktopcomputer"
        case .dark:   return "moon.fill"
        case .light:  return "sun.max.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark:   return .dark
        case .light:  return .light
        }
    }

    var next: AppColorScheme {
        switch self {
        case .system: return .dark
        case .dark:   return .light
        case .light:  return .system
        }
    }
}

// MARK: - AppSettings

/// 앱 설정 — UserDefaults 영속. 일반 캘린더 앱 설정 준용.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults: UserDefaults
    static let currentBundleVersion: String =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    private enum Key {
        static let plannerMode = "settings.plannerMode"
        static let notifications = "settings.notificationsEnabled"
        static let onboarding = "settings.onboardingCompleted"
        static let enabledCalendarIDs = "settings.enabledCalendarIDs"
        static let lastSeenVersion = "settings.lastSeenVersion"
        static let appColorScheme = "settings.appColorScheme"
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
    /// 온보딩을 마지막으로 완료한 앱 버전. 현재 버전과 다르면 재노출.
    @Published var lastSeenVersion: String {
        didSet { defaults.set(lastSeenVersion, forKey: Key.lastSeenVersion) }
    }
    @Published var appColorScheme: AppColorScheme {
        didSet { defaults.set(appColorScheme.rawValue, forKey: Key.appColorScheme) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let rawMode = defaults.string(forKey: Key.plannerMode) ?? PlannerMode.todo.rawValue
        self.plannerMode = PlannerMode(rawValue: rawMode) ?? .todo
        self.notificationsEnabled = defaults.bool(forKey: Key.notifications)
        self.onboardingCompleted = defaults.bool(forKey: Key.onboarding)
        self.enabledCalendarIDs = defaults.stringArray(forKey: Key.enabledCalendarIDs) ?? []
        self.lastSeenVersion = defaults.string(forKey: Key.lastSeenVersion) ?? ""
        let rawScheme = defaults.string(forKey: Key.appColorScheme) ?? AppColorScheme.system.rawValue
        self.appColorScheme = AppColorScheme(rawValue: rawScheme) ?? .system
    }

    /// 온보딩 노출 조건: DEBUG 매회 / 최초 설치 / 재설치(UserDefaults 초기화) / 버전 업데이트.
    var shouldShowOnboarding: Bool {
//        #if DEBUG // 디버그 모드 스킵
//        return true
//        #else
        return !onboardingCompleted || lastSeenVersion != Self.currentBundleVersion
//        #endif
    }
}
