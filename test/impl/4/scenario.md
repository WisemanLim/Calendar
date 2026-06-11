# impl/4 — 시간 기반 이벤트 입력 시나리오

> 구현 범위: CalendarEventItem 도입, 플래너 모드별 시간 설정 UX, overdue 적색 표시, PRD 현행화

## 전제조건
- impl/3 결과: BUILD SUCCEEDED, 24 tests PASS
- `EventTemplate.defaultStartHour`/`defaultDurationMinutes` 필드 추가됨

---

## TC-01 빌드 검증
- **입력**: `xcodebuild build -scheme Calendar`
- **기대**: BUILD SUCCEEDED, 컴파일 에러 없음

## TC-02 단위 테스트 전체 통과
- **입력**: `xcodebuild test -scheme Calendar`
- **기대**: CalendarLogicTests 9개 + PlannerLogicTests 15개 = 24개 전체 PASS

## TC-03 CalendarEventItem 구조 검증
- **검증 대상**: `EventStoreManager.events` 타입이 `[String: [CalendarEventItem]]`
- **기대**: `fetchEvents` 반환값에 `id`, `title`, `displayTitle`, `startDate`, `isOverdue`, `isTodo` 포함

## TC-04 diary 시간 자동 기록
- **시나리오**: diary 모드에서 `+` 탭 → 에디터 오픈 → 내용 입력 → 저장
- **기대**:
  - `editorOpenTime` = 화면 열린 시각 → EKEvent.startDate
  - 저장 시각 = EKEvent.endDate
  - `isAllDay = false`
  - 에디터 상단 경과 시간 `mm:ss` 표시

## TC-05 todo due-date 설정
- **시나리오**: todo 모드에서 `+` 탭 → DatePicker로 기한 설정 → 저장
- **기대**:
  - 기한 = EKEvent.startDate (= endDate)
  - 저장 버튼 활성 조건: 항목 1개 이상
  - 기한 < 현재 시각이면 "기한이 지났습니다" 경고 표시

## TC-06 overdue 적색 표시
- **시나리오**: todo 이벤트가 startDate < now, notes에 "- [ ]" 포함
- **기대**: `CalendarEventItem.isOverdue = true`, CalendarView의 해당 항목 텍스트·점 적색

## TC-07 medication 프리셋 + 기본값 저장
- **시나리오**: personalEvent → 복용 카테고리 → 템플릿 선택 → "아침" 프리셋 탭
- **기대**: `eventStartTime` = 선택일 07:00
- **추가**: "기본 시간으로 저장" 탭 시 `templateStore.templates[n].defaultStartHour` 갱신

## TC-08 appointment 시작·종료 시간
- **시나리오**: personalEvent → 약속 → 템플릿 선택 → 시작/종료 DatePicker 설정
- **기대**: EKEvent.startDate = 설정한 시작시간, endDate = 설정한 종료시간

## TC-09 fixed 반복 설정
- **시나리오**: personalEvent → 고정 → 템플릿 선택 → 반복 토글 ON → 시작/종료일 선택
- **기대**:
  - `recurrenceRules = [EKRecurrenceRule(yearly, end: repeatEndDate)]`
  - 반복 OFF 시 `recurrenceRules = nil`

## TC-10 PRD 현행화 확인
- **검증 대상**: `.docs/PRD.md`
- **기대**: §3.2(B) 에 diary/todo/personalEvent 시간 요구사항 서술, 성공 기준 표에 신규 항목 추가
