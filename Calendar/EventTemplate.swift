import Foundation
import Combine

/// 템플릿 분류.
enum TemplateCategory: String, Codable, CaseIterable, Identifiable {
    case medication  // 복용: 아침/점심/저녁
    case appointment // 약속: 연인/친구/회식 등
    case fixed       // 고정/반복: 연간 동일 day-of-year 패턴

    var id: String { rawValue }
    var title: String {
        switch self {
        case .medication: return "복용"
        case .appointment: return "약속"
        case .fixed: return "고정"
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
    /// 이벤트 기본 시작 시(0–23). medication: 7/12/18, appointment: 9, fixed: 9.
    var defaultStartHour: Int
    /// 이벤트 기본 종료 시. appointment는 startHour+1h 등. medication/fixed는 0(시작=종료).
    var defaultDurationMinutes: Int

    init(id: UUID = UUID(), name: String, category: TemplateCategory,
         titleFormat: String, dayOfYear: Int? = nil,
         defaultStartHour: Int = 9, defaultDurationMinutes: Int = 60) {
        self.id = id
        self.name = name
        self.category = category
        self.titleFormat = titleFormat
        self.dayOfYear = dayOfYear
        self.defaultStartHour = defaultStartHour
        self.defaultDurationMinutes = defaultDurationMinutes
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
    private let key = "templates.v1"

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
    static let seed: [EventTemplate] = [
        EventTemplate(name: "아침 복용", category: .medication, titleFormat: "아침 약 복용", defaultStartHour: 7, defaultDurationMinutes: 0),
        EventTemplate(name: "점심 복용", category: .medication, titleFormat: "점심 약 복용", defaultStartHour: 12, defaultDurationMinutes: 0),
        EventTemplate(name: "저녁 복용", category: .medication, titleFormat: "저녁 약 복용", defaultStartHour: 18, defaultDurationMinutes: 0),
        EventTemplate(name: "연인", category: .appointment, titleFormat: "연인과 약속", defaultStartHour: 19, defaultDurationMinutes: 120),
        EventTemplate(name: "친구", category: .appointment, titleFormat: "친구와 약속", defaultStartHour: 14, defaultDurationMinutes: 120),
        EventTemplate(name: "회식", category: .appointment, titleFormat: "회식", defaultStartHour: 18, defaultDurationMinutes: 180),
        EventTemplate(name: "알레르기 약(연간)", category: .fixed, titleFormat: "알레르기 약 복용(-/-)", dayOfYear: 162, defaultStartHour: 9, defaultDurationMinutes: 0)
    ]
}
