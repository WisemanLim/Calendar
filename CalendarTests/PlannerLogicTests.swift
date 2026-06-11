import XCTest
@testable import Calendar

final class PlannerLogicTests: XCTestCase {

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: day-of-year

    func testDayOfYearJan1() {
        XCTAssertEqual(PlannerLogic.dayOfYear(from: date(2025, 1, 1), calendar: cal), 1)
    }

    func testDayOfYear162In2025() {
        // 2025 평년: 162번째 날 = 6월 11일
        XCTAssertEqual(PlannerLogic.dayOfYear(from: date(2025, 6, 11), calendar: cal), 162)
    }

    func testDayOfYearRoundTrip() {
        let d = PlannerLogic.dayOfYear(from: date(2025, 6, 11), calendar: cal)
        let back = PlannerLogic.date(dayOfYear: d, year: 2025, calendar: cal)
        XCTAssertEqual(back, date(2025, 6, 11))
    }

    func testDateForDayOfYearLeap() {
        // 2024 윤년: 366일 존재
        XCTAssertNotNil(PlannerLogic.date(dayOfYear: 366, year: 2024, calendar: cal))
        // 2025 평년: 366 없음
        XCTAssertNil(PlannerLogic.date(dayOfYear: 366, year: 2025, calendar: cal))
    }

    func testDateForDayOfYearOutOfRange() {
        XCTAssertNil(PlannerLogic.date(dayOfYear: 0, year: 2025, calendar: cal))
    }

    // MARK: 고정 이벤트 표기

    func testFixedTitleFormat() {
        XCTAssertEqual(
            PlannerLogic.fixedTitle(dayOfYear: 162, title: "알레르기 약 복용(-/-)"),
            "[#162] 알레르기 약 복용(-/-)"
        )
    }

    func testParseFixedTitle() {
        let parsed = PlannerLogic.parseFixedTitle("[#162] 알레르기 약 복용(-/-)")
        XCTAssertEqual(parsed?.dayOfYear, 162)
        XCTAssertEqual(parsed?.title, "알레르기 약 복용(-/-)")
    }

    func testParseFixedTitleInvalid() {
        XCTAssertNil(PlannerLogic.parseFixedTitle("일반 제목"))
        XCTAssertNil(PlannerLogic.parseFixedTitle("[#abc] x"))
    }

    func testFixedTitleRoundTrip() {
        let t = PlannerLogic.fixedTitle(dayOfYear: 200, title: "운동")
        let p = PlannerLogic.parseFixedTitle(t)
        XCTAssertEqual(p?.dayOfYear, 200)
        XCTAssertEqual(p?.title, "운동")
    }

    // MARK: 투두 인코딩

    func testEncodeTodos() {
        let items = [TodoItem(text: "우유 사기", done: false),
                     TodoItem(text: "운동", done: true)]
        XCTAssertEqual(PlannerLogic.encodeTodos(items), "- [ ] 우유 사기\n- [x] 운동")
    }

    func testDecodeTodos() {
        let items = PlannerLogic.decodeTodos("- [ ] 우유 사기\n- [x] 운동")
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].text, "우유 사기")
        XCTAssertFalse(items[0].done)
        XCTAssertEqual(items[1].text, "운동")
        XCTAssertTrue(items[1].done)
    }

    func testTodoRoundTrip() {
        let items = [TodoItem(text: "A", done: true), TodoItem(text: "B", done: false)]
        let decoded = PlannerLogic.decodeTodos(PlannerLogic.encodeTodos(items))
        XCTAssertEqual(decoded.map(\.text), ["A", "B"])
        XCTAssertEqual(decoded.map(\.done), [true, false])
    }

    func testDecodeIgnoresNonChecklistLines() {
        let items = PlannerLogic.decodeTodos("자유 메모\n- [x] 할일")
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].text, "할일")
    }

    // MARK: 템플릿

    func testTemplateFixedDisplayTitle() {
        let t = EventTemplate(name: "알레르기", category: .fixed,
                              titleFormat: "알레르기 약 복용(-/-)", dayOfYear: 162)
        XCTAssertEqual(t.fixedDisplayTitle, "[#162] 알레르기 약 복용(-/-)")
    }

    func testTemplateNonFixedNoDisplayTitle() {
        let t = EventTemplate(name: "친구", category: .appointment, titleFormat: "친구와 약속")
        XCTAssertNil(t.fixedDisplayTitle)
    }

    func testTemplateCodableRoundTrip() throws {
        let t = EventTemplate(name: "아침 복용", category: .medication, titleFormat: "아침 약 복용")
        let data = try JSONEncoder().encode([t])
        let decoded = try JSONDecoder().decode([EventTemplate].self, from: data)
        XCTAssertEqual(decoded.first, t)
    }

    // MARK: 타이틀 날짜 패턴

    func testSubstituteTitlePatternsYMD() {
        // 2026-03-08: yyyy-mm-dd
        let result = PlannerLogic.substituteTitlePatterns("작업 yyyy-mm-dd", date: date(2026, 3, 8), calendar: cal)
        XCTAssertEqual(result, "작업 2026-03-08")
    }

    func testSubstituteTitlePatternsDayOfYear() {
        // 2026-03-08: Jan(31)+Feb(28)+8 = 67 → "067"
        let result = PlannerLogic.substituteTitlePatterns("d###", date: date(2026, 3, 8), calendar: cal)
        XCTAssertEqual(result, "067")
    }

    func testSubstituteTitlePatternsCombined() {
        let result = PlannerLogic.substituteTitlePatterns("[정기] (d###) yyyy-mm-dd", date: date(2026, 3, 8), calendar: cal)
        XCTAssertEqual(result, "[정기] (067) 2026-03-08")
    }

    func testSubstituteTitlePatternsSlashAndDot() {
        let d = date(2026, 1, 5)
        XCTAssertEqual(PlannerLogic.substituteTitlePatterns("yyyy/mm/dd", date: d, calendar: cal), "2026/01/05")
        XCTAssertEqual(PlannerLogic.substituteTitlePatterns("yyyy.mm.dd", date: d, calendar: cal), "2026.01.05")
        XCTAssertEqual(PlannerLogic.substituteTitlePatterns("dd-mm-yyyy", date: d, calendar: cal), "05-01-2026")
        XCTAssertEqual(PlannerLogic.substituteTitlePatterns("yy-mm-dd",   date: d, calendar: cal), "26-01-05")
    }

    func testHasTitleDatePattern() {
        XCTAssertTrue(PlannerLogic.hasTitleDatePattern("작업 yyyy-mm-dd"))
        XCTAssertTrue(PlannerLogic.hasTitleDatePattern("d### 기록"))
        XCTAssertTrue(PlannerLogic.hasTitleDatePattern("[정기] dd-mm-yyyy"))
        XCTAssertFalse(PlannerLogic.hasTitleDatePattern("알레르기 약 복용"))
        XCTAssertFalse(PlannerLogic.hasTitleDatePattern("[#162] 알레르기"))
    }
}
