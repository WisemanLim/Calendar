import SwiftUI

/// 앱 설정 — (1)연동 (2)사용자 테마(플래너 모드) (3)알림. 일반 캘린더 앱 준용.
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var eventStore: EventStoreManager
    @ObservedObject var notifications = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // (2) 사용자 테마 = 플래너 모드
                Section {
                    Picker("입력 방식", selection: $settings.plannerMode) {
                        ForEach(PlannerMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    Text(settings.plannerMode.detail)
                        .font(.caption)
                        .foregroundColor(.gray)
                } header: {
                    Text("사용자 테마")
                }

                // (3) 알림
                Section("알림") {
                    Toggle("일정 알림", isOn: $settings.notificationsEnabled)
                        .onChange(of: settings.notificationsEnabled) { _, on in
                            if on { Task { await notifications.requestAuthorization() } }
                        }
                    if settings.notificationsEnabled && !notifications.authorized {
                        Text("기기 설정에서 알림 권한을 허용해야 알림이 표시됩니다.")
                            .font(.caption).foregroundColor(.orange)
                    }
                }

                // (1) 연동 — 시스템 계정 기반
                Section {
                    let sources = eventStore.calendarSources()
                    if sources.isEmpty {
                        Text("연동된 캘린더가 없습니다. 기기 설정 → 캘린더에서 Google/iCloud 계정을 추가하세요.")
                            .font(.caption).foregroundColor(.gray)
                    } else {
                        ForEach(sources, id: \.id) { src in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(src.title)
                                    Text(src.source).font(.caption2).foregroundColor(.gray)
                                }
                                Spacer()
                                if settings.enabledCalendarIDs.isEmpty || settings.enabledCalendarIDs.contains(src.id) {
                                    Image(systemName: "checkmark").foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { toggleCalendar(src.id) }
                        }
                    }
                } header: {
                    Text("캘린더 연동")
                } footer: {
                    Text("Google 캘린더는 기기 설정 → 캘린더 → 계정 추가로 연결되며, 이 앱이 자동으로 표시합니다.")
                }

                // (4) 고객지원
                Section {
                    NavigationLink("고객지원") { SupportView() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("설정").font(.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        colorSchemeToggleButton
                        Button("완료") { dismiss() }
                    }
                }
            }
        }
    }

    private var colorSchemeToggleButton: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                settings.appColorScheme = settings.appColorScheme.next
            }
        } label: {
            Image(systemName: settings.appColorScheme.icon)
                .font(.system(size: 20))
                .contentTransition(.symbolEffect(.replace.byLayer.downUp))
        }
    }

    private func toggleCalendar(_ id: String) {
        if settings.enabledCalendarIDs.contains(id) {
            settings.enabledCalendarIDs.removeAll { $0 == id }
        } else {
            settings.enabledCalendarIDs.append(id)
        }
    }
}
