import Foundation

/// 사용자 "테마"(입력 방식). 색 테마(`CalendarTheme`)와 별개.
/// 이벤트 추가 UX 를 결정한다.
enum PlannerMode: String, CaseIterable, Codable, Identifiable {
    case diary          // 일기: 전체화면 자유 입력
    case todo           // 일정관리: 체크리스트 + 완료 토글
    case personalEvent  // 개인 이벤트: 템플릿 선택 후 입력

    var id: String { rawValue }

    var title: String {
        switch self {
        case .diary: return "일기"
        case .todo: return "업무 이벤트"
        case .personalEvent: return "개인 이벤트"
        }
    }

    var detail: String {
        switch self {
        case .diary: return "이벤트 추가 시 일기장처럼 전체 화면으로 자유롭게 작성합니다."
        case .todo: return "할 일·회의 등 업무 이벤트 템플릿을 선택해 빠르게 입력합니다."
        case .personalEvent: return "복용·약속 등 개인 이벤트 템플릿을 선택해 빠르게 입력합니다."
        }
    }

    var systemImage: String {
        switch self {
        case .diary: return "book.closed"
        case .todo: return "briefcase"
        case .personalEvent: return "square.grid.2x2"
        }
    }
}
