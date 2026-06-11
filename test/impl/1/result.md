# 시험 결과 — impl/1

- 일자: 2026-06-11
- 판정: **전체 PASS**

## 결과 요약

| ID | 시나리오 | 결과 | 비고 |
|----|----------|------|------|
| S1 | 앱 빌드 회귀 | ✅ PASS | BUILD SUCCEEDED, 소스 경고/에러 0 (AppIntents 무해 경고만) |
| S2 | 메모 중복 렌더 수정 | ✅ PASS | nested HStack 제거, 각 일정 1회 렌더 |
| S3 | 그리드 로직 단위테스트 | ✅ PASS | 9/9 케이스 통과 |
| S4 | 테스트 타깃 동작 | ✅ PASS | TEST SUCCEEDED |

## 단위 테스트 상세 (CalendarLogicTests, 9/9)

| 케이스 | 결과 |
|--------|------|
| testDateKeyFormat | ✅ |
| testDateKeyZeroPads | ✅ |
| testGridAlwaysHas42Cells | ✅ |
| testSundayStartNoLeading | ✅ |
| testSaturdayStartHasSixLeading | ✅ |
| testCurrentMonthDayCount | ✅ |
| testExactlyOneToday | ✅ |
| testSelectedFlag | ✅ |
| testHasEventInjection | ✅ |

## 변경 사항

**버그 수정**
- `CalendarView.swift` SCHEDULE 리스트 nested HStack 제거 — 일정 중복 표시 해소.

**리팩터 (테스트 가능화)**
- 신규 `Calendar/CalendarLogic.swift` — 순수 함수 `monthGrid` / `dateKey` 추출.
- `MonthView.generateDaysInMonth` → `CalendarLogic.monthGrid` 위임.
- `EventStoreManager.dateKey` → `CalendarLogic.dateKey` 위임.
- CalendarView 데드코드 제거: `currentMonthDays`, `monthYearString`,
  `generateDaysInMonth`, `isSameDay`, `days`(한글 요일 배열).

**동작 변경 (의도된 수정)**
- 월 그리드 leading(선행 빈칸) 계산을 SUN-first 헤더에 정합하도록 교정.
  기존 `(firstWeekday-1+6)%7` = 월요일 기준 → 헤더(SUN-first)와 불일치(요일 1칸 밀림).
  신규 `firstWeekday-1` = 일요일 기준. 테스트 S3로 정렬 검증.

**인프라**
- `Calendar.xcodeproj` 에 `CalendarTests` 단위 테스트 타깃 신설
  (synchronized group, TEST_HOST=Calendar.app, BUNDLE_LOADER).
- `CalendarTests/CalendarLogicTests.swift` 9 케이스.

## 잔여 이슈 (미수정, 후속 권장)

1. **MemoListView 중복** — 선택일 SCHEDULE 상단 `MemoListView(prefix(2))` + 하단 전체 ForEach 가
   앞 2개 일정을 중복 표시. 설계 의도 모호 → 확정 후 정리.
2. **hasAccess 늦은 권한 허용 시 미갱신** — `loadEvents` 가 `hasAccess` 변경을 구독하지 않음.
   최초 onAppear 후 권한 허용되면 화면 이동 전까지 이벤트 미표시 가능.
3. **데드코드(프로젝트)** — `ViewController.swift` / `Main.storyboard` 미사용
   (SceneDelegate 가 SwiftUI 직접 호스팅). pbxproj 동기화 그룹 예외 처리 필요해 보류.

## 재현 명령

```
xcodebuild -project Calendar.xcodeproj -scheme Calendar \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild test -project Calendar.xcodeproj -scheme Calendar \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
