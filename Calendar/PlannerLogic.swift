import Foundation

/// 투두 항목 (체크리스트 1줄).
struct TodoItem: Identifiable, Equatable {
    var id = UUID()
    var text: String
    var done: Bool

    init(id: UUID = UUID(), text: String, done: Bool = false) {
        self.id = id
        self.text = text
        self.done = done
    }
}

/// 플래너 모드/템플릿 순수 로직 — 뷰 비의존, 테스트 가능.
enum PlannerLogic {

    // MARK: day-of-year

    /// 그 해 일련일(1 = 1월 1일).
    static func dayOfYear(from date: Date, calendar: Calendar = .current) -> Int {
        calendar.ordinality(of: .day, in: .year, for: date) ?? 1
    }

    /// 특정 연도의 day-of-year 에 해당하는 날짜. 범위 밖이면 nil.
    static func date(dayOfYear day: Int, year: Int, calendar: Calendar = .current) -> Date? {
        guard day >= 1 else { return nil }
        guard let jan1 = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let range = calendar.range(of: .day, in: .year, for: jan1),
              day <= range.count else { return nil }
        return calendar.date(byAdding: .day, value: day - 1, to: jan1)
    }

    // MARK: 고정 이벤트 표기 [#ddd] 제목

    /// `[#162] 알레르기 약 복용(-/-)` 형태 생성.
    static func fixedTitle(dayOfYear day: Int, title: String) -> String {
        "[#\(day)] \(title)"
    }

    /// `[#ddd] 제목` 파싱 → (day, 제목). 형식 불일치면 nil.
    static func parseFixedTitle(_ raw: String) -> (dayOfYear: Int, title: String)? {
        guard raw.hasPrefix("[#"),
              let close = raw.firstIndex(of: "]") else { return nil }
        let numStart = raw.index(raw.startIndex, offsetBy: 2)
        let numStr = raw[numStart..<close]
        guard let day = Int(numStr) else { return nil }
        let after = raw.index(after: close)
        let title = raw[after...].trimmingCharacters(in: .whitespaces)
        return (day, title)
    }

    // MARK: 투두 인코딩 (EKEvent.notes)

    /// 체크리스트 → notes 문자열. `- [ ] 항목` / `- [x] 항목`.
    static func encodeTodos(_ items: [TodoItem]) -> String {
        items.map { "- [\($0.done ? "x" : " ")] \($0.text)" }.joined(separator: "\n")
    }

    /// notes 문자열 → 체크리스트. 체크박스 라인만 파싱, 나머지는 무시.
    static func decodeTodos(_ notes: String) -> [TodoItem] {
        notes.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
            let s = line.trimmingCharacters(in: .whitespaces)
            guard s.hasPrefix("- [") , s.count >= 5 else { return nil }
            let markIndex = s.index(s.startIndex, offsetBy: 3)
            let mark = s[markIndex]
            let done = (mark == "x" || mark == "X")
            // "- [x] " 이후가 본문 (닫는 ] 다음 공백 포함 6글자)
            guard let bracketClose = s.firstIndex(of: "]") else { return nil }
            let textStart = s.index(after: bracketClose)
            let text = s[textStart...].trimmingCharacters(in: .whitespaces)
            return TodoItem(text: text, done: done)
        }
    }

    // MARK: 타이틀 날짜 패턴

    private static let datePatterns = [
        "yyyy-mm-dd", "yyyy/mm/dd", "yy-mm-dd", "yyyy.mm.dd", "dd-mm-yyyy", "d###"
    ]

    /// 타이틀의 날짜 패턴(yyyy-mm-dd, d### 등)을 실제 날짜 문자열로 치환한다.
    /// yyyy 계열 먼저 처리해 yy-mm-dd 와 충돌 방지.
    static func substituteTitlePatterns(_ title: String, date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else { return title }
        let yyyy = String(format: "%04d", year)
        let yy   = String(format: "%02d", year % 100)
        let mm   = String(format: "%02d", month)
        let dd   = String(format: "%02d", day)
        let doy  = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let ddd  = String(format: "%03d", doy)
        return title
            .replacingOccurrences(of: "yyyy-mm-dd", with: "\(yyyy)-\(mm)-\(dd)")
            .replacingOccurrences(of: "yyyy/mm/dd", with: "\(yyyy)/\(mm)/\(dd)")
            .replacingOccurrences(of: "yy-mm-dd",   with: "\(yy)-\(mm)-\(dd)")
            .replacingOccurrences(of: "yyyy.mm.dd", with: "\(yyyy).\(mm).\(dd)")
            .replacingOccurrences(of: "dd-mm-yyyy", with: "\(dd)-\(mm)-\(yyyy)")
            .replacingOccurrences(of: "d###",        with: ddd)
    }

    /// 타이틀에 지원되는 날짜 패턴이 포함되어 있는지 반환.
    static func hasTitleDatePattern(_ title: String) -> Bool {
        datePatterns.contains { title.contains($0) }
    }
}
