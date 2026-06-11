import SwiftUI

/// 앱 루트 — 온보딩 노출 분기 후 캘린더.
struct RootView: View {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var templateStore = TemplateStore.shared
    @State private var showOnboarding: Bool

    init() {
        _showOnboarding = State(initialValue: AppSettings.shared.shouldShowOnboarding)
    }

    var body: some View {
        CalendarView(settings: settings, templateStore: templateStore)
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(settings: settings) { showOnboarding = false }
            }
            .preferredColorScheme(settings.appColorScheme.colorScheme)
    }
}
