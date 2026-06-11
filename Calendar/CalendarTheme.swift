import SwiftUI

/// 캘린더 색상 테마. 차후 다크/브랜드 테마 교체를 위해 색을 한 곳에 모은다.
/// 주입 방식: `CalendarView(theme:)` 기본값 `.default`.
struct CalendarTheme {
    /// 선택일·오늘·이벤트 점 등 강조 색.
    var accent: Color
    /// 월 이름 + 월 이동(<,>) 버튼 색.
    var month: Color
    /// 연도 숫자 + 연 이동(<,>) 버튼 색. (요구사항: 둘은 항상 동일 색)
    var year: Color
    /// Today 버튼 틴트.
    var todayTint: Color
    /// 이동 버튼 배경.
    var navBackground: Color
    /// 주말 색.
    var sunday: Color
    var saturday: Color

    static let `default` = CalendarTheme(
        accent: .blue,
        month: .primary,
        year: .gray,
        todayTint: .blue,
        navBackground: Color.gray.opacity(0.12),
        sunday: .red,
        saturday: .blue
    )
}
