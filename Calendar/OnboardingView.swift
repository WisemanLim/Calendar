import SwiftUI

/// 인트로/온보딩 — 최초 실행(또는 DEBUG 매회) 노출.
/// 사용 가이드 → 플래너 모드 선택 → Google 연동 가이드 → 알림 가이드 → 완료.
struct OnboardingView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var notifications = NotificationManager.shared
    var onFinish: () -> Void

    @State private var page = 0
    private let lastPage = 3

    var body: some View {
        VStack {
            TabView(selection: $page) {
                guidePage.tag(0)
                modePage.tag(1)
                googlePage.tag(2)
                notificationPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(page == lastPage ? "시작하기" : "다음") {
                if page == lastPage {
                    settings.onboardingCompleted = true
                    onFinish()
                } else {
                    withAnimation { page += 1 }
                }
            }
            .font(.system(size: 18, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private func page(icon: String, title: String, _ body: AnyView) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: icon).font(.system(size: 64)).foregroundColor(.blue)
            Text(title).font(.system(size: 26, weight: .bold))
            body.padding(.horizontal, 32)
            Spacer()
        }
    }

    private var guidePage: some View {
        page(icon: "calendar", title: "Wise Calendar",
             AnyView(Text("큰 날짜 화면을 좌우로 스와이프해 날짜를 넘기고, 상단에서 월·연도를 이동합니다. 하단 미니 달력으로 빠르게 점프하세요.")
                .multilineTextAlignment(.center).foregroundColor(.gray)))
    }

    private var modePage: some View {
        page(icon: "square.grid.2x2", title: "사용 방식 선택",
             AnyView(VStack(spacing: 12) {
                ForEach(PlannerMode.allCases) { mode in
                    Button {
                        settings.plannerMode = mode
                    } label: {
                        HStack {
                            Label(mode.title, systemImage: mode.systemImage)
                            Spacer()
                            if settings.plannerMode == mode {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
             }))
    }

    private var googlePage: some View {
        page(icon: "link", title: "캘린더 연동",
             AnyView(Text("기기 설정 → 캘린더 → 계정에서 Google·iCloud 계정을 추가하면, 이 앱이 해당 일정을 자동으로 표시합니다.")
                .multilineTextAlignment(.center).foregroundColor(.gray)))
    }

    private var notificationPage: some View {
        page(icon: "bell.badge", title: "알림",
             AnyView(VStack(spacing: 16) {
                Text("일정 알림을 받으려면 알림을 허용하세요. 설정에서 언제든 변경할 수 있습니다.")
                    .multilineTextAlignment(.center).foregroundColor(.gray)
                Button("알림 허용") {
                    settings.notificationsEnabled = true
                    Task { await notifications.requestAuthorization() }
                }
                .padding(.horizontal, 24).padding(.vertical, 10)
                .background(Color.blue.opacity(0.1)).cornerRadius(10)
             }))
    }
}
