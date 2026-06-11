# 시험 시나리오 — impl/3 (설정·플래너·템플릿·온보딩)

- 일자: 2026-06-11
- 대상 빌드: bzj4p1xk4
- 프로파일: ios-swiftui

## 범위

PRD §3.2 신규 기능 전체:
- AppSettings 영속 (plannerMode / notificationsEnabled / onboardingCompleted / enabledCalendarIDs)
- PlannerMode (diary / todo / personalEvent)
- EventTemplate + TemplateStore (seed 7건, [#ddd] 고정 패턴)
- PlannerLogic 순수 함수 (dayOfYear, date(dayOfYear:year:), fixedTitle, parseFixedTitle, encodeTodos, decodeTodos)
- NotificationManager (UNUserNotificationCenter 권한 요청, 9am 알림 예약)
- EventEditorView (모드별 입력 UI)
- SettingsView (연동·테마·알림 3-섹션)
- OnboardingView (4-단계 TabView, DEBUG=매회)
- RootView (온보딩 분기 → CalendarView)

## 시험 항목

| # | 분류 | 시나리오 | 판정 기준 |
|---|------|----------|-----------|
| 1 | 컴파일 | `xcodebuild build` 에러 0 | BUILD SUCCEEDED |
| 2 | 단위 — CalendarLogicTests | 9개 테스트 전체 통과 | 9/9 |
| 3 | 단위 — PlannerLogicTests.dayOfYear | Jan 1 = 1, 2025-06-11 = 162, 윤년 366 존재/평년 nil | 5/5 |
| 4 | 단위 — PlannerLogicTests.fixedTitle | format·parse·roundtrip·invalid | 4/4 |
| 5 | 단위 — PlannerLogicTests.encodeTodos | encode·decode·roundtrip·비체크리스트 무시 | 4/4 |
| 6 | 단위 — PlannerLogicTests.template | fixedDisplayTitle·비고정 빈값·Codable roundtrip | 3/3 |
| 7 | 빌드+시험 합산 | xcodebuild test 전체 | 24/24 |

## 실행 명령

```bash
xcrun simctl shutdown all
xcodebuild test \
  -project Calendar.xcodeproj \
  -scheme Calendar \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  2>&1 | grep -E "error:|BUILD FAILED|BUILD SUCCEEDED|TEST SUCCEEDED|TEST FAILED|Executed [0-9]+ test|\.swift:[0-9]+:[0-9]+: error"
```
