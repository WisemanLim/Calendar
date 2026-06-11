# 시험 시나리오 — impl/1

- 일자: 2026-06-11
- 대상: Wise-Calendar (iOS, Swift + SwiftUI + EventKit)
- 프로파일: ios-swiftui · 도메인: ict-saas (소비자 앱, 규제 최소)
- 범위: 버그 수정 + 리팩터(순수 로직 추출) + XCTest 타깃 신설

## 환경 (dev-env)

| 항목 | 값 |
|------|-----|
| 빌드 | xcodebuild, scheme `Calendar`, Debug |
| 시뮬레이터 | iPhone 17 (iOS Simulator) |
| deploy target | iOS 18.4 / Swift 5.0 |

## 시나리오

### S1. 앱 빌드 (회귀)
- 절차: `xcodebuild -scheme Calendar -destination 'iPhone 17' build`
- 기대: BUILD SUCCEEDED, 소스 경고/에러 0

### S2. 메모 중복 렌더 버그
- 대상: CalendarView SCHEDULE 리스트
- 기대: ForEach 내 각 일정 1회만 렌더 (nested HStack 중복 제거)

### S3. 캘린더 그리드 로직 (단위 테스트)
- 대상: `CalendarLogic.monthGrid` / `CalendarLogic.dateKey`
- 기대:
  - 모든 달 그리드 = 42칸
  - SUN-first 정렬: 일요일 시작 → 선행 0칸 / 토요일 시작 → 선행 6칸
  - 당월 일수 정확 (2월 = 28)
  - today/selected 플래그 각 1개
  - dateKey = `yyyy-MM-dd` 제로패딩
  - hasEvent 주입 반영

### S4. 테스트 타깃 동작
- 절차: `xcodebuild test -scheme Calendar -destination 'iPhone 17'`
- 기대: TEST SUCCEEDED, 전 케이스 통과
