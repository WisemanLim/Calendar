import Foundation
import Combine

/// 템플릿 분류.
enum TemplateCategory: String, Codable, CaseIterable, Identifiable {
    case workEvent   // 업무 이벤트: 할 일, 회식, 회의, 세미나/컨퍼런스
    case medication  // 복용: 알레르기 약복용
    case appointment // 약속: 연인/친구 등
    case fixed       // 고정/반복: 연간 고정 + 정기 복용

    var id: String { rawValue }
    var title: String {
        switch self {
        case .workEvent:   return "업무 이벤트"
        case .medication:  return "복용"
        case .appointment: return "약속"
        case .fixed:       return "고정/반복"
        }
    }
}

/// 개인 이벤트 입력 템플릿.
/// - `titleFormat`: 제목 프리필.
/// - `dayOfYear`: fixed 전용. 그 해 일련일(1–366). 매년 같은 날 재현.
struct EventTemplate: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var category: TemplateCategory
    var titleFormat: String
    var dayOfYear: Int?
    var defaultStartHour: Int
    var defaultDurationMinutes: Int
    /// 체크리스트(할 일) 스타일 저장 여부 — 기한+완료 토글, 시간 입력 없음.
    var isTodo: Bool

    init(id: UUID = UUID(), name: String, category: TemplateCategory,
         titleFormat: String, dayOfYear: Int? = nil,
         defaultStartHour: Int = 9, defaultDurationMinutes: Int = 60,
         isTodo: Bool = false) {
        self.id = id
        self.name = name
        self.category = category
        self.titleFormat = titleFormat
        self.dayOfYear = dayOfYear
        self.defaultStartHour = defaultStartHour
        self.defaultDurationMinutes = defaultDurationMinutes
        self.isTodo = isTodo
    }

    // isTodo 키 누락된 이전 데이터 호환 디코딩
    enum CodingKeys: String, CodingKey {
        case id, name, category, titleFormat, dayOfYear, defaultStartHour, defaultDurationMinutes, isTodo
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decode(TemplateCategory.self, forKey: .category)
        titleFormat = try c.decode(String.self, forKey: .titleFormat)
        dayOfYear = try c.decodeIfPresent(Int.self, forKey: .dayOfYear)
        defaultStartHour = try c.decode(Int.self, forKey: .defaultStartHour)
        defaultDurationMinutes = try c.decode(Int.self, forKey: .defaultDurationMinutes)
        isTodo = try c.decodeIfPresent(Bool.self, forKey: .isTodo) ?? false
    }

    /// 고정 이벤트 표기 `[#ddd] 제목(-/-)` 생성 (fixed + dayOfYear 있을 때).
    var fixedDisplayTitle: String? {
        guard category == .fixed, let d = dayOfYear else { return nil }
        return PlannerLogic.fixedTitle(dayOfYear: d, title: titleFormat)
    }
}

/// 템플릿 저장소 — UserDefaults(JSON) 영속. 최초 기본 시드 제공.
@MainActor
final class TemplateStore: ObservableObject {
    static let shared = TemplateStore()

    private let defaults: UserDefaults
    private let key = "templates.v3"

    @Published private(set) var templates: [EventTemplate] {
        didSet { persist() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([EventTemplate].self, from: data) {
            self.templates = decoded
        } else {
            self.templates = TemplateStore.seed
        }
    }

    func add(_ template: EventTemplate) { templates.append(template) }
    func remove(_ template: EventTemplate) { templates.removeAll { $0.id == template.id } }
    func update(_ template: EventTemplate) {
        if let i = templates.firstIndex(where: { $0.id == template.id }) { templates[i] = template }
    }
    func templates(in category: TemplateCategory) -> [EventTemplate] {
        templates.filter { $0.category == category }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(templates) {
            defaults.set(data, forKey: key)
        }
    }

    /// 기본 시드 템플릿.
    /// titleFormat 에 날짜 패턴(yyyy-mm-dd, d### 등)이 포함되면 저장 시 실제 날짜로 치환된다.
    /// 치환 패턴 없는 fixed 항목은 저장 시 자동으로 yearly RRULE이 적용된다.
    static let seed: [EventTemplate] = [
        // 업무 이벤트 (PlannerMode.todo 전용)
        EventTemplate(name: "할 일", category: .workEvent, titleFormat: "할 일", defaultStartHour: 9, defaultDurationMinutes: 60, isTodo: true),
        EventTemplate(name: "회의", category: .workEvent, titleFormat: "회의", defaultStartHour: 10, defaultDurationMinutes: 60),
        EventTemplate(name: "세미나/컨퍼런스", category: .workEvent, titleFormat: "세미나/컨퍼런스", defaultStartHour: 9, defaultDurationMinutes: 480),
        EventTemplate(name: "회식", category: .workEvent, titleFormat: "회식", defaultStartHour: 18, defaultDurationMinutes: 180),
        // 복용 — 날짜 패턴 없음 → 저장 시 auto yearly RRULE
        EventTemplate(name: "아침 약 복용", category: .medication, titleFormat: "아침 약 복용", defaultStartHour: 7, defaultDurationMinutes: 0),
        EventTemplate(name: "점심 약 복용", category: .medication, titleFormat: "점심 약 복용", defaultStartHour: 12, defaultDurationMinutes: 0),
        EventTemplate(name: "저녁 약 복용", category: .medication, titleFormat: "저녁 약 복용", defaultStartHour: 18, defaultDurationMinutes: 0),
        EventTemplate(name: "임시/긴급 복용", category: .medication, titleFormat: "임시/긴급 복용", defaultStartHour: 9, defaultDurationMinutes: 0),
        // 약속
        EventTemplate(name: "연인과 약속", category: .appointment, titleFormat: "연인과 약속", defaultStartHour: 19, defaultDurationMinutes: 120),
        EventTemplate(name: "친구와 약속", category: .appointment, titleFormat: "친구와 약속", defaultStartHour: 14, defaultDurationMinutes: 120),
        EventTemplate(name: "동호회/이벤트", category: .appointment, titleFormat: "동호회/이벤트", defaultStartHour: 10, defaultDurationMinutes: 120),
        EventTemplate(name: "비밀 약속", category: .appointment, titleFormat: "[비밀] 약속", defaultStartHour: 19, defaultDurationMinutes: 120),
        // 고정/반복 — 날짜 패턴 → RRULE 없음, 패턴 없음 → auto yearly RRULE
        EventTemplate(name: "알레르기 약 복용", category: .fixed, titleFormat: "알레르기 약 복용 (d###)", defaultStartHour: 9, defaultDurationMinutes: 0),
        EventTemplate(name: "약 복용 날짜 기록", category: .fixed, titleFormat: "약 복용 yyyy-mm-dd", defaultStartHour: 9, defaultDurationMinutes: 0),
        EventTemplate(name: "정기작업", category: .fixed, titleFormat: "[정기작업] (d###) yyyy-mm-dd", defaultStartHour: 9, defaultDurationMinutes: 0),
    ]
}
