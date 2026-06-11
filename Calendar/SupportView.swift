import SwiftUI

// MARK: - SupportView

struct SupportView: View {
    @Environment(\.dismiss) private var dismiss
    private let version = AppSettings.currentBundleVersion

    var body: some View {
        Form {
            Section("가이드") {
                NavigationLink("도움말 센터") { HelpCenterView() }
                NavigationLink("자주 묻는 질문") { FAQView() }
            }

            Section {
                HStack {
                    Text("현재 버전")
                    Spacer()
                    Text(version).foregroundColor(.secondary)
                }
                Button("업데이트 확인") {
                    if let url = URL(string: "itms-apps://itunes.apple.com/kr/app/apple-store/id") {
                        UIApplication.shared.open(url)
                    }
                }
                .foregroundColor(.primary)
            }

            Section("문제 해결") {
                NavigationLink("일반적인 문제") { TroubleshootingView() }
                NavigationLink("동기화 문제 해결 안내서") { SyncGuideView() }
                Button("이메일 보내기") {
                    let subject = "Wise Calendar 문의 v\(version)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "mailto:support@wisecalendar.app?subject=\(subject)") {
                        UIApplication.shared.open(url)
                    }
                }
                .foregroundColor(.primary)
                NavigationLink("디버그 로그 보내기") { DebugLogView() }
            }
        }
        .navigationTitle("고객지원")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("v\(version)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
    }
}

// MARK: - HelpCenterView

private struct HelpCenterView: View {
    var body: some View {
        List {
            Section("기본 사용법") {
                helpRow("arrow.left.arrow.right", "날짜 이동",
                        "히어로 영역을 좌우로 스와이프하거나 하단 달력의 날짜를 탭하세요.")
                helpRow("calendar", "월·연도 이동",
                        "상단 헤더의 < > 버튼으로 월과 연도를 변경합니다.")
                helpRow("circle.fill", "Today 이동",
                        "선택한 날짜가 오늘이 아닐 때 상단에 Today 버튼이 표시됩니다.")
                helpRow("magnifyingglass", "이벤트 검색",
                        "상단 🔍 버튼을 탭하면 제목·메모 기준으로 이벤트를 검색합니다.")
            }
            Section("이벤트 관리") {
                helpRow("plus.circle", "이벤트 추가",
                        "+ 버튼 탭, 히어로 영역 더블탭, 또는 롱프레스로 이벤트를 추가합니다.\n+ 버튼을 길게 누르면 1회만 다른 입력 방식으로 추가할 수 있습니다.")
                helpRow("pencil", "이벤트 편집·삭제",
                        "일정 목록에서 이벤트를 길게 누르면 편집·복사·삭제 메뉴가 표시됩니다.")
                helpRow("doc.on.doc", "이벤트 복사",
                        "'복사(내용포함/제외)'를 선택하면 목표 날짜를 지정해 복사합니다.")
            }
            Section("플래너 모드") {
                helpRow("book", "일기 모드",
                        "자유 텍스트로 하루를 기록합니다. 에디터 오픈~저장 시각이 자동으로 기록됩니다.")
                helpRow("checklist", "일정관리 모드",
                        "체크리스트로 할 일을 관리합니다. 기한 초과 항목은 빨간색으로 표시됩니다.")
                helpRow("square.grid.2x2", "개인이벤트 모드",
                        "복용·약속·고정 템플릿으로 빠르게 이벤트를 입력합니다.")
            }
        }
        .navigationTitle("도움말 센터")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func helpRow(_ icon: String, _ title: String, _ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon).font(.system(size: 14, weight: .semibold))
            Text(desc).font(.system(size: 13)).foregroundColor(.secondary).lineSpacing(2)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - FAQView

private struct FAQView: View {
    private let faqs: [(q: String, a: String)] = [
        ("Google 캘린더가 앱에 표시되지 않아요.",
         "기기 설정 → 캘린더 → 계정 추가에서 Google 계정을 추가하세요. 앱 설정(⚙) → 캘린더 연동에서 해당 캘린더를 확인합니다."),
        ("알림이 오지 않아요.",
         "기기 설정 → 알림 → Wise Calendar에서 알림을 허용하세요. 앱 설정(⚙) → 알림 토글도 ON이어야 합니다."),
        ("날씨가 표시되지 않아요.",
         "위치 권한이 필요합니다. 기기 설정 → 개인 정보 보호 → 위치 서비스에서 '앱 사용 중'으로 설정하세요."),
        ("플래너 모드를 바꾸고 싶어요.",
         "설정(⚙) → 사용자 테마 → 입력 방식에서 언제든 변경할 수 있습니다."),
        ("이벤트를 다른 날로 복사하고 싶어요.",
         "이벤트를 길게 눌러 '복사(내용포함)' 또는 '복사(내용제외)'를 선택하면 목표 날짜를 지정해 복사합니다."),
        ("앱 테마(다크/라이트)를 변경하고 싶어요.",
         "설정(⚙)에서 '설정' 제목 옆 아이콘을 탭하면 시스템·다크·라이트가 순환 전환됩니다."),
        ("이벤트 검색은 어떻게 하나요?",
         "메인 화면 상단의 🔍 버튼을 탭하면 검색 화면이 열립니다. 검색어를 입력하면 ±2년 범위 내 이벤트를 찾습니다."),
    ]

    var body: some View {
        List {
            ForEach(faqs, id: \.q) { faq in
                VStack(alignment: .leading, spacing: 6) {
                    Text("Q. \(faq.q)").font(.system(size: 14, weight: .semibold))
                    Text("A. \(faq.a)").font(.system(size: 13)).foregroundColor(.secondary).lineSpacing(2)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("자주 묻는 질문")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - TroubleshootingView

private struct TroubleshootingView: View {
    var body: some View {
        List {
            Section("이벤트") {
                issueRow("이벤트가 표시되지 않아요",
                         "기기 설정 → 개인 정보 보호 → 캘린더에서 Wise Calendar 접근을 허용해 주세요.")
                issueRow("추가한 이벤트가 목록에 보이지 않아요",
                         "다른 날로 이동 후 돌아오면 목록이 갱신됩니다. 반복 발생 시 이메일로 문의해 주세요.")
            }
            Section("날씨") {
                issueRow("날씨 아이콘 대신 이모지가 표시돼요",
                         "위치 권한 없음 또는 날씨 조회 실패 시 이모지로 대체됩니다. 위치 권한을 허용하면 아이콘이 표시됩니다.")
                issueRow("날씨 데이터가 오래됐어요",
                         "앱을 완전히 종료 후 재실행하면 날씨가 다시 조회됩니다.")
            }
            Section("알림") {
                issueRow("알림이 오지 않아요",
                         "기기 설정 → 알림 → Wise Calendar에서 허용 여부와 앱 설정(⚙) → 알림 토글을 확인하세요.")
                issueRow("알림 시간이 맞지 않아요",
                         "현재 모든 알림은 이벤트 당일 오전 9시에 발송됩니다.")
            }
            Section("캘린더 연동") {
                issueRow("Google 캘린더가 표시되지 않아요",
                         "기기 설정 → 캘린더 → 계정에서 Google 계정 추가 후 앱을 재실행하세요.")
            }
        }
        .navigationTitle("일반적인 문제")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func issueRow(_ title: String, _ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(desc).font(.system(size: 13)).foregroundColor(.secondary).lineSpacing(2)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - SyncGuideView

private struct SyncGuideView: View {
    var body: some View {
        List {
            Section("Google 캘린더 연동 단계") {
                stepRow(1, "iPhone 설정 → 캘린더 → 계정")
                stepRow(2, "'계정 추가' → Google 선택")
                stepRow(3, "Google 계정으로 로그인")
                stepRow(4, "'캘린더' 스위치 ON")
                stepRow(5, "Wise Calendar 앱 실행 → 이벤트 자동 표시")
            }
            Section("연동이 안 될 때") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("기기 설정 → 개인 정보 보호 → 캘린더에서 Wise Calendar의 '모든 이벤트 접근' 허용 여부를 확인하세요.")
                        .font(.system(size: 13)).foregroundColor(.secondary).lineSpacing(2)
                    Text("Google 계정을 삭제 후 다시 추가하면 동기화 문제가 해결되는 경우가 많습니다.")
                        .font(.system(size: 13)).foregroundColor(.secondary).lineSpacing(2)
                }
                .padding(.vertical, 2)
            }
            Section("iCloud 캘린더") {
                Text("iCloud 계정은 기기 로그인 시 자동으로 연동됩니다. 앱 설정(⚙) → 캘린더 연동에서 표시 여부를 선택할 수 있습니다.")
                    .font(.system(size: 13)).foregroundColor(.secondary).lineSpacing(2)
                    .padding(.vertical, 2)
            }
        }
        .navigationTitle("동기화 문제 해결")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stepRow(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Color.blue)
                .clipShape(Circle())
            Text(text).font(.system(size: 13)).lineSpacing(2)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - DebugLogView

private struct DebugLogView: View {
    private var debugInfo: String {
        let version = AppSettings.currentBundleVersion
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let device = UIDevice.current
        return """
        Wise Calendar Debug Info
        ========================
        앱 버전: \(version) (\(build))
        기기: \(device.model)
        iOS: \(device.systemVersion)
        언어/지역: \(Locale.current.identifier)
        날짜: \(ISO8601DateFormatter().string(from: Date()))
        """
    }

    var body: some View {
        List {
            Section("디버그 정보") {
                Text(debugInfo)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Section {
                ShareLink("디버그 정보 공유", item: debugInfo)
                Button("이메일로 보내기") {
                    let body = debugInfo.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let subject = "Wise Calendar 디버그 로그".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "mailto:support@wisecalendar.app?subject=\(subject)&body=\(body)") {
                        UIApplication.shared.open(url)
                    }
                }
                .foregroundColor(.primary)
            }
        }
        .navigationTitle("디버그 로그")
        .navigationBarTitleDisplayMode(.inline)
    }
}
