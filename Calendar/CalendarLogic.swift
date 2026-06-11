import Foundation

/// 캘린더 날짜 로직 (순수 함수 — 뷰 상태 비의존, 테스트 가능).
/// 그리드 헤더가 SUN-first(일요일 시작)로 고정이므로 모든 계산도 SUN-first 기준.
enum CalendarLogic {

    /// 이벤트 캐시 키 (yyyy-MM-dd).
    static func dateKey(from date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// 한 달의 6주(42칸) 그리드를 생성한다.
    /// - SUN-first 정렬: 선행 빈칸 = (그 달 1일의 요일 - 1), 일요일=0.
    /// - 앞/뒤는 전·다음 달 날짜로 채워 항상 42칸.
    /// - `hasEvent` 로 각 날짜의 이벤트 보유 여부 주입(기본 false).
    static func monthGrid(
        for date: Date,
        selectedDate: Date,
        today: Date,
        calendar: Calendar = .current,
        hasEvent: (Date) -> Bool = { _ in false },
        eventCount: (Date) -> Int = { _ in 0 }
    ) -> [DayInfo] {
        var result = [DayInfo]()
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let firstDayOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return []
        }
        let numDays = range.count

        // weekday: 1 = Sunday … 7 = Saturday → SUN-first 선행 빈칸 수
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let leading = firstWeekday - 1

        let startOfToday = calendar.startOfDay(for: today)
        let startOfSelected = calendar.startOfDay(for: selectedDate)

        func makeInfo(_ d: Date, isCurrentMonth: Bool) -> DayInfo {
            var info = DayInfo(day: calendar.component(.day, from: d), date: d, isCurrentMonth: isCurrentMonth)
            info.isToday = calendar.isDate(d, inSameDayAs: startOfToday)
            info.isSelected = calendar.isDate(d, inSameDayAs: startOfSelected)
            let cnt = eventCount(d)
            info.eventCount = cnt
            info.hasEvent = hasEvent(d) || cnt > 0
            return info
        }

        // 전월 선행일
        if leading > 0 {
            for i in 0..<leading {
                if let d = calendar.date(byAdding: .day, value: -leading + i, to: firstDayOfMonth) {
                    result.append(makeInfo(d, isCurrentMonth: false))
                }
            }
        }

        // 당월
        for day in 1...numDays {
            var dc = components
            dc.day = day
            if let d = calendar.date(from: dc) {
                result.append(makeInfo(d, isCurrentMonth: true))
            }
        }

        // 다음월 후행일 (42칸 채우기)
        let total = 42
        let remaining = total - result.count
        if remaining > 0, let last = result.last?.date {
            for i in 0..<remaining {
                if let d = calendar.date(byAdding: .day, value: i + 1, to: last) {
                    result.append(makeInfo(d, isCurrentMonth: false))
                }
            }
        }

        return result
    }
}
