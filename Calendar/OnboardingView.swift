import SwiftUI

/// 인트로/온보딩 — 최초 설치·재설치·버전 업데이트(또는 DEBUG 매회) 노출.
/// 4단계: 소개+모드선택 → 일기+할일 → 개인이벤트 → 연동+알림
struct OnboardingView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var notifications = NotificationManager.shared
    var onFinish: () -> Void

    @State private var page = 0
    private let lastPage = 3

    var body: some View {
        VStack {
            TabView(selection: $page) {
                introPage.tag(0)
                modesPage.tag(1)
                personalEventDetailPage.tag(2)
                integrationPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(page == lastPage ? "시작하기" : "다음") {
                if page == lastPage {
                    settings.onboardingCompleted = true
                    settings.lastSeenVersion = AppSettings.currentBundleVersion
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

    // MARK: - Page 0: Intro + Mode Selection

    private var introPage: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("🗓️").font(.system(size: 56))
                    Text("Wise Calendar").font(.system(size: 26, weight: .bold))
                    Text("나만의 iOS 플래너 앱").font(.system(size: 15)).foregroundColor(.secondary)
                }
                .padding(.top, 32)

                sceneCard(
                    background: Color(red: 0.94, green: 0.97, blue: 1.0),
                    content: AnyView(
                        VStack(spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                Text("😊").font(.system(size: 44))
                                VStack(alignment: .leading, spacing: 6) {
                                    speechBubble("오늘 일정을 한눈에!\n크게 보고 빠르게 입력하자 📅", color: .blue.opacity(0.1))
                                }
                            }
                            HStack {
                                Spacer()
                                Text("좌우 스와이프로 날짜 이동 · 하단 달력으로 빠른 점프")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                        }
                    )
                )

                featureList([
                    ("calendar", "큰 날짜 히어로 화면"),
                    ("arrow.left.arrow.right", "스와이프로 날짜·월·연도 이동"),
                    ("cloud.sun.fill", "주간 날씨 + 이벤트 현황 한눈에"),
                ])
                .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    Text("사용 방식 선택").font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)

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
                        .padding(.horizontal, 24)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "gearshape").foregroundColor(.blue)
                    Text("선택한 방식은 설정에서 언제든지 변경할 수 있습니다.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Page 1: Diary + Todo Modes

    private var modesPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("📖 📋").font(.system(size: 48))
                    Text("입력 모드").font(.system(size: 26, weight: .bold))
                    Text("두 가지 기록 방식을 골라 사용하세요").font(.system(size: 15)).foregroundColor(.secondary)
                }
                .padding(.top, 32)

                // Diary section
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Text("📖").font(.system(size: 28))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("일기 모드").font(.system(size: 17, weight: .bold))
                            Text("하루를 글로 기록합니다").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    sceneCard(
                        background: Color(red: 1.0, green: 0.97, blue: 0.88),
                        content: AnyView(
                            VStack(spacing: 10) {
                                HStack(alignment: .top, spacing: 12) {
                                    Text("🧑‍💻").font(.system(size: 40))
                                    speechBubble("오늘 드디어 프로젝트 완료…\n소회를 남겨야겠다 📝", color: .orange.opacity(0.1))
                                }
                                HStack {
                                    Spacer()
                                    Text("시작 → 저장 시각 자동 기록").font(.system(size: 11)).foregroundColor(.gray)
                                }
                            }
                        )
                    )

                    featureList([
                        ("pencil.tip", "자유로운 본문 입력"),
                        ("timer", "에디터 열린 시각 = 시작, 저장 시각 = 종료 자동"),
                        ("clock", "경과 시간 실시간 표시"),
                    ])
                    .padding(.horizontal, 24)
                }

                Divider().padding(.horizontal, 24)

                // Todo section
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Text("📋").font(.system(size: 28))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("일정관리 모드").font(.system(size: 17, weight: .bold))
                            Text("잊지 말아야 할 일들을 체크리스트로").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    sceneCard(
                        background: Color(red: 0.94, green: 0.96, blue: 1.0),
                        content: AnyView(
                            VStack(spacing: 10) {
                                HStack(alignment: .top, spacing: 12) {
                                    Text("😰").font(.system(size: 40))
                                    speechBubble("또 잊어버렸다…\n이번엔 체크리스트로 관리해야지!", color: .blue.opacity(0.1))
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    todoRow("기획서 제출", done: true)
                                    todoRow("팀 미팅 자료 준비", done: false)
                                    todoRow("클라이언트 회신", done: false)
                                }
                                .padding(.horizontal, 4)
                            }
                        )
                    )

                    featureList([
                        ("checklist", "항목별 완료 토글"),
                        ("calendar.badge.clock", "기한(Due Date) 필수 설정"),
                        ("exclamationmark.circle.fill", "기한 초과 항목 빨간색 강조"),
                    ])
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - Page 2: PersonalEvent Mode Detail

    private var personalEventDetailPage: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("🗂️").font(.system(size: 56))
                    Text("개인 이벤트").font(.system(size: 26, weight: .bold))
                    Text("템플릿으로 빠르게 입력하세요").font(.system(size: 15)).foregroundColor(.secondary)
                }
                .padding(.top, 32)

                eventTypeCard(
                    emoji: "👴💊", color: Color(red: 0.95, green: 1.0, blue: 0.95),
                    title: "복용", subtitle: "아침 7시 · 점심 12시 · 저녁 18시",
                    description: "노인 또는 만성 질환 관리에 유용합니다.\n아침/점심/저녁 프리셋으로 빠르게 입력하고\n약 봉투 사진도 카메라·앨범으로 바로 첨부할 수 있습니다.",
                    badge: "📷 사진 첨부 지원",
                    permissionNote: "사진 첨부 시 카메라 및 앨범(사진 보관함) 접근 권한이 필요합니다."
                )

                eventTypeCard(
                    emoji: "💑", color: Color(red: 1.0, green: 0.95, blue: 0.97),
                    title: "약속", subtitle: "연인 · 친구 · 회식",
                    description: "기다려지는 만남을 등록하세요.\n장소(location)를 입력하면 iOS 지도 앱과 연동됩니다.",
                    badge: nil
                )

                eventTypeCard(
                    emoji: "🔄📅", color: Color(red: 0.95, green: 0.95, blue: 1.0),
                    title: "고정", subtitle: "정기 작업 · 연간 반복",
                    description: "매년 반복되는 일정을 등록합니다.\n[#162] 알레르기 약 복용(-/-) 처럼 연중 일련번호로\n자동 태그됩니다.",
                    badge: "↻ 매년 자동 반복"
                )

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Page 3: Integration + Notifications

    private var integrationPage: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("🔗 🔔").font(.system(size: 48))
                    Text("연동 & 알림").font(.system(size: 26, weight: .bold))
                    Text("캘린더 연동과 알림을 설정하세요").font(.system(size: 15)).foregroundColor(.secondary)
                }
                .padding(.top, 32)

                sceneCard(
                    background: Color(red: 0.95, green: 1.0, blue: 0.95),
                    content: AnyView(
                        VStack(spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                Text("📱").font(.system(size: 40))
                                speechBubble("Google 캘린더 일정이\n자동으로 여기 보이네! 🎉", color: .green.opacity(0.12))
                            }
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "link").foregroundColor(.blue)
                                Text("설정 → 캘린더 → 계정 추가 → Google/iCloud 로그인")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    )
                )

                featureList([
                    ("calendar.badge.checkmark", "Google·iCloud 캘린더 자동 표시"),
                    ("checkmark.circle", "앱 설정(⚙)에서 표시 캘린더 선택"),
                    ("lock.shield", "기기 계정 기반 — 별도 로그인 불필요"),
                ])
                .padding(.horizontal, 24)

                Divider().padding(.horizontal, 24)

                sceneCard(
                    background: Color(red: 1.0, green: 0.97, blue: 0.92),
                    content: AnyView(
                        VStack(spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                Text("🔔").font(.system(size: 40))
                                speechBubble("오전 9시 알림 덕분에\n일정을 하나도 안 놓쳤다!", color: .orange.opacity(0.1))
                            }
                            Button("알림 허용") {
                                settings.notificationsEnabled = true
                                Task { await notifications.requestAuthorization() }
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(10)
                            .frame(maxWidth: .infinity)
                        }
                    )
                )

                featureList([
                    ("bell.badge", "이벤트 저장 시 당일 오전 9시 알림 예약"),
                    ("gearshape", "설정에서 언제든지 알림 on/off 변경 가능"),
                ])
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Reusable sub-components

    private func sceneCard(background: Color, content: AnyView) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .cornerRadius(16)
            .padding(.horizontal, 20)
    }

    private func speechBubble(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 13))
            .padding(10)
            .background(color)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }

    private func todoRow(_ text: String, done: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.square.fill" : "square")
                .foregroundColor(done ? .blue : .gray)
                .font(.system(size: 14))
            Text(text)
                .font(.system(size: 13))
                .strikethrough(done, color: .gray)
                .foregroundColor(done ? .gray : .primary)
        }
    }

    private func featureList(_ items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items, id: \.0) { symbol, text in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: symbol)
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(width: 22)
                    Text(text)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func eventTypeCard(emoji: String, color: Color, title: String,
                                subtitle: String, description: String, badge: String?,
                                permissionNote: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(emoji).font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 17, weight: .bold))
                    Text(subtitle).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(8)
                        .foregroundColor(.blue)
                }
            }
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineSpacing(3)
            if let note = permissionNote {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color)
        .cornerRadius(14)
    }
}
