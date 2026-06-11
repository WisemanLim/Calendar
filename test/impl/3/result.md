# 시험 결과 — impl/3 (설정·플래너·템플릿·온보딩)

- 일자: 2026-06-11
- 판정: **전체 PASS**
- 빌드 태스크: bzj4p1xk4 (exit 0)

## 결과 요약

| 항목 | 결과 |
|------|------|
| 컴파일 | ✅ 에러 0 |
| 빌드 | ✅ BUILD SUCCEEDED |
| 단위 테스트 | ✅ 24/24 |

## 테스트 세부

| 테스트 클래스 | 테스트 수 | 판정 |
|-------------|----------|------|
| CalendarLogicTests | 9 | ✅ |
| PlannerLogicTests | 15 | ✅ |
| **합계** | **24** | **PASS** |

### PlannerLogicTests 항목

| # | 함수 | 내용 | 결과 |
|---|------|------|------|
| 1 | dayOfYear | Jan 1 = 1 | ✅ |
| 2 | dayOfYear | 2025-06-11 = 162 | ✅ |
| 3 | dayOfYear | roundtrip (date → doy → date) | ✅ |
| 4 | date(dayOfYear:year:) | 윤년 366 존재, 평년 nil | ✅ |
| 5 | date(dayOfYear:year:) | 0 → nil (범위 밖) | ✅ |
| 6 | fixedTitle | "[#162] 알레르기 약 복용(-/-)" 포맷 | ✅ |
| 7 | parseFixedTitle | 파싱 doy=162, title 분리 | ✅ |
| 8 | parseFixedTitle | 잘못된 입력 → nil | ✅ |
| 9 | fixedTitle | roundtrip (format → parse) | ✅ |
| 10 | encodeTodos | "- [ ] ..\n- [x] .." 형식 | ✅ |
| 11 | decodeTodos | 체크리스트 파싱 | ✅ |
| 12 | encodeTodos | roundtrip (encode → decode) | ✅ |
| 13 | decodeTodos | 비-체크리스트 라인 무시 | ✅ |
| 14 | EventTemplate | fixedDisplayTitle 포맷 | ✅ |
| 15 | EventTemplate | Codable roundtrip (JSON 직렬화) | ✅ |

## 요구사항 반영

| # | 요구사항 | 구현 | 결과 |
|---|----------|------|------|
| 1 | AppSettings UserDefaults 영속 | plannerMode/notifications/onboarding/enabledCalendarIDs, `didSet` 즉시 저장 | ✅ |
| 2 | PlannerMode 3종 | diary/todo/personalEvent, rawValue Codable, title/detail/systemImage | ✅ |
| 3 | EventTemplate + TemplateStore | Codable, seed 7건, UserDefaults JSON 영속 | ✅ |
| 4 | [#ddd] 고정 패턴 | dayOfYear 기반 연간 고정 이벤트, fixedTitle/parseFixedTitle | ✅ |
| 5 | NotificationManager | UNUserNotificationCenter, 9am 알림 예약 | ✅ |
| 6 | EventEditorView 모드별 | diary=자유 텍스트, todo=체크리스트, personalEvent=템플릿 피커 | ✅ |
| 7 | SettingsView 3-섹션 | (1)캘린더 연동 (2)플래너 모드 (3)알림 | ✅ |
| 8 | OnboardingView 4단계 | 가이드→모드선택→Google연동→알림, DEBUG 매회 | ✅ |
| 9 | RootView 온보딩 분기 | shouldShowOnboarding → .fullScreenCover | ✅ |
| 10 | CalendarView 기어/+ 버튼 | showSettings(sheet) + showEditor(모드별 sheet/fullScreen) | ✅ |

## 변경/신규 파일

| 파일 | 구분 | 내용 |
|------|------|------|
| `Calendar/PlannerMode.swift` | 신규 | diary/todo/personalEvent enum |
| `Calendar/AppSettings.swift` | 신규 | UserDefaults 영속 설정 |
| `Calendar/EventTemplate.swift` | 신규 | TemplateCategory, EventTemplate, TemplateStore |
| `Calendar/PlannerLogic.swift` | 신규 | dayOfYear, fixedTitle, encodeTodos 등 순수 함수 |
| `Calendar/NotificationManager.swift` | 신규 | UNUserNotificationCenter 래퍼 |
| `Calendar/EventEditorView.swift` | 신규 | 모드별 이벤트 입력 UI |
| `Calendar/SettingsView.swift` | 신규 | 앱 설정 화면 |
| `Calendar/OnboardingView.swift` | 신규 | 4단계 온보딩 |
| `Calendar/RootView.swift` | 신규 | 온보딩 분기 루트 |
| `Calendar/CalendarView.swift` | 수정 | settings/templateStore 주입, 기어/+ 버튼, sheet/fullScreenCover |
| `Calendar/EventStoreManager.swift` | 수정 | addEvent() EKEvent 쓰기, invalidateCache, calendarSources() |
| `Calendar/SceneDelegate.swift` | 수정 | RootView 로 교체 |
| `CalendarTests/PlannerLogicTests.swift` | 신규 | 15개 단위 테스트 |

## 재현

```bash
xcrun simctl shutdown all
xcodebuild test \
  -project Calendar.xcodeproj \
  -scheme Calendar \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
