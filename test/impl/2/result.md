# 시험 결과 — impl/2 (헤더/테마/하단 달력)

- 일자: 2026-06-11
- 판정: **전체 PASS**
- 근거: 첨부 이미지 기준 헤더 재구성 + 테마 도입 + 하단 2개월

## 요구사항 반영

| # | 요구사항 | 구현 | 결과 |
|---|----------|------|------|
| 1 | 월 우측 [Today] 버튼, 선택일≠오늘일 때만 | `showsTodayButton` = `!isDateInToday(selectedDate)`, `goToToday()` | ✅ |
| 2 | 월 이동 `<`/`>` 추가 | 월 이름 좌우 chevron, `changeMonth(±1)` | ✅ |
| 3 | 연 이동 버튼 색 = 연도색 동일 + 테마 확장 | `CalendarTheme.year` 단일 소스로 연 텍스트·연 버튼 동시 | ✅ |
| 4 | 하단 달력 2개월(이미지) | 4개월 2×2 + 측면 chevron → 현재월+다음월 2개 | ✅ |

## 시험

| 항목 | 결과 |
|------|------|
| 컴파일 | ✅ 에러 0 |
| 빌드 | ✅ BUILD SUCCEEDED |
| 단위 테스트 | ✅ 9/9 (CalendarLogicTests) |

비고: 1차 test 실행은 시뮬레이터 `Busy/preflight` 런치 플레이크로 실패 →
`simctl shutdown all` 후 재시험 통과. 코드 결함 아님.

## 변경 파일

- `Calendar/CalendarTheme.swift` (신규) — 색 테마. accent/month/year/todayTint/navBackground/sunday/saturday, `.default`.
- `Calendar/CalendarView.swift`
  - 헤더: `< 월 >` + `[Today]`(조건부) + `< 연 >`. `navButton` 공통 헬퍼.
  - `changeYear(±1)`, `goToToday()`, `showsTodayButton` 추가.
  - 하단: 4개월 그리드 → 현재월+다음월 2개.
  - `MonthView`·`DayView` 에 `theme` 주입, 선택/오늘/이벤트=accent, 주말=theme.

## 재현

```
xcrun simctl shutdown all
xcodebuild test -project Calendar.xcodeproj -scheme Calendar \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
