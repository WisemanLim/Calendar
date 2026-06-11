import XCTest
@testable import Calendar

final class CalendarLogicTests: XCTestCase {

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: dateKey

    func testDateKeyFormat() {
        let key = CalendarLogic.dateKey(from: date(2025, 6, 9), calendar: cal)
        XCTAssertEqual(key, "2025-06-09")
    }

    func testDateKeyZeroPads() {
        XCTAssertEqual(CalendarLogic.dateKey(from: date(2025, 1, 5), calendar: cal), "2025-01-05")
    }

    // MARK: monthGrid — 칸 수

    func testGridAlwaysHas42Cells() {
        for (y, m) in [(2025, 2), (2025, 6), (2024, 2), (2025, 12)] {
            let grid = CalendarLogic.monthGrid(for: date(y, m, 1),
                                               selectedDate: date(y, m, 1),
                                               today: date(y, m, 1),
                                               calendar: cal)
            XCTAssertEqual(grid.count, 42, "\(y)-\(m) 그리드는 42칸이어야 함")
        }
    }

    // MARK: SUN-first 정렬

    func testSundayStartNoLeading() {
        // 2025-06-01 은 일요일 → 선행 빈칸 0, 첫 칸이 1일
        let grid = CalendarLogic.monthGrid(for: date(2025, 6, 1),
                                           selectedDate: date(2025, 6, 1),
                                           today: date(2025, 6, 1),
                                           calendar: cal)
        XCTAssertTrue(grid[0].isCurrentMonth)
        XCTAssertEqual(grid[0].day, 1)
    }

    func testSaturdayStartHasSixLeading() {
        // 2025-02-01 은 토요일(weekday 7) → 선행 빈칸 6, 7번째 칸이 1일
        let grid = CalendarLogic.monthGrid(for: date(2025, 2, 1),
                                           selectedDate: date(2025, 2, 1),
                                           today: date(2025, 2, 1),
                                           calendar: cal)
        for i in 0..<6 { XCTAssertFalse(grid[i].isCurrentMonth, "앞 6칸은 전월") }
        XCTAssertTrue(grid[6].isCurrentMonth)
        XCTAssertEqual(grid[6].day, 1)
    }

    func testCurrentMonthDayCount() {
        // 2025-02 (28일) 당월 칸 수 = 28
        let grid = CalendarLogic.monthGrid(for: date(2025, 2, 1),
                                           selectedDate: date(2025, 2, 1),
                                           today: date(2025, 2, 1),
                                           calendar: cal)
        XCTAssertEqual(grid.filter { $0.isCurrentMonth }.count, 28)
    }

    // MARK: today / selected 플래그

    func testExactlyOneToday() {
        let grid = CalendarLogic.monthGrid(for: date(2025, 6, 1),
                                           selectedDate: date(2025, 6, 15),
                                           today: date(2025, 6, 9),
                                           calendar: cal)
        XCTAssertEqual(grid.filter { $0.isToday }.count, 1)
        XCTAssertEqual(grid.first { $0.isToday }?.day, 9)
    }

    func testSelectedFlag() {
        let grid = CalendarLogic.monthGrid(for: date(2025, 6, 1),
                                           selectedDate: date(2025, 6, 15),
                                           today: date(2025, 6, 9),
                                           calendar: cal)
        XCTAssertEqual(grid.filter { $0.isSelected }.count, 1)
        XCTAssertEqual(grid.first { $0.isSelected }?.day, 15)
    }

    // MARK: hasEvent 주입

    func testHasEventInjection() {
        let target = date(2025, 6, 10)
        let grid = CalendarLogic.monthGrid(for: date(2025, 6, 1),
                                           selectedDate: date(2025, 6, 1),
                                           today: date(2025, 6, 1),
                                           calendar: cal,
                                           hasEvent: { cal.isDate($0, inSameDayAs: target) })
        XCTAssertEqual(grid.filter { $0.hasEvent }.count, 1)
        XCTAssertEqual(grid.first { $0.hasEvent }?.day, 10)
    }
}
